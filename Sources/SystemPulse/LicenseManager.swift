import Foundation
import CryptoKit

class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    @Published var isLicensed: Bool = false
    @Published var licenseEmail: String = ""

    private let licenseKeyKey = "SystemPulseLicenseKey"
    private let licenseEmailKey = "SystemPulseLicenseEmail"

    // Secret salt for validation (in production, obfuscate this)
    private let salt = "SystemPulse2026"

    init() {
        loadStoredLicense()
    }

    private func loadStoredLicense() {
        if let key = UserDefaults.standard.string(forKey: licenseKeyKey),
           let email = UserDefaults.standard.string(forKey: licenseEmailKey) {
            if validateLicenseKey(key, email: email) {
                isLicensed = true
                licenseEmail = email
            }
        }
    }

    func activateLicense(key: String, email: String) -> Bool {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if validateLicenseKey(cleanKey, email: cleanEmail) {
            UserDefaults.standard.set(cleanKey, forKey: licenseKeyKey)
            UserDefaults.standard.set(cleanEmail, forKey: licenseEmailKey)
            isLicensed = true
            licenseEmail = cleanEmail
            NotificationCenter.default.post(name: NSNotification.Name("LicenseStatusChanged"), object: nil)
            return true
        }
        return false
    }

    func deactivateLicense() {
        UserDefaults.standard.removeObject(forKey: licenseKeyKey)
        UserDefaults.standard.removeObject(forKey: licenseEmailKey)
        isLicensed = false
        licenseEmail = ""
    }

    private func validateLicenseKey(_ key: String, email: String) -> Bool {
        // License key format: XXXX-XXXX-XXXX-XXXX
        // Generated from: SHA256(email + salt), take first 16 chars, format with dashes
        let expectedKey = generateLicenseKey(for: email)
        return key == expectedKey
    }

    func generateLicenseKey(for email: String) -> String {
        let input = email.lowercased() + salt
        let hash = SHA256.hash(data: Data(input.utf8))
        let hashString = hash.compactMap { String(format: "%02X", $0) }.joined()
        let prefix = String(hashString.prefix(16))

        // Format as XXXX-XXXX-XXXX-XXXX
        var formatted = ""
        for (index, char) in prefix.enumerated() {
            if index > 0 && index % 4 == 0 {
                formatted += "-"
            }
            formatted.append(char)
        }
        return formatted
    }
}
