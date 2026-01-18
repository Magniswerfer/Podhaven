import Foundation

extension TimeInterval {
    /// Format a time interval as a human-readable string (e.g., "1h 23m", "45m 12s")
    func formattedTime() -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = self >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: self) ?? "0s"
    }
}