//
//  BatteryAttributes.swift
//  Wiesenbatterie
//
//  Created by Manuel on 27.12.25.
//


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
