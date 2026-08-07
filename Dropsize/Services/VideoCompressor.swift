import AVFoundation

public enum VideoCompressionError: Error {
    case noVideoTrack
    case readerSetupFailed
    case writerSetupFailed
    case compressionCancelled
    case compressionFailed(Error)
}

public final class VideoCompressor {
    public static let shared = VideoCompressor()
    
    private init() {}
    
    public func compressVideo(
        inputURL: URL,
        outputURL: URL,
        targetSizeInBytes: Int64,
        progressHandler: @escaping (Double) -> Void
    ) async throws {
        // Delete output if exists
        try? FileManager.default.removeItem(at: outputURL)
        
        let asset = AVURLAsset(url: inputURL)
        
        // Load keys asynchronously
        let duration = try await asset.load(.duration)
        let tracks = try await asset.load(.tracks)
        
        guard let videoTrack = tracks.first(where: { $0.mediaType == .video }) else {
            throw VideoCompressionError.noVideoTrack
        }
        
        let durationSeconds = duration.seconds
        guard durationSeconds > 0 else {
            throw VideoCompressionError.writerSetupFailed
        }
        
        // Calculate target bitrate
        let targetBits = Double(targetSizeInBytes) * 8.0
        let totalBitrate = targetBits / durationSeconds
        
        // Audio Bitrate defaults
        let audioTrack = tracks.first(where: { $0.mediaType == .audio })
        let audioBitrate: Double = audioTrack != nil ? 96000 : 0 // 96 kbps for audio
        
        var videoBitrate = totalBitrate - audioBitrate
        if videoBitrate < 100_000 {
            videoBitrate = 100_000 // Minimum 100kbps video bitrate
        }
        
        // Choose resolution based on target video bitrate
        let originalNaturalSize = try await videoTrack.load(.naturalSize)
        let targetSize = calculateTargetResolution(originalSize: originalNaturalSize, bitrate: videoBitrate)
        
        // Set up reader
        let reader = try AVAssetReader(asset: asset)
        
        // Set up writer
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        
        // Video Settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(targetSize.width),
            AVVideoHeightKey: Int(targetSize.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: Int(videoBitrate),
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        
        let writerVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerVideoInput.expectsMediaDataInRealTime = false
        
        // Reader Video Output
        let readerVideoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        
        if reader.canAdd(readerVideoOutput) {
            reader.add(readerVideoOutput)
        } else {
            throw VideoCompressionError.readerSetupFailed
        }
        
        if writer.canAdd(writerVideoInput) {
            writer.add(writerVideoInput)
        } else {
            throw VideoCompressionError.writerSetupFailed
        }
        
        // Audio Track setup if available
        var writerAudioInput: AVAssetWriterInput? = nil
        var readerAudioOutput: AVAssetReaderTrackOutput? = nil
        
        if let audioTrack = audioTrack {
            readerAudioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
            if reader.canAdd(readerAudioOutput!) {
                reader.add(readerAudioOutput!)
            }
            
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 44100.0,
                AVEncoderBitRateKey: Int(audioBitrate)
            ]
            
            writerAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            writerAudioInput?.expectsMediaDataInRealTime = false
            
            if writer.canAdd(writerAudioInput!) {
                writer.add(writerAudioInput!)
            }
        }
        
        // Start Reader & Writer
        guard reader.startReading() else {
            throw VideoCompressionError.readerSetupFailed
        }
        
        guard writer.startWriting() else {
            throw VideoCompressionError.writerSetupFailed
        }
        
        writer.startSession(atSourceTime: .zero)
        
        let queue = DispatchQueue(label: "com.kwh.dropsize.video-compress-queue")
        
        await withCheckedContinuation { continuation in
            let group = DispatchGroup()
            
            // Compress Video Track
            group.enter()
            writerVideoInput.requestMediaDataWhenReady(on: queue) {
                while writerVideoInput.isReadyForMoreMediaData {
                    if let sampleBuffer = readerVideoOutput.copyNextSampleBuffer() {
                        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                        let progress = durationSeconds > 0 ? timestamp.seconds / durationSeconds : 0.0
                        progressHandler(min(0.99, progress))
                        
                        writerVideoInput.append(sampleBuffer)
                    } else {
                        writerVideoInput.markAsFinished()
                        group.leave()
                        break
                    }
                }
            }
            
            // Compress Audio Track
            if let writerAudioInput = writerAudioInput, let readerAudioOutput = readerAudioOutput {
                group.enter()
                writerAudioInput.requestMediaDataWhenReady(on: queue) {
                    while writerAudioInput.isReadyForMoreMediaData {
                        if let sampleBuffer = readerAudioOutput.copyNextSampleBuffer() {
                            writerAudioInput.append(sampleBuffer)
                        } else {
                            writerAudioInput.markAsFinished()
                            group.leave()
                            break
                        }
                    }
                }
            }
            
            // Wait for tracks completion
            group.notify(queue: queue) {
                if reader.status == .failed {
                    writer.cancelWriting()
                    continuation.resume()
                } else {
                    writer.finishWriting {
                        progressHandler(1.0)
                        continuation.resume()
                    }
                }
            }
        }
        
        if reader.status == .failed {
            throw VideoCompressionError.compressionFailed(reader.error ?? NSError(domain: "Dropsize", code: -1, userInfo: nil))
        }
        if writer.status == .failed {
            throw VideoCompressionError.compressionFailed(writer.error ?? NSError(domain: "Dropsize", code: -1, userInfo: nil))
        }
    }
    
    private func calculateTargetResolution(originalSize: CGSize, bitrate: Double) -> CGSize {
        let isLandscape = originalSize.width >= originalSize.height
        let longEdge = max(originalSize.width, originalSize.height)
        let shortEdge = min(originalSize.width, originalSize.height)
        let aspectRatio = shortEdge / longEdge
        
        var targetLongEdge: CGFloat
        if bitrate >= 3_500_000 {
            targetLongEdge = longEdge
        } else if bitrate >= 1_800_000 {
            targetLongEdge = min(longEdge, 1080)
        } else if bitrate >= 900_000 {
            targetLongEdge = min(longEdge, 720)
        } else if bitrate >= 400_000 {
            targetLongEdge = min(longEdge, 480)
        } else {
            targetLongEdge = min(longEdge, 360)
        }
        
        let targetShortEdge = targetLongEdge * aspectRatio
        
        // Video encoder performance prefers multiples of 16
        let finalWidth = CGFloat(Int(isLandscape ? targetLongEdge : targetShortEdge) / 16 * 16)
        let finalHeight = CGFloat(Int(isLandscape ? targetShortEdge : targetLongEdge) / 16 * 16)
        
        return CGSize(width: max(16, finalWidth), height: max(16, finalHeight))
    }
}
