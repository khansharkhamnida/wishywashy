//
//  LaundromatListInteractor.swift
//  wishywashy
//
//  Created by Shofia Ghazali on 3/11/26.
//
/*
import Foundation

protocol LaundromatListInteractorInputProtocol: AnyObject {
    var output: LaundromatListInteractorOutputProtocol? { get set }
    func fetchLaundromats()
}

protocol LaundromatListInteractorOutputProtocol: AnyObject {
    func didFetchLaundromats(_ laundromats: [Laundromat])
    func didFail(with error: Error)
}

final class LaundromatListInteractor: LaundromatListInteractorInputProtocol {
    weak var output: LaundromatListInteractorOutputProtocol?   // weak avoids a retain cycle
    private let service: LaundromatServiceProtocol         // injected, not created inside

    init(service: LaundromatServiceProtocol) {
        self.service = service
    }

    func fetchLaundromats() {
        // 1. call the service
        // 2. apply rules (filter, sort, validate)
        // 3. report via output
    }
}

*/
