import SwiftUI
import PhotosUI

struct BatchItem: Identifiable {
    let id = UUID()
    let name: String
    let originalURL: URL
    var compressedURL: URL?
    var originalSize: Int64
    var compressedSize: Int64?
    var isMovie: Bool
    var progress: Double = 0.0
    var status: Status = .idle
    
    enum Status: Equatable {
        case idle
        case compressing
        case completed
        case failed(String)
        
        static func == (lhs: Status, rhs: Status) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.compressing, .compressing), (.completed, .completed):
                return true
            case (.failed(let a), .failed(let b)):
                return a == b
            default:
                return false
            }
        }
    }
}

struct BatchCompressView: View {
    @State private var storeManager = StoreManager.shared
    @State private var showPaywall = false
    
    @State private var selectedPickerItems: [PhotosPickerItem] = []
    @State private var items: [BatchItem] = []
    
    @State private var targetSizeMB: Double = 2.0
    @State private var isCompressing = false
    @State private var compressionCompleted = false
    
    @State private var showShareSheet = false
    @State private var shareItems: [URL] = []
    
    @State private var alertMessage: String?
    @State private var showAlert = false
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                Text("Batch Compress")
                    .font(.title)
                    .fontWeight(.black)
                    .foregroundColor(Theme.primaryText)
                    .padding(.top, 16)
                
                // Target size slider
                GlassmorphicContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Target Size:")
                                .font(.headline)
                                .foregroundColor(Theme.primaryText)
                            Spacer()
                            Text(String(format: "%.1f MB", targetSizeMB))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.accent)
                        }
                        
                        Slider(value: $targetSizeMB, in: 0.5...15.0, step: 0.5)
                            .tint(Theme.accent)
                    }
                }
                .padding(.horizontal)
                
                // Main picker/queue
                if items.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 64))
                            .foregroundColor(Theme.secondaryText.opacity(0.3))
                        
                        Text("No media selected")
                            .font(.headline)
                            .foregroundColor(Theme.secondaryText)
                        
                        PhotosPicker(
                            selection: $selectedPickerItems,
                            maxSelectionCount: 15,
                            matching: .any(of: [.images, .videos])
                        ) {
                            Text("Select Photos & Videos")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Theme.primaryGradient)
                                .cornerRadius(12)
                        }
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(items) { item in
                            HStack {
                                Image(systemName: item.isMovie ? "video.circle.fill" : "photo.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(Theme.accent)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name)
                                        .font(.subheadline)
                                        .foregroundColor(Theme.primaryText)
                                        .lineLimit(1)
                                    Text("Original: \(formatSize(item.originalSize))")
                                        .font(.caption)
                                        .foregroundColor(Theme.secondaryText)
                                }
                                
                                Spacer()
                                
                                switch item.status {
                                case .idle:
                                    Text("Pending")
                                        .font(.caption)
                                        .foregroundColor(Theme.secondaryText)
                                case .compressing:
                                    ProgressView(value: item.progress)
                                        .tint(Theme.accent)
                                        .frame(width: 60)
                                case .completed:
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("Done")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                            .fontWeight(.bold)
                                        if let size = item.compressedSize {
                                            Text(formatSize(size))
                                                .font(.caption2)
                                                .foregroundColor(Theme.secondaryText)
                                        }
                                    }
                                case .failed(let err):
                                    Text("Failed: \(err)")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            .listRowBackground(Theme.cardBg)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
                    .frame(maxHeight: .infinity)
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    if !items.isEmpty {
                        if compressionCompleted {
                            PremiumButton(title: "Save All to Photos", icon: "square.and.arrow.down") {
                                saveAllToLibrary()
                            }
                            .padding(.horizontal)
                            
                            Button(action: {
                                shareItems = items.compactMap { $0.compressedURL }
                                showShareSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Share All...")
                                }
                                .font(.headline)
                                .foregroundColor(Theme.primaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(14)
                            }
                            .padding(.horizontal)
                            
                            Button("Clear Queue") {
                                clearQueue()
                            }
                            .foregroundColor(Theme.secondaryText)
                            .font(.subheadline)
                            .padding(.top, 4)
                        } else {
                            PremiumButton(title: isCompressing ? "Compressing..." : "Start Batch Compression", icon: "play.fill") {
                                startBatchCompression()
                            }
                            .disabled(isCompressing)
                            .padding(.horizontal)
                            
                            if !isCompressing {
                                Button("Cancel") {
                                    clearQueue()
                                }
                                .foregroundColor(Theme.secondaryText)
                                .font(.subheadline)
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .onChange(of: selectedPickerItems) { _, _ in
            loadSelectedItems()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Dropsize Batch"), message: Text(alertMessage ?? ""), dismissButton: .default(Text("OK")))
        }
    }
    
    private func loadSelectedItems() {
        guard !selectedPickerItems.isEmpty else { return }
        
        // Batch mode is Premium only! Check entitlement.
        if !storeManager.hasPremiumAccess {
            showPaywall = true
            selectedPickerItems = []
            return
        }
        
        items = []
        compressionCompleted = false
        
        let tempDir = FileManager.default.temporaryDirectory
        
        for pickerItem in selectedPickerItems {
            let name = pickerItem.itemIdentifier ?? UUID().uuidString
            let isMovie = pickerItem.supportedContentTypes.contains(.movie)
            
            Task {
                do {
                    if isMovie {
                        if let movie = try await pickerItem.loadTransferable(type: MovieTransferable.self) {
                            let destURL = tempDir.appendingPathComponent("\(UUID().uuidString).mp4")
                            try FileManager.default.copyItem(at: movie.url, to: destURL)
                            
                            let size = try FileManager.default.attributesOfItem(atPath: destURL.path)[.size] as? Int64 ?? 0
                            
                            await MainActor.run {
                                items.append(BatchItem(name: name, originalURL: destURL, originalSize: size, isMovie: true))
                            }
                        }
                    } else {
                        if let data = try await pickerItem.loadTransferable(type: Data.self) {
                            let destURL = tempDir.appendingPathComponent("\(UUID().uuidString).jpg")
                            try data.write(to: destURL)
                            
                            await MainActor.run {
                                items.append(BatchItem(name: name, originalURL: destURL, originalSize: Int64(data.count), isMovie: false))
                            }
                        }
                    }
                } catch {
                    print("Error loading batch item: \(error)")
                }
            }
        }
    }
    
    private func startBatchCompression() {
        guard !items.isEmpty else { return }
        isCompressing = true
        
        let targetSizeInBytes = Int64(targetSizeMB * 1024 * 1024)
        let tempDir = FileManager.default.temporaryDirectory
        
        Task {
            for index in 0..<items.count {
                await MainActor.run {
                    items[index].status = .compressing
                }
                
                let item = items[index]
                let outputURL = tempDir.appendingPathComponent("\(UUID().uuidString)_out.\(item.isMovie ? "mp4" : "jpg")")
                
                do {
                    if item.isMovie {
                        try await VideoCompressor.shared.compressVideo(
                            inputURL: item.originalURL,
                            outputURL: outputURL,
                            targetSizeInBytes: targetSizeInBytes,
                            progressHandler: { prog in
                                Task {
                                    await MainActor.run {
                                        items[index].progress = prog
                                    }
                                }
                            }
                        )
                    } else {
                        let originalData = try Data(contentsOf: item.originalURL)
                        let res = try PhotoCompressor.shared.compressImage(
                            data: originalData,
                            targetSizeInBytes: targetSizeInBytes,
                            stripMetadata: UserDefaultsManager.shared.stripMetadata
                        )
                        try res.data.write(to: outputURL)
                    }
                    
                    let outSize = try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64 ?? 0
                    
                    await MainActor.run {
                        items[index].compressedURL = outputURL
                        items[index].compressedSize = outSize
                        items[index].status = .completed
                    }
                } catch {
                    await MainActor.run {
                        items[index].status = .failed(error.localizedDescription)
                    }
                }
            }
            
            await MainActor.run {
                isCompressing = false
                compressionCompleted = true
            }
        }
    }
    
    private func saveAllToLibrary() {
        Task {
            var successCount = 0
            do {
                for item in items {
                    guard let compressedURL = item.compressedURL else { continue }
                    if item.isMovie {
                        try await PHPhotoLibrary.shared().performChanges {
                            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: compressedURL)
                        }
                    } else {
                        guard let image = UIImage(contentsOfFile: compressedURL.path) else { continue }
                        try await PHPhotoLibrary.shared().performChanges {
                            PHAssetChangeRequest.creationRequestForAsset(from: image)
                        }
                    }
                    successCount += 1
                }
                alertMessage = "Successfully saved \(successCount) items to your library!"
                showAlert = true
            } catch {
                alertMessage = "Failed to save some files: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    private func clearQueue() {
        for item in items {
            try? FileManager.default.removeItem(at: item.originalURL)
            if let cURL = item.compressedURL {
                try? FileManager.default.removeItem(at: cURL)
            }
        }
        items = []
        selectedPickerItems = []
        compressionCompleted = false
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// Transferable helper for video files from picker
struct MovieTransferable: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let tempDir = FileManager.default.temporaryDirectory
            let copyURL = tempDir.appendingPathComponent("\(UUID().uuidString).mp4")
            try FileManager.default.copyItem(at: received.file, to: copyURL)
            return MovieTransferable(url: copyURL)
        }
    }
}
