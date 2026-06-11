import Foundation
#if os(macOS)
import Security
#endif

enum AppGroup {
    static let suffix = "com.obsidianwidget.shared"
    static let legacyIdentifier = "group.com.obsidianwidget.shared"
    static let stateFileName = "widget-state.json"

    static var identifier: String {
        if let teamID = resolvedTeamID() {
            return "\(teamID).\(suffix)"
        }
        return legacyIdentifier
    }

    static var containerURL: URL? {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            return url
        }

        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: legacyIdentifier)
    }

    static var stateFileURL: URL? {
        containerURL?.appendingPathComponent(stateFileName)
    }

    private static func resolvedTeamID() -> String? {
        #if os(macOS)
        guard let bundleURL = Bundle.main.bundleURL as CFURL? else {
            return nil
        }

        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(bundleURL, SecCSFlags(), &staticCode) == errSecSuccess,
              let code = staticCode else {
            return nil
        }

        var infoCF: CFDictionary?
        guard SecCodeCopySigningInformation(
            code,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &infoCF) == errSecSuccess,
              let info = infoCF as? [String: Any],
              let teamID = info[kSecCodeInfoTeamIdentifier as String] as? String,
              !teamID.isEmpty else {
            return nil
        }

        return teamID
        #else
        return nil
        #endif
    }
}
