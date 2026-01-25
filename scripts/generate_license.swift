#!/usr/bin/env swift
// License Key Generator for SystemPulse
// Usage: swift generate_license.swift customer@email.com

import Foundation
import CryptoKit

let salt = "SystemPulse2026"

func generateLicenseKey(for email: String) -> String {
    let input = email.lowercased() + salt
    let hash = SHA256.hash(data: Data(input.utf8))
    let hashString = hash.compactMap { String(format: "%02X", $0) }.joined()
    let prefix = String(hashString.prefix(16))
    
    var formatted = ""
    for (index, char) in prefix.enumerated() {
        if index > 0 && index % 4 == 0 {
            formatted += "-"
        }
        formatted.append(char)
    }
    return formatted
}

guard CommandLine.arguments.count > 1 else {
    print("Usage: swift generate_license.swift <email>")
    print("Example: swift generate_license.swift customer@example.com")
    exit(1)
}

let email = CommandLine.arguments[1]
let key = generateLicenseKey(for: email)

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("SystemPulse License Key")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("Email: \(email)")
print("Key:   \(key)")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("")
print("Send this to your customer:")
print("")
print("Thanks for purchasing SystemPulse! 🎉")
print("")
print("Your license details:")
print("Email: \(email)")
print("License Key: \(key)")
print("")
print("To activate: Open SystemPulse → Click 'Enter License' → Enter your email and key")
