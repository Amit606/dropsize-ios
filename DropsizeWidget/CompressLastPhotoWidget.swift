import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), thumbnail: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let path = UserDefaultsManager.shared.lastCompressedPhotoPath
        let image = path != nil ? UIImage(contentsOfFile: path!) : nil
        let entry = SimpleEntry(date: Date(), thumbnail: image)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let path = UserDefaultsManager.shared.lastCompressedPhotoPath
        let image = path != nil ? UIImage(contentsOfFile: path!) : nil
        let entry = SimpleEntry(date: Date(), thumbnail: image)

        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let thumbnail: UIImage?
}

struct CompressLastPhotoWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            Color(hex: "090A0F")
                .ignoresSafeArea()
            
            if family == .systemSmall {
                if let image = entry.thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(
                            VStack {
                                Spacer()
                                HStack {
                                    Text("Last Shrunk")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.black.opacity(0.6))
                                        .cornerRadius(4)
                                    Spacer()
                                }
                                .padding(8)
                            }
                        )
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.title)
                            .foregroundColor(Color(hex: "8A3FFC"))
                        
                        Text("Shrink Photo")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Tap to open")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }
                    .multilineTextAlignment(.center)
                    .padding()
                }
            } else {
                // systemMedium layout
                HStack(spacing: 16) {
                    if let image = entry.thumbnail {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 90, height: 90)
                            .cornerRadius(12)
                            .clipped()
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.05))
                                .frame(width: 90, height: 90)
                            Image(systemName: "photo.badge.plus")
                                .font(.title)
                                .foregroundColor(Color(hex: "8A3FFC"))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Dropsize")
                            .font(.headline)
                            .fontWeight(.black)
                            .foregroundColor(.white)
                        
                        Text("Last Shrunk Photo")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("Tap to shrink more")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: "8A3FFC"))
                    }
                    Spacer()
                }
                .padding()
            }
        }
        .widgetURL(URL(string: "dropsize://compress"))
    }
}

@main
struct CompressLastPhotoWidget: Widget {
    let kind: String = "CompressLastPhotoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CompressLastPhotoWidgetEntryView(entry: entry)
                .containerBackground(Color(hex: "090A0F"), for: .widget)
        }
        .configurationDisplayName("Last Shrunk")
        .description("Quickly open Dropsize or view your last compressed photo.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 1)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
