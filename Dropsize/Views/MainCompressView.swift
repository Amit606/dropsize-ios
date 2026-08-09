import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct MainCompressView: View {
    @State private var storeManager = StoreManager.shared
    @State private var showPaywall = false
    
    // Picked media state
    @State private var selectedPickerItem: PhotosPickerItem? = nil
    @State private var localOriginalURL: URL? = nil
    @State private var isMovie = false
    @State private var originalSize: Int64 = 0
    @State private var thumbnail: UIImage? = nil
    
    // Compression parameters
    @State private var targetSizeMB: Double = 1.0
    @State private var isCompressing = false
    @State private var isImporting = false
    @State private var compressionProgress: Double = 0.0
    
    // Navigation / Results
    @State private var localCompressedURL: URL? = nil
    @State private var showResult = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("Dropsize")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(Theme.primaryText)
                    Spacer()
                    
                    if !storeManager.hasPremiumAccess {
                        Button(action: { showPaywall = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                Text("Go Premium")
                            }
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.primaryGradient)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Select Media Area or Preview Card
                if localOriginalURL == nil {
                    PhotosPicker(
                        selection: $selectedPickerItem,
                        matching: .any(of: [.images, .videos])
                    ) {
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Theme.accent.opacity(0.15))
                                    .frame(width: 80, height: 80)
                                Image(systemName: "photo.badge.plus")
                                    .font(.largeTitle)
                                    .foregroundColor(Theme.accent)
                            }
                            
                            Text("Select Photo or Video")
                                .font(.headline)
                                .foregroundColor(Theme.primaryText)
                            Text("Compress to your exact target file size")
                                .font(.subheadline)
                                .foregroundColor(Theme.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                        .background(Color.white.opacity(0.02))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                .foregroundColor(Color.white.opacity(0.15))
                        )
                    }
                    .padding(.horizontal)
                } else {
                    // Preview Card
                    GlassmorphicContainer {
                        HStack(spacing: 16) {
                            if let thumb = thumbnail {
                                Image(uiImage: thumb)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .cornerRadius(12)
                                    .clipped()
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.05))
                                        .frame(width: 80, height: 80)
                                    Image(systemName: isMovie ? "video.fill" : "photo.fill")
                                        .foregroundColor(Theme.secondaryText)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(isMovie ? "Video File" : "Photo File")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(Theme.accent)
                                
                                Text(formatSize(originalSize))
                                    .font(.title2)
                                    .fontWeight(.black)
                                    .foregroundColor(Theme.primaryText)
                            }
                            Spacer()
                            
                            Button(action: resetMedia) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Adjustment Sliders & Presets
                if localOriginalURL != nil {
                    VStack(spacing: 20) {
                        // Presets
                        HStack(spacing: 12) {
                            PresetButton(title: "Email", value: 1.0, currentTarget: $targetSizeMB)
                            PresetButton(title: "Messages", value: 2.0, currentTarget: $targetSizeMB)
                            PresetButton(title: "Web", value: 5.0, currentTarget: $targetSizeMB)
                        }
                        .padding(.horizontal)
                        
                        // Custom slider
                        GlassmorphicContainer {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Target File Size:")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.secondaryText)
                                    Spacer()
                                    Text(String(format: "%.1f MB", targetSizeMB))
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(Theme.primaryText)
                                }
                                
                                Slider(value: $targetSizeMB, in: 0.5...15.0, step: 0.5)
                                    .tint(Theme.accent)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                // Compression Action
                if localOriginalURL != nil {
                    VStack(spacing: 16) {
                        if let error = errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }
                        
                        PremiumButton(title: isMovie ? "Compress Video" : "Compress Photo", icon: "arrow.down.right.and.arrow.up.left") {
                            performCompression()
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 24)
                }
            }
            
            // Glassmorphic Modal Progress Overlay Dialog
            if isImporting || isCompressing {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                GlassmorphicContainer {
                    VStack(spacing: 20) {
                        if isImporting {
                            ProgressView()
                                .tint(Theme.accent)
                                .scaleEffect(1.5)
                                .padding(.vertical, 8)
                            
                            Text("Loading Media...")
                                .font(.headline)
                                .foregroundColor(Theme.primaryText)
                            
                            Text("Importing selected file from your photo library. Please wait.")
                                .font(.caption)
                                .foregroundColor(Theme.secondaryText)
                                .multilineTextAlignment(.center)
                                .frame(width: 220)
                        } else if isCompressing {
                            VStack(spacing: 16) {
                                if isMovie {
                                    CircularProgressView(progress: compressionProgress)
                                        .frame(width: 72, height: 72)
                                        .padding(.vertical, 4)
                                    
                                    Text("Compressing Video...")
                                        .font(.headline)
                                        .foregroundColor(Theme.primaryText)
                                    
                                    Text(String(format: "%.0f%%", compressionProgress * 100))
                                        .font(.title3)
                                        .fontWeight(.black)
                                        .foregroundColor(Theme.accent)
                                } else {
                                    ProgressView()
                                        .tint(Theme.accent)
                                        .scaleEffect(1.5)
                                        .padding(.vertical, 8)
                                    
                                    Text("Compressing Photo...")
                                        .font(.headline)
                                        .foregroundColor(Theme.primaryText)
                                    
                                    Text("Optimizing image and metadata...")
                                        .font(.caption)
                                        .foregroundColor(Theme.secondaryText)
                                }
                            }
                            .frame(width: 220)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(width: 280)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onChange(of: selectedPickerItem) { _, _ in
            loadSelectedMedia()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showResult) {
            if let orig = localOriginalURL, let comp = localCompressedURL {
                ResultView(originalURL: orig, compressedURL: comp, isMovie: isMovie)
            }
        }
    }
    
    private func loadSelectedMedia() {
        guard let item = selectedPickerItem else { return }
        
        isMovie = item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) || $0.conforms(to: .video) })
        let tempDir = FileManager.default.temporaryDirectory
        isImporting = true
        errorMessage = nil
        
        Task {
            do {
                if isMovie {
                    if let movie = try await item.loadTransferable(type: MovieTransferable.self) {
                        let destURL = tempDir.appendingPathComponent("\(UUID().uuidString).mp4")
                        try FileManager.default.copyItem(at: movie.url, to: destURL)
                        
                        let size = try FileManager.default.attributesOfItem(atPath: destURL.path)[.size] as? Int64 ?? 0
                        let asset = AVAsset(url: destURL)
                        let generator = AVAssetImageGenerator(asset: asset)
                        generator.appliesPreferredTrackTransform = true
                        let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil)
                        
                        await MainActor.run {
                            self.localOriginalURL = destURL
                            self.originalSize = size
                            if let cg = cgImage {
                                self.thumbnail = UIImage(cgImage: cg)
                            }
                            self.isImporting = false
                        }
                    } else {
                        await MainActor.run {
                            self.isImporting = false
                        }
                    }
                } else {
                    if let data = try await item.loadTransferable(type: Data.self) {
                        let destURL = tempDir.appendingPathComponent("\(UUID().uuidString).jpg")
                        try data.write(to: destURL)
                        
                        await MainActor.run {
                            self.localOriginalURL = destURL
                            self.originalSize = Int64(data.count)
                            self.thumbnail = UIImage(data: data)
                            self.isImporting = false
                        }
                    } else {
                        await MainActor.run {
                            self.isImporting = false
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load media: \(error.localizedDescription)"
                    self.isImporting = false
                }
            }
        }
    }
    
    private func performCompression() {
        guard let origURL = localOriginalURL else { return }
        
        // Check Daily Limits for Free Tier
        let defaults = UserDefaultsManager.shared
        if defaults.hasReachedFreeLimit {
            showPaywall = true
            return
        }
        
        isCompressing = true
        compressionProgress = 0.0
        errorMessage = nil
        
        let targetSizeInBytes = Int64(targetSizeMB * 1024 * 1024)
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("\(UUID().uuidString)_out.\(isMovie ? "mp4" : "jpg")")
        
        Task {
            do {
                if isMovie {
                    try await VideoCompressor.shared.compressVideo(
                        inputURL: origURL,
                        outputURL: outputURL,
                        targetSizeInBytes: targetSizeInBytes,
                        progressHandler: { progress in
                            Task {
                                await MainActor.run {
                                    self.compressionProgress = progress
                                }
                            }
                        }
                    )
                } else {
                    let originalData = try Data(contentsOf: origURL)
                    let res = try PhotoCompressor.shared.compressImage(
                        data: originalData,
                        targetSizeInBytes: targetSizeInBytes,
                        stripMetadata: defaults.stripMetadata
                    )
                    try res.data.write(to: outputURL)
                    await MainActor.run {
                        self.compressionProgress = 1.0
                    }
                }
                
                // Track usage and save to App Group for widget display
                defaults.incrementCompressionCount()
                
                // Save to history
                let fileName = origURL.lastPathComponent
                HistoryManager.shared.addEntry(
                    name: fileName,
                    originalSize: originalSize,
                    compressedURL: outputURL,
                    isMovie: isMovie
                )
                
                if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.kwh.dropsize") {
                    let thumbURL = containerURL.appendingPathComponent("last_compressed_thumbnail.jpg")
                    try? FileManager.default.removeItem(at: thumbURL)
                    if let data = try? Data(contentsOf: outputURL),
                       let image = UIImage(data: data) {
                        let scaleFactor: CGFloat = image.size.width > 200 ? 200.0 / image.size.width : 1.0
                        let thumbImage = image.scaled(by: scaleFactor) ?? image
                        if let thumbData = thumbImage.jpegData(compressionQuality: 0.8) {
                            try? thumbData.write(to: thumbURL)
                            defaults.lastCompressedPhotoPath = thumbURL.path
                        }
                    }
                }
                
                await MainActor.run {
                    self.localCompressedURL = outputURL
                    self.isCompressing = false
                    self.showResult = true
                }
            } catch {
                await MainActor.run {
                    self.isCompressing = false
                    self.errorMessage = "Compression failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func resetMedia() {
        if let orig = localOriginalURL {
            try? FileManager.default.removeItem(at: orig)
        }
        if let comp = localCompressedURL {
            try? FileManager.default.removeItem(at: comp)
        }
        selectedPickerItem = nil
        localOriginalURL = nil
        localCompressedURL = nil
        thumbnail = nil
        originalSize = 0
        errorMessage = nil
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct PresetButton: View {
    let title: String
    let value: Double
    @Binding var currentTarget: Double
    
    var body: some View {
        Button(action: { currentTarget = value }) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(currentTarget == value ? .white : Theme.secondaryText)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background {
                    if currentTarget == value {
                        Theme.primaryGradient
                    } else {
                        LinearGradient(colors: [Color.white.opacity(0.05), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                    }
                }
                .cornerRadius(10)
        }
    }
}

struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    Theme.accent.opacity(0.15),
                    lineWidth: 6
                )
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(
                    Theme.primaryGradient,
                    style: StrokeStyle(
                        lineWidth: 6,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut, value: progress)
        }
    }
}

