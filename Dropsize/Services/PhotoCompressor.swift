import UIKit
import ImageIO
import UniformTypeIdentifiers

public struct CompressionResult {
    public let data: Data
    public let originalSize: Int64
    public let compressedSize: Int64
    public let scale: CGFloat
    public let quality: CGFloat
}

public enum PhotoCompressionError: Error {
    case invalidImageData
    case unableToCompressToTarget
}

public final class PhotoCompressor {
    public static let shared = PhotoCompressor()
    
    private init() {}
    
    public func compressImage(
        data: Data,
        targetSizeInBytes: Int64,
        stripMetadata: Bool = false
    ) throws -> CompressionResult {
        guard let image = UIImage(data: data) else {
            throw PhotoCompressionError.invalidImageData
        }
        
        let originalSize = Int64(data.count)
        
        // If original size is already smaller and we aren't stripping metadata, return it
        if originalSize <= targetSizeInBytes && !stripMetadata {
            return CompressionResult(data: data, originalSize: originalSize, compressedSize: originalSize, scale: 1.0, quality: 1.0)
        }
        
        var currentScale: CGFloat = 1.0
        var currentQuality: CGFloat = 1.0
        var finalData: Data? = nil
        
        // Try to binary search quality at full resolution
        var lowQuality: CGFloat = 0.0
        var highQuality: CGFloat = 1.0
        var bestDataForCurrentScale: Data? = nil
        var bestQualityForCurrentScale: CGFloat = 0.0
        
        // Run binary search
        for _ in 0..<8 {
            let midQuality = (lowQuality + highQuality) / 2.0
            guard let jpeg = image.jpegData(compressionQuality: midQuality) else { continue }
            
            let size = Int64(jpeg.count)
            if size <= targetSizeInBytes {
                bestDataForCurrentScale = jpeg
                bestQualityForCurrentScale = midQuality
                lowQuality = midQuality // Try to get higher quality that still fits
            } else {
                highQuality = midQuality // Need more compression
            }
        }
        
        // If we found a valid quality at scale 1.0
        if let data = bestDataForCurrentScale {
            finalData = data
            currentQuality = bestQualityForCurrentScale
        } else {
            // Even quality 0.0 at scale 1.0 is too large. We must scale down resolution.
            // Let's estimate starting scale:
            guard let minQualityData = image.jpegData(compressionQuality: 0.0) else {
                throw PhotoCompressionError.unableToCompressToTarget
            }
            
            let ratio = Double(targetSizeInBytes) / Double(minQualityData.count)
            var scaleFactor = CGFloat(fmin(0.9, fmax(0.1, sqrt(ratio))))
            
            // Loop to downscale and compress
            for _ in 0..<5 {
                guard let scaledImage = image.scaled(by: scaleFactor) else { break }
                
                var bestScaledData: Data? = nil
                var bestScaledQuality: CGFloat = 0.0
                var lowQ: CGFloat = 0.0
                var highQ: CGFloat = 1.0
                
                for _ in 0..<6 {
                    let midQ = (lowQ + highQ) / 2.0
                    guard let jpeg = scaledImage.jpegData(compressionQuality: midQ) else { continue }
                    
                    let size = Int64(jpeg.count)
                    if size <= targetSizeInBytes {
                        bestScaledData = jpeg
                        bestScaledQuality = midQ
                        lowQ = midQ
                    } else {
                        highQ = midQ
                    }
                }
                
                if let data = bestScaledData {
                    finalData = data
                    currentQuality = bestScaledQuality
                    currentScale = scaleFactor
                    break
                } else {
                    // Still too large, reduce scale factor
                    scaleFactor *= 0.7
                }
            }
        }
        
        // If we still couldn't find any data under the target size, just use the lowest quality + scale
        var resultData: Data
        if let data = finalData {
            resultData = data
        } else {
            guard let scaled = image.scaled(by: 0.1),
                  let minData = scaled.jpegData(compressionQuality: 0.0) else {
                throw PhotoCompressionError.unableToCompressToTarget
            }
            resultData = minData
            currentScale = 0.1
            currentQuality = 0.0
        }
        
        if stripMetadata {
            resultData = stripMetadataFromJPEG(data: resultData) ?? resultData
        }
        
        return CompressionResult(
            data: resultData,
            originalSize: originalSize,
            compressedSize: Int64(resultData.count),
            scale: currentScale,
            quality: currentQuality
        )
    }
    
    private func stripMetadataFromJPEG(data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) else {
            return nil
        }
        
        let writeData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(writeData, type, 1, nil) else {
            return nil
        }
        
        // kCGImageDestinationMergeMetadata = false prevents metadata copying
        let options: [CFString: Any] = [
            kCGImageDestinationMergeMetadata: false
        ] as [CFString: Any]
        
        CGImageDestinationAddImageFromSource(destination, source, 0, options as CFDictionary)
        if CGImageDestinationFinalize(destination) {
            return writeData as Data
        }
        return nil
    }
}

extension UIImage {
    func scaled(by factor: CGFloat) -> UIImage? {
        guard factor > 0.0 && factor < 1.0 else { return self }
        let newSize = CGSize(width: size.width * factor, height: size.height * factor)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
