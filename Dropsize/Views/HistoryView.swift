import SwiftUI
import AVKit

struct HistoryView: View {
    @State private var historyManager = HistoryManager.shared
    
    // Preview / Share State
    @State private var selectedEntry: HistoryEntry? = nil
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header Title
                Text("History")
                    .font(.title)
                    .fontWeight(.black)
                    .foregroundColor(Theme.primaryText)
                    .padding(.top, 16)
                
                // Savings Dashboard
                GlassmorphicContainer {
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Total Space Saved")
                                .font(.caption)
                                .foregroundColor(Theme.secondaryText)
                            Text(formatSize(historyManager.totalBytesSaved))
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 6) {
                            Text("Files Shrunk")
                                .font(.caption)
                                .foregroundColor(Theme.secondaryText)
                            Text("\(historyManager.totalCompressionsCount)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Queue List
                if historyManager.entries.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 64))
                            .foregroundColor(Theme.secondaryText.opacity(0.3))
                        
                        Text("No history entries yet")
                            .font(.headline)
                            .foregroundColor(Theme.secondaryText)
                        
                        Text("All your compressed photos and videos will appear here.")
                            .font(.subheadline)
                            .foregroundColor(Theme.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(historyManager.entries) { entry in
                                HistoryRowView(entry: entry) {
                                    if let idx = historyManager.entries.firstIndex(of: entry) {
                                        historyManager.deleteEntry(at: IndexSet(integer: idx))
                                    }
                                }
                                .onTapGesture {
                                    selectedEntry = entry
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
        .sheet(item: $selectedEntry) { entry in
            HistoryDetailView(entry: entry) { fileURL in
                presentShareSheet(activityItems: [fileURL])
            }
        }
        .onAppear {
            historyManager.loadHistory()
        }
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// History Detail Modal Sheet
struct HistoryDetailView: View {
    @Environment(\.dismiss) var dismiss
    let entry: HistoryEntry
    let onShare: (URL) -> Void
    
    @State private var fileURL: URL? = nil
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("History Item Details")
                        .font(.headline)
                        .foregroundColor(Theme.primaryText)
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Theme.secondaryText)
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Visual Media Preview
                ZStack {
                    if let url = fileURL {
                        if entry.isMovie {
                            VideoPlayer(player: AVPlayer(url: url))
                                .frame(height: 250)
                                .cornerRadius(16)
                        } else {
                            if let uiImage = UIImage(contentsOfFile: url.path) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 250)
                                    .cornerRadius(16)
                            }
                        }
                    } else {
                        ProgressView()
                            .tint(.white)
                            .frame(height: 250)
                    }
                }
                .padding(.horizontal)
                
                // Stats Card
                GlassmorphicContainer {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Filename")
                                .foregroundColor(Theme.secondaryText)
                            Spacer()
                            Text(entry.fileName)
                                .foregroundColor(Theme.primaryText)
                                .lineLimit(1)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                        
                        HStack {
                            Text("Original Size")
                                .foregroundColor(Theme.secondaryText)
                            Spacer()
                            Text(formatSize(entry.originalSize))
                                .foregroundColor(Theme.primaryText)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                        
                        HStack {
                            Text("Compressed Size")
                                .foregroundColor(Theme.secondaryText)
                            Spacer()
                            Text(formatSize(entry.compressedSize))
                                .foregroundColor(.green)
                                .fontWeight(.bold)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                        
                        HStack {
                            Text("Compression Date")
                                .foregroundColor(Theme.secondaryText)
                            Spacer()
                            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                .foregroundColor(Theme.primaryText)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action
                if let url = fileURL {
                    PremiumButton(title: "Share / Export File", icon: "square.and.arrow.up") {
                        onShare(url)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            resolveFileURL()
        }
    }
    
    private func resolveFileURL() {
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.kwh.dropsize") {
            let fullURL = containerURL.appendingPathComponent(entry.relativePath)
            if FileManager.default.fileExists(atPath: fullURL.path) {
                self.fileURL = fullURL
            }
        }
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct HistoryRowView: View {
    let entry: HistoryEntry
    let onDelete: () -> Void
    
    @State private var thumbnail: UIImage? = nil
    @State private var isLoaded = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail
            ZStack {
                if let thumb = thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 54, height: 54)
                        .cornerRadius(10)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 54, height: 54)
                    
                    Image(systemName: entry.isMovie ? "video.fill" : "photo.fill")
                        .foregroundColor(Theme.secondaryText.opacity(0.5))
                        .font(.system(size: 18))
                }
            }
            .frame(width: 54, height: 54)
            
            // Details
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.fileName)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.primaryText)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(formatSize(entry.originalSize))
                        .font(.caption2)
                        .foregroundColor(Theme.secondaryText)
                        .strikethrough()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8))
                        .foregroundColor(Theme.secondaryText)
                    Text(formatSize(entry.compressedSize))
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.bold)
                }
            }
            
            Spacer()
            
            // Savings badge & Delete button
            HStack(spacing: 12) {
                let pct = entry.originalSize > 0 ? Double(entry.originalSize - entry.compressedSize) / Double(entry.originalSize) * 100 : 0
                Text(String(format: "-%.0f%%", pct))
                    .font(.caption2)
                    .fontWeight(.black)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(6)
                
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.7))
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.all, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .contentShape(Rectangle()) // Ensures tap gesture works across entire card
        .task {
            guard !isLoaded else { return }
            loadThumbnail()
            isLoaded = true
        }
    }
    
    private func loadThumbnail() {
        let groupSuiteName = "group.com.kwh.dropsize"
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupSuiteName) else {
            return
        }
        let fullURL = container.appendingPathComponent(entry.relativePath)
        guard FileManager.default.fileExists(atPath: fullURL.path) else {
            return
        }
        
        if entry.isMovie {
            // Generate video thumbnail asynchronously
            let asset = AVAsset(url: fullURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: .zero)]) { _, image, _, _, _ in
                if let cgImage = image {
                    let uiImg = UIImage(cgImage: cgImage)
                    DispatchQueue.main.async {
                        self.thumbnail = uiImg
                    }
                }
            }
        } else {
            // Load photo thumbnail
            if let uiImage = UIImage(contentsOfFile: fullURL.path) {
                self.thumbnail = uiImage
            }
        }
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
