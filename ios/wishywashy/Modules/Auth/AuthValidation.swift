//
//  AuthValidation.swift
//  wishywashy
//
//  The form rules. Each function returns the message to show, or nil when the value is fine.
//

import Foundation

enum AuthValidation {
    static let minPasswordLength = 8
    static let maxNameLength = 50

    static func name(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Tell us what to call you." }
        if trimmed.count > maxNameLength { return "Keep your name under \(maxNameLength) letters." }
        return nil
    }

    static func email(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Enter your email." }
        return isValidEmail(trimmed) ? nil : "That doesn't look like an email address."
    }

    /// Used when signing up. Sign-in only asks for a non-empty password, because older accounts may be shorter.
    static func newPassword(_ value: String) -> String? {
        if value.isEmpty { return "Choose a password." }
        return value.count >= minPasswordLength ? nil : "Use at least \(minPasswordLength) characters."
    }

    static func existingPassword(_ value: String) -> String? {
        value.isEmpty ? "Enter your password." : nil
    }

    static func confirmation(_ confirm: String, matches password: String) -> String? {
        if confirm.isEmpty { return "Type your password again." }
        return confirm == password ? nil : "The passwords don't match."
    }

    static func isValidEmail(_ value: String) -> Bool {
        value.range(of: #"^[^\s@]+@[^\s@.]+(\.[^\s@.]+)+$"#, options: .regularExpression) != nil
    }
}
