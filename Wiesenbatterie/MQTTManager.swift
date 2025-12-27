import Foundation
import CocoaMQTT
import SwiftUI

class MQTTManager: ObservableObject {
    // Diese Variablen aktualisieren automatisch die UI
    @Published var voltage: String = "..."
    @Published var status: String = "Disconnected"

    var mqtt: CocoaMQTT?

    init() {
        // Deine Broker-Daten (IP vom Pi oder öffentlicher Broker)
        let clientID = "iPhoneClient-" + String(ProcessInfo().processIdentifier)
        mqtt = CocoaMQTT(clientID: clientID, host: "DEINE_BROKER_IP", port: 1883)
        // mqtt?.username = "user"
        // mqtt?.password = "pass"

        mqtt?.didConnectAck = { mqtt, ack in
            self.status = "Connected"
            mqtt.subscribe("wiesenbatterie/voltage") // Dein Topic
        }

        mqtt?.didReceiveMessage = { mqtt, message, id in
            // Daten kommen rein -> UI Update im Main Thread
            DispatchQueue.main.async {
                if message.topic == "wiesenbatterie/voltage" {
                    self.voltage = message.string ?? "Err"
                }
            }
        }

        mqtt?.connect()
    }
}