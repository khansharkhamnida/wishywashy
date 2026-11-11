//
//  Money.swift
//  wishywashy
//

import Foundation

enum Money {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    /// e.g. 6 becomes "S$6.00"
    static func string(_ amount: Decimal) -> String {
        "S$" + (formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)")
    }
}
