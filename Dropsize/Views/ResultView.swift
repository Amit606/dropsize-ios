import SwiftUI
import AVKit

struct ResultView: View {
    @Environment(\.dismiss) var dismiss
    
    let originalURL: URL
    let compressedURL: URL
    let isMovie: Bool
    
    @State private var originalSize: Int64 = 0
    @State private var compressedSize: Int64 = 0
    @State private var beforeImage: UIImage?
    @State private var afterImage: UIImage?
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var alertMessage: String?
    @State private var showAlert = false
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Title & Stats
                VStack(spacing: 8) {
                    Text("Result")
                        .font(.title)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                    
                    let percentage = originalSize > 0 ? Double(originalSize - compressedSize) / Double(originalSize) * 100 : 0
                    Text(String(format: "Saved %.0f%%", percentage))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(8)
                }
                
                // Visual Preview Section
                ZStack {
                    if isMovie {
                        let player = AVPlayer(url: compressedURL)
                        VideoPlayer(player: player)
                            .frame(maxHeight: 300)
                            .cornerRadius(16)
                            .shadow(radius: 8)
                            .onAppear {
                                player.play()
                            }
                            .onDisappear {
                                player.pause()
                            }
                    } else {
                        if let before = beforeImage, let after = afterImage {
                            BeforeAfterSlider(beforeImage: before, afterImage: after)
                                .frame(height: 300)
                                .shadow(radius: 8)
                        } else {
                            ProgressView()
                                .tint(.white)
                                .frame(height: 300)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Size Metrics
                GlassmorphicContainer {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Original")
                                .font(.caption)
                                .foregroundColor(Theme.secondaryText)
                            Text(formatSize(originalSize))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title)
                            .foregroundColor(Theme.accent)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 6) {
                            Text("Compressed")
                                .font(.caption)
                                .foregroundColor(Theme.secondaryText)
                            Text(formatSize(compressedSize))
                                .font(.title3)
                                .fontWeight(.black)
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Actions
                VStack(spacing: 12) {
                    PremiumButton(title: "Save to Photos", icon: "square.and.arrow.down") {
                        saveToLibrary()
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        shareItems = [compressedURL]
                        showShareSheet = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share File...")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(14)
                    }
                    .padding(.horizontal)
                    
                    Button("Dismiss") {
                        dismiss()
                    }
                    .foregroundColor(Theme.secondaryText)
                    .font(.subheadline)
                    .padding(.top, 8)
                }
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            loadMediaSizes()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Dropsize"), message: Text(alertMessage ?? ""), dismissButton: .default(Text("OK")))
        }
    }
    
    private func loadMediaSizes() {
        if let originalAttributes = try? FileManager.default.attributesOfItem(atPath: originalURL.path),
           let size = originalAttributes[.size] as? Int64 {
            originalSize = size
        }
        if let compressedAttributes = try? FileManager.default.attributesOfItem(atPath: compressedURL.path),
           let size = compressedAttributes[.size] as? Int64 {
            compressedSize = size
        }
        
        if !isMovie {
            beforeImage = UIImage(contentsOfFile: originalURL.path)
            afterImage = UIImage(contentsOfFile: compressedURL.path)
        }
    }
    
    private func saveToLibrary() {
        Task {
            do {
                if isMovie {
                    try await PHPhotoLibrary.shared().performChanges {
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: compressedURL)
                    }
                } else {
                    guard let image = UIImage(contentsOfFile: compressedURL.path) else {
                        alertMessage = "Unable to read compressed image."
                        showAlert = true
                        return
                    }
                    try await PHPhotoLibrary.shared().performChanges {
                        PHAssetChangeRequest.creationRequestForAsset(from: image)
                    }
                }
                alertMessage = "Successfully saved to your Photos library!"
                showAlert = true
            } catch {
                alertMessage = "Failed to save: \(error.localizedDescription)"
                showAlert = true
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

// Custom Activity View Controller wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

import Photos

struct BeforeAfterSlider: View {
    let beforeImage: UIImage
    let afterImage: UIImage
    
    @State private var dragOffset: CGFloat = 0.5
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack(alignment: .leading) {
                Image(uiImage: beforeImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
                
                Image(uiImage: afterImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
                    .mask(
                        HStack(spacing: 0) {
                            Rectangle()
                                .frame(width: width * dragOffset)
                            Spacer()
                        }
                    )
                
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2)
                    .offset(x: width * dragOffset - 1)
                    .shadow(radius: 2)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 36, height: 36)
                    .shadow(radius: 4)
                    .overlay(
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                    )
                    .offset(x: width * dragOffset - 18, y: height / 2.0 - 18)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newOffset = value.location.x / width
                                dragOffset = min(max(newOffset, 0.0), 1.0)
                            }
                    )
            }
            .cornerRadius(16)
        }
    }
}
