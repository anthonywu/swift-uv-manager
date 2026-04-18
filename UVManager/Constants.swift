import Foundation

enum AppConstants {
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    static let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    static let appName = "UV Manager"
    static let githubURL = "https://github.com/anthonywu"
}
