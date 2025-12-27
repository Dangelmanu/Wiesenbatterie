//
//  BatteryWidgetBundle.swift
//  BatteryWidget
//
//  Created by Manuel on 27.12.25.
//

import WidgetKit
import SwiftUI

@main
struct BatteryWidgetBundle: WidgetBundle {
    var body: some Widget {
        BatteryWidget()
        BatteryWidgetControl()
    }
}
