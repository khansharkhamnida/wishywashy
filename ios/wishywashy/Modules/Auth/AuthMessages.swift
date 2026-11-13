//
//  AuthMessages.swift
//  wishywashy
//
//  Friendly text for each auth error. The raw API message is never shown.
//

import Foundation

enum AuthMessages {
    static func text(for error: AuthError) -> String {
        switch error {
        case .invalidCredentials:
            "That email or password isn't right. Check them and try again."
        case .emailNotConfirmed:
            "Please confirm your email first. Open the link we sent you, then sign in."
        case .emailAlreadyRegistered:
            "That email already has an account. Try signing in instead."
        case .invalidEmail:
            "That doesn't look like a valid email address."
        case .weakPassword:
            "Choose a stronger password with at least \(AuthValidation.minPasswordLength) characters, mixing letters and numbers."
        case .signUpDisabled:
            "New accounts can't be created right now. Please try again later."
        case .rateLimited:
            "Too many tries. Wait a minute and try again."
        case .offline:
            "Can't reach WishyWashy. Check your internet connection and try again."
        case .sessionExpired:
            "Your session ended. Please sign in again."
        case .notConfigured:
            "Live mode needs -supabaseURL and -supabaseAnonKey launch arguments."
        case .server, .unknown:
            "Something went wrong on our side. Please try again."
        }
    }
}
