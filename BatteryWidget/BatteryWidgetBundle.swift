import WidgetKit
import SwiftUI
import ActivityKit

// --- Design-Farben & Globale Helfer ---
extension Color {
    static let widgetBg = Color(red: 17/255, green: 22/255, blue: 35/255) // Cyberpunk Dunkelblau
}

func getStatusColor(_ soc: Double) -> Color {
    return soc < 20 ? .red : (soc < 50 ? .orange : .green)
}

// --- Haupt-Einstiegspunkt ---
@main
struct BatteryWidgetBundle: WidgetBundle {
    var body: some Widget {
        BatteryActivityWidget() // Das neue, schicke Live-Widget
        BatteryHomeWidget()     // Das große Home-Widget (bleibt wie es war)
    }
}

// ==========================================
// TEIL A: Live Activity (Sperrbildschirm & Island) - NEU DESIGNT
// ==========================================
struct BatteryActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BatteryAttributes.self) { context in
            // --------------------------------------------------
            // 1. SPERRBILDSCHIRM / UNTEN (ZENTRIERT!)
            // --------------------------------------------------
            HStack(spacing: 35) { // Engerer Abstand, kein Spacer -> Zentriert
                // Linker Block: Großer Ring
                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: context.state.soc / 100)
                        .stroke(
                            getStatusColor(context.state.soc),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .shadow(color: getStatusColor(context.state.soc).opacity(0.4), radius: 8)
                    
                    VStack(spacing: -4) {
                        Text("\(Int(context.state.soc))")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("%")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 80, height: 80)
                
                // Rechter Block: Große Daten
                VStack(alignment: .leading, spacing: 10) {
                    // Solar
                    HStack(spacing: 8) {
                        Image(systemName: "sun.max.fill")
                            .font(.title3)
                            .foregroundColor(.yellow)
                        Text("\(Int(context.state.solarPower)) W")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    // Batterie
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.title3)
                            .foregroundColor(context.state.batteryPower > 0 ? .red : .green)
                        Text("\(Int(abs(context.state.batteryPower))) W")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
            .padding(.vertical, 25) // Mehr Platz nach oben/unten
            .padding(.horizontal, 30)
            .activityBackgroundTint(Color.widgetBg.opacity(0.95))
            .activitySystemActionForegroundColor(Color.white)
            
        } dynamicIsland: { context in
            // --------------------------------------------------
            // 2. DYNAMIC ISLAND (PRO MAX OPTIMIERT)
            // --------------------------------------------------
            DynamicIsland {
                // === EXPANDED (Lang drücken) ===
                
                // Links: Riesige Prozentzahl
                DynamicIslandExpandedRegion(.leading) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(context.state.soc))")
                            .font(.system(size: 46, weight: .black, design: .rounded))
                            .foregroundColor(getStatusColor(context.state.soc))
                        Text("%")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    .padding(.leading, 10)
                }
                
                // Rechts: Prominente Leistungsdaten
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(spacing: 4) {
                            Text("\(Int(context.state.solarPower))")
                                .font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.white)
                            Text("W").font(.footnote).foregroundColor(.gray)
                            Image(systemName: "sun.max.fill").foregroundColor(.yellow)
                        }
                        HStack(spacing: 4) {
                            Text("\(Int(abs(context.state.batteryPower)))")
                                .font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.white)
                            Text("W").font(.footnote).foregroundColor(.gray)
                            Image(systemName: "bolt.fill").foregroundColor(context.state.batteryPower > 0 ? .red : .green)
                        }
                    }
                    .padding(.trailing, 10)
                }
                
                // Unten: Label
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("Wiesenbatterie Live")
                    }
                    .font(.caption2).foregroundColor(.gray.opacity(0.6))
                    .padding(.top, 10)
                }
                
            } compactLeading: {
                // === KOMPAKT LINKS ===
                HStack(spacing: 2) {
                    Image(systemName: "bolt.fill").font(.caption2).foregroundColor(context.state.batteryPower > 0 ? .red : .green)
                    Text("\(Int(context.state.soc))%").fontWeight(.black).foregroundColor(getStatusColor(context.state.soc))
                }
            } compactTrailing: {
                // === KOMPAKT RECHTS ===
                if context.state.solarPower > 50 {
                    HStack(spacing: 2) {
                        Text("\(Int(context.state.solarPower))").fontWeight(.bold)
                        Image(systemName: "sun.max.fill").font(.caption2).foregroundColor(.yellow)
                    }
                } else {
                    // Wenn wenig Sonne, zeige Batterie-Watt
                     Text("\(Int(abs(context.state.batteryPower)))W").font(.caption).foregroundColor(.gray)
                }
            } minimal: {
                // === MINIMAL (Insel geteilt) ===
                Text("\(Int(context.state.soc))").fontWeight(.black).foregroundColor(getStatusColor(context.state.soc))
            }
        }
    }
}


// ==========================================
// TEIL B: Home Screen Widget (Bleibt gleich)
// ==========================================
struct BatteryHomeWidget: Widget {
    let kind: String = "BatteryHomeWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                BatteryHomeEntryView(entry: entry).containerBackground(for: .widget) { Color.widgetBg }
            } else { BatteryHomeEntryView(entry: entry).background(Color.widgetBg) }
        }
        .configurationDisplayName("Wiesenbatterie Max").description("Extra große Anzeige.").supportedFamilies([.systemSmall])
    }
}

// Helper Views & Provider für Home Widget (kompakt, da unverändert)
struct BatteryHomeEntryView : View {
    var entry: Provider.Entry
    var body: some View {
        let socVal = Double(entry.soc) ?? 0; let color = getStatusColor(socVal)
        VStack(alignment: .leading, spacing: 0) {
            HStack { Image(systemName: "bolt.fill").foregroundColor(color).font(.caption); Text("WIESEN").font(.system(size: 10, weight: .bold)).foregroundColor(.gray).kerning(1.2); Spacer() }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 2) { Text(entry.soc).font(.system(size: 56, weight: .black, design: .rounded)).foregroundColor(.white).shadow(color: color.opacity(0.6), radius: 8); Text("%").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.gray) }
            Spacer()
            GeometryReader { geo in ZStack(alignment: .leading) { Capsule().fill(Color.white.opacity(0.1)); Capsule().fill(LinearGradient(colors: [color.opacity(0.7), color], startPoint: .leading, endPoint: .trailing)).frame(width: geo.size.width * (CGFloat(socVal) / 100)) } }.frame(height: 10)
        }.padding(12)
    }
}
struct Provider: TimelineProvider {
    typealias Entry = SimpleEntry
    func placeholder(in context: Context) -> SimpleEntry { SimpleEntry(date: Date(), soc: "85") }
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) { completion(SimpleEntry(date: Date(), soc: "85")) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let defaults = UserDefaults(suiteName: "group.de.manuel.wiesenbatterie"); let soc = defaults?.string(forKey: "soc") ?? "--"
        completion(Timeline(entries: [SimpleEntry(date: Date(), soc: soc)], policy: .never))
    }
}
struct SimpleEntry: TimelineEntry { let date: Date; let soc: String }
