import SwiftUI
import Combine

// --- 1. FARBEN & DESIGN ---
extension Color {
    static let bgDark = Color(red: 11/255, green: 15/255, blue: 20/255)
    static let cardBg = Color(red: 17/255, green: 22/255, blue: 35/255)
    static let cyanGlow = Color(red: 0/255, green: 229/255, blue: 255/255)
    static let ringOk = Color(red: 34/255, green: 197/255, blue: 94/255)
    static let ringMid = Color(red: 245/255, green: 158/255, blue: 11/255)
    static let ringLow = Color(red: 239/255, green: 68/255, blue: 68/255)
    static let textMuted = Color.gray
}

enum Page { case status, settings, devlog }

// --- 2. HAUPT VIEW ---
struct ContentView: View {
    @StateObject var mqttManager = MQTTManager()
    @Environment(\.scenePhase) var scenePhase
    
    @State private var showMenu = false
    @State private var currentPage: Page = .status
    
    // Wischgeste Definition
    var dragGesture: some Gesture {
        DragGesture()
            .onEnded { value in
                // Öffnen: Start am linken Rand (< 50pt) und Wisch nach rechts
                if !showMenu && value.startLocation.x < 50 && value.translation.width > 50 {
                    withAnimation { showMenu = true }
                }
                // Schließen: Wisch nach links
                else if showMenu && value.translation.width < -50 {
                    withAnimation { showMenu = false }
                }
            }
    }
    
    var body: some View {
        ZStack {
            BackgroundView()
            
            ZStack {
                switch currentPage {
                case .status:
                    StatusView(data: mqttManager, showMenu: $showMenu)
                case .settings:
                    SettingsView(showMenu: $showMenu, mqttManager: mqttManager)
                case .devlog:
                    DevLogView(showMenu: $showMenu, mqttManager: mqttManager)
                }
            }
            .cornerRadius(showMenu ? 20 : 0)
            .offset(x: showMenu ? 250 : 0)
            .scaleEffect(showMenu ? 0.8 : 1)
            .disabled(showMenu)
            .shadow(color: .black.opacity(showMenu ? 0.5 : 0), radius: 20, x: -10, y: 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showMenu)
            
            // Side Menu
            if showMenu {
                Color.black.opacity(0.01).edgesIgnoringSafeArea(.all)
                    .onTapGesture { withAnimation { showMenu = false } }
                
                HStack {
                    SideMenu(currentPage: $currentPage, showMenu: $showMenu)
                        .frame(width: 270)
                        .background(Color.cardBg.opacity(0.95))
                        .overlay(Rectangle().frame(width: 1).foregroundColor(Color.cyanGlow.opacity(0.3)), alignment: .trailing)
                    Spacer()
                }
                .transition(.move(edge: .leading))
                .zIndex(100)
            }
        }
        .preferredColorScheme(.dark)
        .gesture(dragGesture)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active { mqttManager.connect() }
            else if newPhase == .background { mqttManager.disconnect() }
        }
        .onAppear {
            mqttManager.initializeAndConnect()
        }
    }
}

// --- 3. STATUS VIEW ---
struct StatusView: View {
    @ObservedObject var data: MQTTManager; @Binding var showMenu: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                MenuButton(showMenu: $showMenu)
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(data.connectionState.contains("Verbunden") ? Color.ringOk : Color.ringLow).frame(width: 10, height: 10)
                    Text(data.connectionState).font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Color.white.opacity(0.06)).cornerRadius(20)
            }
            .padding(.horizontal).padding(.top, 60).frame(height: 100)
            
            Spacer()
            
            VStack(spacing: 40) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.05), lineWidth: 25)
                    let socVal = Double(data.soc) ?? 0
                    Circle().trim(from: 0, to: CGFloat(socVal) / 100).stroke(AngularGradient(gradient: Gradient(colors: [getSocColor(socVal).opacity(0.6), getSocColor(socVal)]), center: .center, startAngle: .degrees(-90), endAngle: .degrees(270)), style: StrokeStyle(lineWidth: 25, lineCap: .round)).rotationEffect(.degrees(-90)).shadow(color: getSocColor(socVal).opacity(0.5), radius: 20)
                    VStack(spacing: 5) {
                        Text("\(data.soc)").font(.system(size: 70, weight: .black, design: .rounded)).foregroundColor(.white).shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                        Text("%").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.textMuted)
                        TimeSinceView(date: data.lastUpdatedSoc, fontSize: 14, iconSize: 12).padding(.top, 10)
                    }
                }.frame(width: 280, height: 280)
                
                VStack(spacing: 16) {
                    MetricRow(icon: "sun.max.fill", label: "Solarleistung", value: data.solarPower, unit: "W", color: .white, date: data.lastUpdatedSolar)
                    MetricRow(icon: "battery.100", label: "Batterie", value: formatBattery(data.batteryPower), unit: "W", color: getBatteryColor(data.batteryPower), date: data.lastUpdatedBattery)
                    MetricRow(icon: "powerplug.fill", label: "Verbrauch", value: calculateConsumption(), unit: "W", color: getConsumptionColor(), date: data.lastUpdatedBattery)
                }.padding(25).background(Color.cardBg.opacity(0.9)).cornerRadius(30).overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.white.opacity(0.08), lineWidth: 1)).shadow(color: Color.cyanGlow.opacity(0.1), radius: 30).padding(.horizontal, 20)
            }
            Spacer(); Spacer()
        }
    }
    func getSocColor(_ val: Double) -> Color { if val < 20 { return .ringLow }; if val < 60 { return .ringMid }; return .ringOk }
    func getBatteryColor(_ rawVal: String) -> Color { let val = Double(rawVal) ?? 0; if val > 1 { return .ringLow }; if val < -1 { return .ringOk }; return .white }
    func getConsumptionColor() -> Color { let s = Double(data.solarPower) ?? 0; let b = Double(data.batteryPower) ?? 0; let c = max(0, s + b); return c > 1 ? .ringLow : .white }
    func formatBattery(_ rawVal: String) -> String { let val = Double(rawVal) ?? 0; if val > 1 { return "−\(Int(abs(val)))" }; return "\(Int(abs(val)))" }
    func calculateConsumption() -> String { let s = Double(data.solarPower) ?? 0; let b = Double(data.batteryPower) ?? 0; let c = max(0, s + b); return c > 0 ? "−\(Int(c))" : "0" }
}

// --- 4. SETTINGS VIEW ---
struct SettingsView: View {
    @Binding var showMenu: Bool; @ObservedObject var mqttManager: MQTTManager
    @AppStorage("alarmEnabled") private var alarmEnabled = false
    @AppStorage("alarmThreshold") private var alarmThreshold = 20.0
    @AppStorage("liveActivityEnabled") private var liveActivityEnabled = true
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                MenuButton(showMenu: $showMenu)
                Spacer()
                Text("Einstellungen").font(.headline).foregroundColor(.white)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal).padding(.top, 60).frame(height: 100)
            
            ScrollView {
                VStack(spacing: 25) {
                    VStack(alignment: .leading, spacing: 15) { HStack { Image(systemName: "platter.2.filled.iphone").foregroundColor(liveActivityEnabled ? .cyanGlow : .gray).font(.title2); Text("Live Activity").font(.title3).bold().foregroundColor(.white); Spacer(); Toggle("", isOn: $liveActivityEnabled).labelsHidden().tint(.cyanGlow).onChange(of: liveActivityEnabled) { _, n in mqttManager.toggleLiveActivity(n) } }; Text("Zeigt Batterie-Status auf dem Sperrbildschirm und in der Dynamic Island.").font(.caption).foregroundColor(.gray) }.padding(20).background(Color.cardBg).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1));
                    VStack(alignment: .leading, spacing: 20) { HStack { Image(systemName: "bell.badge.fill").foregroundColor(alarmEnabled ? .ringLow : .gray).font(.title2); Text("Batterie Alarm").font(.title3).bold().foregroundColor(.white); Spacer(); Toggle("", isOn: $alarmEnabled).labelsHidden().tint(.ringLow) }; Divider().background(Color.white.opacity(0.1)); if alarmEnabled { VStack(alignment: .leading, spacing: 10) { HStack { Text("Alarm bei unter:").foregroundColor(.gray); Spacer(); Text("\(Int(alarmThreshold))%").font(.title2).bold().foregroundColor(.ringLow) }; Slider(value: $alarmThreshold, in: 5...90, step: 1).accentColor(.ringLow) }.transition(.opacity.combined(with: .move(edge: .top))) } else { Text("Alarm ist deaktiviert").font(.footnote).foregroundColor(.gray) } }.padding(20).background(Color.cardBg).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1));
                    Spacer()
                }.padding()
            }
        }
    }
}

// --- 5. DEV LOG VIEW ---
struct DevLogView: View {
    @Binding var showMenu: Bool
    @ObservedObject var mqttManager: MQTTManager
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                MenuButton(showMenu: $showMenu)
                Spacer()
                Text("Dev Log 🛠️").font(.headline).foregroundColor(.white)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal).padding(.top, 60).frame(height: 100)
            
            ScrollView {
                // HIER WAR DER FEHLER: mqttManager.logs ist jetzt String (korrekt)
                Text(mqttManager.logs)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color.black.opacity(0.5))
            .cornerRadius(10)
            .padding()
            
            Spacer()
        }
    }
}

// --- 6. HELPER VIEWS ---
struct MenuButton: View {
    @Binding var showMenu: Bool
    var body: some View {
        Button(action: { withAnimation { showMenu.toggle() } }) {
            Image(systemName: "line.3.horizontal").font(.system(size: 24, weight: .bold)).foregroundColor(.white).padding(10).background(Color.white.opacity(0.05)).cornerRadius(10).frame(width: 44, height: 44)
        }
    }
}
struct TimeSinceView: View {
    let date: Date; var fontSize: CGFloat = 14; var iconSize: CGFloat = 12
    @State private var timeString = "Gerade eben"
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View { HStack(spacing: 4){ Image(systemName: "clock.arrow.circlepath").font(.system(size: iconSize)); Text(timeString) }.font(.system(size: fontSize, weight: .medium, design: .rounded)).foregroundColor(.cyanGlow.opacity(0.6)).onReceive(timer){_ in upd()}.onAppear{upd()}.onChange(of: date){_,_ in upd()} }
    func upd() { let d = Date().timeIntervalSince(date); if d<2{timeString="Gerade eben"}else if d<60{timeString="vor \(Int(d))s"}else if d<3600{timeString="vor \(Int(d/60)) min"}else{timeString="> 1 Std"} }
}
struct MetricRow: View {
    let icon: String; let label: String; let value: String; let unit: String; let color: Color; let date: Date
    var body: some View { HStack{ Image(systemName: icon).frame(width: 35).font(.system(size: 22)).foregroundColor(.white.opacity(0.8)); Text(label).font(.system(size: 17, design: .rounded)).foregroundColor(.textMuted); Spacer(); VStack(alignment: .trailing, spacing: 2) { HStack(alignment: .firstTextBaseline, spacing: 2) { Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(color); Text(unit).font(.system(size: 16, weight: .medium, design: .rounded)).foregroundColor(color.opacity(0.7)) }; TimeSinceView(date: date, fontSize: 11, iconSize: 9) } }.padding(16).background(Color.white.opacity(0.03)).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05), lineWidth: 1)) }
}
struct SideMenu: View {
    @Binding var currentPage: Page; @Binding var showMenu: Bool
    var body: some View {
        VStack(alignment:.leading,spacing:30){
            VStack(alignment:.leading){ Text("Wiesen").font(.largeTitle).foregroundColor(.white); Text("Batterie").font(.largeTitle).bold().foregroundColor(.cyanGlow) }.padding(.top,60).padding(.horizontal)
            Divider().background(Color.white.opacity(0.1))
            VStack(spacing:15){
                MB(t:"Live-Status",i:"bolt.fill",p:.status,s:$currentPage,m:$showMenu)
                MB(t:"Einstellungen",i:"bell.badge",p:.settings,s:$currentPage,m:$showMenu)
                MB(t:"Dev Log",i:"terminal.fill",p:.devlog,s:$currentPage,m:$showMenu)
            }.padding(.horizontal)
            Spacer()
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
}
struct MB: View { let t:String;let i:String;let p:Page;@Binding var s:Page;@Binding var m:Bool; var body: some View { Button(action:{withAnimation{s=p;m=false}}){HStack{Image(systemName:i).frame(width:30);Text(t);Spacer()}.padding().background(s==p ? Color.cyanGlow.opacity(0.1):Color.clear).cornerRadius(10).foregroundColor(s==p ? .cyanGlow:.gray)} } }
struct BackgroundView: View {
    var body: some View {
        ZStack {
            Color.bgDark.ignoresSafeArea()
            GeometryReader { proxy in
                let w = proxy.size.width
                RadialGradient(gradient: Gradient(colors: [Color.cyanGlow.opacity(0.1), Color.clear]), center: .topLeading, startRadius: 0, endRadius: w * 0.8)
                RadialGradient(gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.clear]), center: .bottomTrailing, startRadius: 0, endRadius: w * 0.8)
            }.ignoresSafeArea()
        }
    }
}
