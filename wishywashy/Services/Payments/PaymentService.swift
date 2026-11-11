//
//  PaymentService.swift
//  wishywashy
//

import UIKit

struct PaymentRequest {
    let bookingId: String
    let amount: Decimal
    let currency: String
    let description: String
}

enum PaymentOutcome {
    case paid(Payment)
    case cancelled
    case failed(String)
}

/// Collects a payment from the user. The app never sees real card numbers.
protocol PaymentService {
    func pay(_ request: PaymentRequest, from viewController: UIViewController) async -> PaymentOutcome
}

enum PaymentServices {
    static var current: PaymentService { MockPaymentService() }
}
