import Foundation

enum ClaudeUsageLimiter {
    static let maxDailyCalls = 20

    private struct UsageRecord: Codable {
        var date: String
        var count: Int
    }

    static var callsUsedToday: Int {
        usageForToday().count
    }

    static var remainingCallsToday: Int {
        max(0, maxDailyCalls - callsUsedToday)
    }

    static func canMakeCall() -> Bool {
        callsUsedToday < maxDailyCalls
    }

    static func recordCall() {
        var usage = usageForToday()
        usage.count += 1
        save(usage)
    }

    private static func usageForToday() -> UsageRecord {
        let today = todayString()
        var usage = loadUsage()

        if usage.date != today {
            usage = UsageRecord(date: today, count: 0)
        }

        return usage
    }

    private static func loadUsage() -> UsageRecord {
        let path = usageFilePath()
        guard FileManager.default.fileExists(atPath: path.path),
              let data = try? Data(contentsOf: path),
              let parsed = try? JSONDecoder().decode(UsageRecord.self, from: data) else {
            return UsageRecord(date: todayString(), count: 0)
        }

        return parsed
    }

    private static func save(_ usage: UsageRecord) {
        let path = usageFilePath()
        let directory = path.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        if let data = try? JSONEncoder().encode(usage) {
            try? data.write(to: path)
        }
    }

    private static func usageFilePath() -> URL {
        ConfigStore.userDataDirectory().appendingPathComponent("claude-usage.json")
    }

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
