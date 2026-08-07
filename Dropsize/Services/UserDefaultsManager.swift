import Foundation

public final class UserDefaultsManager {
    public static let shared = UserDefaultsManager()
    
    private let groupSuiteName = "group.com.kwh.dropsize"
    private let userDefaults: UserDefaults?
    
    private let premiumKey = "dropsize_is_premium"
    private let dailyCompressCountKey = "dropsize_daily_compress_count"
    private let lastResetDateKey = "dropsize_last_reset_date"
    private let stripMetadataKey = "dropsize_strip_metadata"
    private let lastCompressedPhotoPathKey = "dropsize_last_compressed_photo_path"
    
    private init() {
        self.userDefaults = UserDefaults(suiteName: groupSuiteName)
    }
    
    public var isPremium: Bool {
        get {
            userDefaults?.bool(forKey: premiumKey) ?? false
        }
        set {
            userDefaults?.set(newValue, forKey: premiumKey)
        }
    }
    
    public var stripMetadata: Bool {
        get {
            userDefaults?.bool(forKey: stripMetadataKey) ?? false
        }
        set {
            userDefaults?.set(newValue, forKey: stripMetadataKey)
        }
    }
    
    public var lastCompressedPhotoPath: String? {
        get {
            userDefaults?.string(forKey: lastCompressedPhotoPathKey)
        }
        set {
            userDefaults?.set(newValue, forKey: lastCompressedPhotoPathKey)
        }
    }
    
    public var remainingFreeCompressions: Int {
        if isPremium {
            return 99999
        }
        resetDailyCountIfNeeded()
        let count = userDefaults?.integer(forKey: dailyCompressCountKey) ?? 0
        return max(0, 3 - count)
    }
    
    public var hasReachedFreeLimit: Bool {
        remainingFreeCompressions <= 0
    }
    
    public func incrementCompressionCount() {
        guard !isPremium else { return }
        resetDailyCountIfNeeded()
        let currentCount = userDefaults?.integer(forKey: dailyCompressCountKey) ?? 0
        userDefaults?.set(currentCount + 1, forKey: dailyCompressCountKey)
    }
    
    private func resetDailyCountIfNeeded() {
        let lastResetDate = userDefaults?.object(forKey: lastResetDateKey) as? Date ?? Date.distantPast
        let calendar = Calendar.current
        if !calendar.isDateInToday(lastResetDate) {
            userDefaults?.set(0, forKey: dailyCompressCountKey)
            userDefaults?.set(Date(), forKey: lastResetDateKey)
        }
    }
}

