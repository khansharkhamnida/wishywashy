//
//  Session.swift
//  wishywashy
//

import Foundation

/// Who is using the app. The fixed sample user in sample mode, the signed-in user in live mode.
enum Session {
    static let sampleUser = User(id: "u1",
                                 name: "Shofia",
                                 email: "shofia@example.com",
                                 phoneNumber: nil)

    static var user: User { Services.auth.currentUser ?? sampleUser }
}
