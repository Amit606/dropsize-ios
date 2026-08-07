import UIKit
import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import Photos

@objc(ShareViewController)
class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }
    
    private func setupView() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            cancel()
            return
        }
        
        var attachments: [NSItemProvider] = []
        for item in extensionItems {
            if let providers = item.attachments {
                attachments.append(contentsOf: providers)
            }
        }
        
        guard let provider = attachments.first else {
            cancel()
            return
        }
        
        let isImage = provider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        let isMovie = provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
        
        guard isImage || isMovie else {
            cancel()
            return
        }
        
        let typeIdentifier = isMovie ? UTType.movie.identifier : UTType.image.identifier
        
        provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] (url, error) in
            guard let self = self else { return }
            if let error = error {
                print("Share Extension Error: \(error.localizedDescription)")
                self.cancel()
                return
            }
            
            guard let sourceURL = url else {
                self.cancel()
                return
            }
            
            // Copy file to temp directory
            let tempDir = FileManager.default.temporaryDirectory
            let extensionName = isMovie ? "mp4" : "jpg"
            let copyURL = tempDir.appendingPathComponent("\(UUID().uuidString).\(extensionName)")
            
            do {
                try? FileManager.default.removeItem(at: copyURL)
                try FileManager.default.copyItem(at: sourceURL, to: copyURL)
                
                DispatchQueue.main.async {
                    self.presentSwiftUIView(url: copyURL, isMovie: isMovie)
                }
            } catch {
                print("Share Extension File Copy Error: \(error.localizedDescription)")
                self.cancel()
            }
        }
    }
    
    private func presentSwiftUIView(url: URL, isMovie: Bool) {
        let extensionView = ShareExtensionView(
            originalURL: url,
            isMovie: isMovie,
            onComplete: { [weak self] compressedURL in
                self?.complete(with: compressedURL)
            },
            onCancel: { [weak self] in
                self?.cancel()
            }
        )
        
        let hostingController = UIHostingController(rootView: extensionView)
        addChild(hostingController)
        view.addSubview(hostingController.view)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        hostingController.didMove(toParent: self)
    }
    
    private func complete(with url: URL) {
        // Return the compressed file
        let itemProvider = NSItemProvider(contentsOf: url)
        let extensionItem = NSExtensionItem()
        extensionItem.attachments = [itemProvider ?? NSItemProvider()]
        
        extensionContext?.completeRequest(returningItems: [extensionItem], completionHandler: nil)
    }
    
    private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: "Dropsize", code: -1, userInfo: nil))
    }
}

// SwiftUI Share View Interface
struct ShareExtensionView: View {
    let originalURL: URL
    let isMovie: Bool
    let onComplete: (URL) -> Void
    let onCancel: () -> Void
    
    @State private var originalSize: Int64 = 0
    @State private var thumbnail: UIImage? = nil
    
    @State private var targetSizeMB: Double = 1.0
    @State private var isCompressing = false
    @State private var compressionProgress: Double = 0.0
    @State private var compressedURL: URL? = nil
    @State private var compressedSize: Int64 = 0
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(Theme.secondaryText)
                    Spacer()
                    Text("Compress & Share")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    if let compURL = compressedURL {
                        Button("Done") {
                            onComplete(compURL)
                        }
                        .foregroundColor(Theme.accent)
                        .fontWeight(.bold)
                    } else {
                        Button("Done") {
                            onCancel()
                        }
                        .disabled(true)
                        .opacity(0)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Info / Preview
                GlassmorphicContainer {
                    HStack(spacing: 16) {
                        if let thumb = thumbnail {
                            Image(uiImage: thumb)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .cornerRadius(8)
                                .clipped()
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.05))
                                    .frame(width: 60, height: 60)
                                Image(systemName: isMovie ? "video.fill" : "photo.fill")
                                    .foregroundColor(Theme.secondaryText)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(isMovie ? "Video File" : "Photo File")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.accent)
                            
                            Text("Original: \(formatSize(originalSize))")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            
                            if compressedSize > 0 {
                                Text("Compressed: \(formatSize(compressedSize))")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal)
                
                if compressedURL == nil {
                    // Limits indicator or Settings
                    let defaults = UserDefaultsManager.shared
                    if defaults.hasReachedFreeLimit {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .font(.largeTitle)
                                .foregroundColor(.red)
                            Text("Limit Reached")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Daily free compression limit reached. Please purchase Premium in the main app to continue.")
                                .font(.caption)
                                .foregroundColor(Theme.secondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        VStack(spacing: 16) {
                            HStack(spacing: 12) {
                                PresetButton(title: "Email", value: 1.0, currentTarget: $targetSizeMB)
                                PresetButton(title: "Messages", value: 2.0, currentTarget: $targetSizeMB)
                                PresetButton(title: "Web", value: 5.0, currentTarget: $targetSizeMB)
                            }
                            .padding(.horizontal)
                            
                            GlassmorphicContainer {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text("Target Size:")
                                            .font(.caption)
                                            .foregroundColor(Theme.secondaryText)
                                        Spacer()
                                        Text(String(format: "%.1f MB", targetSizeMB))
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                    Slider(value: $targetSizeMB, in: 0.5...10.0, step: 0.5)
                                        .tint(Theme.accent)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                } else {
                    // Completion graphic
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        
                        let pct = originalSize > 0 ? Double(originalSize - compressedSize) / Double(originalSize) * 100 : 0
                        Text(String(format: "Saved %.0f%% of space!", pct))
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Tap 'Done' in the top right to complete sharing.")
                            .font(.caption)
                            .foregroundColor(Theme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxHeight: .infinity)
                }
                
                Spacer()
                
                // Actions
                if compressedURL == nil && !UserDefaultsManager.shared.hasReachedFreeLimit {
                    VStack {
                        if isCompressing {
                            VStack(spacing: 8) {
                                ProgressView(value: compressionProgress)
                                    .tint(Theme.accent)
                                Text(String(format: "Compressing... %.0f%%", compressionProgress * 100))
                                    .font(.caption)
                                    .foregroundColor(Theme.secondaryText)
                            }
                            .padding(.horizontal)
                        } else {
                            if let err = errorMessage {
                                Text(err)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            
                            PremiumButton(title: "Compress", icon: "arrow.down.right.and.arrow.up.left") {
                                performCompression()
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            loadOriginalMediaDetails()
        }
    }
    
    private func loadOriginalMediaDetails() {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: originalURL.path),
           let size = attrs[.size] as? Int64 {
            originalSize = size
        }
        
        if isMovie {
            let asset = AVAsset(url: originalURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil)
            if let cg = cgImage {
                thumbnail = UIImage(cgImage: cg)
            }
        } else {
            thumbnail = UIImage(contentsOfFile: originalURL.path)
        }
    }
    
    private func performCompression() {
        let defaults = UserDefaultsManager.shared
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
                        inputURL: originalURL,
                        outputURL: outputURL,
                        targetSizeInBytes: targetSizeInBytes,
                        progressHandler: { prog in
                            Task {
                                await MainActor.run {
                                    self.compressionProgress = prog
                                }
                            }
                        }
                    )
                } else {
                    let originalData = try Data(contentsOf: originalURL)
                    let res = try PhotoCompressor.shared.compressImage(
                        data: originalData,
                        targetSizeInBytes: targetSizeInBytes,
                        stripMetadata: defaults.stripMetadata
                    )
                    try res.data.write(to: outputURL)
                }
                
                defaults.incrementCompressionCount()
                
                // Save to history
                let fileName = originalURL.lastPathComponent
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
                
                let outSize = try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64 ?? 0
                
                await MainActor.run {
                    self.compressedURL = outputURL
                    self.compressedSize = outSize
                    self.isCompressing = false
                }
            } catch {
                await MainActor.run {
                    self.isCompressing = false
                    self.errorMessage = "Failed: \(error.localizedDescription)"
                }
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
