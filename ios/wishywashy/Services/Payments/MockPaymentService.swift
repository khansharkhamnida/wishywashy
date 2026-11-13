//
//  MockPaymentService.swift
//  wishywashy
//

import UIKit

/// A test payment sheet. No real money moves.
final class MockPaymentService: PaymentService {

    func pay(_ request: PaymentRequest, from viewController: UIViewController) async -> PaymentOutcome {
        let choice = await askForMethod(request, on: viewController)
        switch choice {
        case .cancelled:
            return .cancelled
        case .declined:
            try? await Task.sleep(for: .seconds(0.8))
            return .failed("Your card was declined. Try another way to pay.")
        case .method(let method):
            try? await Task.sleep(for: .seconds(0.8))
            return .paid(Payment(id: "test_\(UUID().uuidString.prefix(10))",
                                 bookingId: request.bookingId,
                                 userId: Session.user.id,
                                 amount: request.amount,
                                 currency: request.currency,
                                 method: method,
                                 status: .succeeded,
                                 createdAt: Date()))
        }
    }

    private enum Choice {
        case method(PaymentMethod)
        case declined
        case cancelled
    }

    private func askForMethod(_ request: PaymentRequest, on viewController: UIViewController) async -> Choice {
        await withCheckedContinuation { continuation in
            let sheet = UIAlertController(title: "Pay \(Money.string(request.amount))",
                                          message: "\(request.description)\nTest payment sheet: no real money moves.",
                                          preferredStyle: .actionSheet)
            let options: [(String, Choice)] = [
                ("Visa •••• 4242", .method(.card)),
                ("Mastercard •••• 5555", .method(.card)),
                ("PayNow", .method(.payNow)),
                ("Apple Pay", .method(.applePay)),
                ("Simulate a declined card", .declined)
            ]
            for (title, choice) in options {
                sheet.addAction(UIAlertAction(title: title, style: .default) { _ in continuation.resume(returning: choice) })
            }
            sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in continuation.resume(returning: .cancelled) })
            sheet.popoverPresentationController?.sourceView = viewController.view
            sheet.popoverPresentationController?.sourceRect = CGRect(x: viewController.view.bounds.midX,
                                                                     y: viewController.view.bounds.midY, width: 0, height: 0)
            (viewController.presentedViewController ?? viewController).present(sheet, animated: true)
        }
    }
}
