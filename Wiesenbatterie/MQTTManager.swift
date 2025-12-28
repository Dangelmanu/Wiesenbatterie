import Foundation
import CocoaMQTT
import SwiftUI
import Combine
import ActivityKit
import WidgetKit
import UserNotifications

class MQTTManager: ObservableObject {
    @Published var soc: String = "--"
    @Published var solarPower: String = "0"
    @Published var batteryPower: String = "0"
    @Published var connectionState: String = "Warte auf Start..."
    @Published var logs: String = "App gestartet...\n"
    
    @Published var lastUpdatedSoc: Date = Date()
    @Published var lastUpdatedSolar: Date = Date()
    @Published var lastUpdatedBattery: Date = Date()
    
    var mqtt: CocoaMQTT?
    var currentActivity: Activity<BatteryAttributes>?
    private var hasTriggeredAlarm = false
    private var watchdogTimer: Timer?
    
    // Status-Flag, um Spamming zu verhindern
    private var isConnecting = false
    
    let topicSOC = "Wiesenbatterie/soc/soc_percent"
    let topicSolar = "solardaten/laderegler/PPV"
    let topicBattery = "Wiesenbatterie/soc/power"
    let suiteName = "group.de.manuel.wiesenbatterie"

    init() {
        log("Init: Manager erstellt.")
    }
    
    func log(_ msg: String) {
        let time = Date().formatted(.dateTime.hour().minute().second().secondFraction(.fractional(3)))
        DispatchQueue.main.async {
            self.logs += "[\(time)] \(msg)\n"
            // Scrollen simulieren indem wir alte Logs irgendwann abschneiden, falls zu lang
            if self.logs.count > 5000 { self.logs = String(self.logs.suffix(5000)) }
            print("[\(time)] \(msg)")
        }
    }
    
    func initializeAndConnect() {
        log("initializeAndConnect: Lade Cache...")
        loadCachedValues()
        
        // Watchdog starten
        startWatchdog()
        
        log("Starte Hintergrund-Setup...")
        DispatchQueue.global(qos: .userInitiated).async {
            self.setupAndConnect()
        }
    }
    
    private func setupAndConnect() {
        DispatchQueue.main.async { self.requestNotificationPermission() }
        
        if UserDefaults.standard.object(forKey: "liveActivityEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "liveActivityEnabled")
        }
        
        let clientID = "iPhone-" + String(ProcessInfo().processIdentifier)
        self.log("Background: Erstelle MQTT Client...")
        
        let mqttClient = CocoaMQTT(clientID: clientID, host: "tom-rehm.online", port: 1883)
        mqttClient.username = "mqtt"
        mqttClient.password = "WA9ng64&"
        mqttClient.keepAlive = 60
        mqttClient.cleanSession = true
        mqttClient.autoReconnect = true
        
        mqttClient.didConnectAck = { [weak self] mqtt, ack in
            self?.log("Callback: didConnectAck: \(ack)")
            self?.isConnecting = false // Wir sind fertig mit Versuchen
            DispatchQueue.main.async {
                if ack == .accept {
                    self?.connectionState = "Verbunden 🟢"
                    mqtt.subscribe(self?.topicSOC ?? "")
                    mqtt.subscribe(self?.topicSolar ?? "")
                    mqtt.subscribe(self?.topicBattery ?? "")
                } else {
                    self?.connectionState = "Fehler: \(ack)"
                }
            }
        }
        
        mqttClient.didDisconnect = { [weak self] mqtt, err in
            self?.log("Callback: didDisconnect. Fehler: \(err?.localizedDescription ?? "Keiner")")
            self?.isConnecting = false
            DispatchQueue.main.async {
                self?.connectionState = "Getrennt 🔴"
            }
        }
        
        mqttClient.didReceiveMessage = { [weak self] mqtt, message, id in
            let payload = message.string ?? "0"
            DispatchQueue.main.async {
                guard let self = self else { return }
                let now = Date()
                switch message.topic {
                case self.topicSOC:
                    let socVal = Double(payload) ?? 0.0
                    self.soc = String(format: "%.1f", socVal)
                    self.lastUpdatedSoc = now
                    self.checkAlarm(currentSoc: socVal)
                    self.saveValue(key: "soc", value: self.soc, date: now)
                case self.topicSolar:
                    self.solarPower = String(format: "%.0f", Double(payload) ?? 0.0)
                    self.lastUpdatedSolar = now
                    self.saveValue(key: "solar", value: self.solarPower, date: now)
                case self.topicBattery:
                    self.batteryPower = String(format: "%.0f", Double(payload) ?? 0.0)
                    self.lastUpdatedBattery = now
                    self.saveValue(key: "battery", value: self.batteryPower, date: now)
                default: break
                }
                self.updateLiveActivity()
            }
        }
        
        self.mqtt = mqttClient
        
        if UserDefaults.standard.bool(forKey: "liveActivityEnabled") {
            DispatchQueue.main.async { self.startLiveActivity() }
        }
        
        log("Background: Versuche Erst-Verbindung...")
        self.isConnecting = true
        _ = mqttClient.connect()
    }
    
    // --- DER AGGRESSIVE WACHHUND 🐕 ---
    func startWatchdog() {
        watchdogTimer?.invalidate()
        
        // Intervall erhöht auf 8 Sekunden (Netzwerk braucht Zeit)
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Wenn wir verbunden sind, ist alles gut -> Nichts tun.
            if self.mqtt?.connState == .connected {
                return
            }
            
            self.log("🐕 Watchdog: Verbindung fehlt.")
            
            // WICHTIG: Erst die alte, hängende Verbindung töten!
            // Das löst das Problem aus deinem Logfile.
            self.mqtt?.disconnect()
            
            // Kurz warten, dann neu verbinden
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.5) {
                self.log("🐕 Watchdog: Starte Hard-Reconnect...")
                self.isConnecting = true
                _ = self.mqtt?.connect()
            }
        }
    }
    
    // --- Restliche Funktionen ---
    func toggleLiveActivity(_ enabled: Bool) { if enabled { startLiveActivity() } else { stopLiveActivity() } }
    func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, currentActivity == nil else { return }
        let att = BatteryAttributes()
        let state = BatteryAttributes.ContentState(soc: Double(soc) ?? 0, solarPower: Double(solarPower) ?? 0, batteryPower: Double(batteryPower) ?? 0)
        do { currentActivity = try Activity.request(attributes: att, content: .init(state: state, staleDate: nil)) } catch { log("Fehler LiveActivity: \(error)") }
    }
    func stopLiveActivity() { Task { await currentActivity?.end(nil, dismissalPolicy: .immediate); currentActivity = nil } }
    func updateLiveActivity() {
        guard UserDefaults.standard.bool(forKey: "liveActivityEnabled"), let activity = currentActivity else { return }
        let newState = BatteryAttributes.ContentState(soc: Double(soc) ?? 0, solarPower: Double(solarPower) ?? 0, batteryPower: Double(batteryPower) ?? 0)
        Task { await activity.update(.init(state: newState, staleDate: nil)) }
    }
    func loadCachedValues() {
        if let defaults = UserDefaults(suiteName: suiteName) {
            if let v = defaults.string(forKey: "soc") { self.soc = v }
            if let v = defaults.string(forKey: "solar") { self.solarPower = v }
            if let v = defaults.string(forKey: "battery") { self.batteryPower = v }
            self.lastUpdatedSoc = Date(timeIntervalSince1970: defaults.double(forKey: "soc_ts"))
            self.lastUpdatedSolar = Date(timeIntervalSince1970: defaults.double(forKey: "solar_ts"))
            self.lastUpdatedBattery = Date(timeIntervalSince1970: defaults.double(forKey: "battery_ts"))
            if self.lastUpdatedSoc.timeIntervalSince1970 == 0 { self.lastUpdatedSoc = Date() }
            if self.lastUpdatedSolar.timeIntervalSince1970 == 0 { self.lastUpdatedSolar = Date() }
            if self.lastUpdatedBattery.timeIntervalSince1970 == 0 { self.lastUpdatedBattery = Date() }
        }
    }
    func saveValue(key: String, value: String, date: Date) {
        if let defaults = UserDefaults(suiteName: suiteName) {
            defaults.set(value, forKey: key)
            defaults.set(date.timeIntervalSince1970, forKey: "\(key)_ts")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    func checkAlarm(currentSoc: Double) {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "alarmEnabled") && currentSoc < defaults.double(forKey: "alarmThreshold") && !hasTriggeredAlarm {
            sendNotification(soc: currentSoc); hasTriggeredAlarm = true
        }
        if currentSoc > (defaults.double(forKey: "alarmThreshold") + 5.0) { hasTriggeredAlarm = false }
    }
    func sendNotification(soc: Double) {
        let c = UNMutableNotificationContent(); c.title="⚠️ Batterie kritisch"; c.body="Ladestand: \(Int(soc))%"; c.sound = .defaultCritical
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }
    func requestNotificationPermission() { UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in } }
    
    // Manuelle Handler
    func connect() {
        log("Manuelles connect()...")
        DispatchQueue.global(qos: .userInitiated).async {
            self.mqtt?.disconnect() // Sicherheitshalber auch hier erst trennen
            Thread.sleep(forTimeInterval: 0.2)
            _ = self.mqtt?.connect()
        }
    }
    func disconnect() {
        log("Manuelles disconnect()...")
        DispatchQueue.global(qos: .userInitiated).async {
            self.mqtt?.disconnect()
        }
    }
}
