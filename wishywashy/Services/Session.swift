//
//  Session.swift
//  wishywashy
//

import Foundation

/// Who is using the app. Fixed until there is a login.
enum Session {
    static let user = User(id: "u1",
                           name: "Shofia",
                           email: "shofia@example.com",
                           phoneNumber: nil)
}
