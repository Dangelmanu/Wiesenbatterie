import ActivityKit
import SwiftUI

struct BatteryAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Diese Werte können wir live updaten
        var soc: Double
        var solarPower: Double
        var batteryPower: Double
    }
}