//
//  LaundromatListProtocols.swift
//  wishywashy
//
import UIKit

/// Everything the Presenter needs to draw the list
struct LaundromatListResult {
    let laundromats: [Laundromat]
    let selectedId: String
    let savedIds: Set<String>
    /// A short note shown above the list, e.g. when location is off
    let notice: String?
}

protocol LaundromatListViewProtocol: AnyObject {
    func showLoading(_ isLoading: Bool)
    func showLaundromats(_ items: [LaundromatListViewModel], notice: String?)
    func showError(_ message: String)
}

protocol LaundromatListPresenterProtocol: AnyObject {
    func viewDidLoad()
    func didSelectLaundromat(at index: Int)
    func didSelectSort(_ criteria: SortingCriteria)
    func didToggleSaved(at index: Int)
    /// Empty text goes back to laundromats near the user
    func didSearchLocation(_ query: String)
}

protocol LaundromatListInteractorInputProtocol: AnyObject {
    func fetchLaundromats()
    func sortLaundromats(by criteria: SortingCriteria)
    func searchLocation(_ query: String)
    func selectLaundromat(id: String)
    func toggleSaved(id: String)
}

protocol LaundromatListInteractorOutputProtocol: AnyObject {
    func didStartLoading()
    func didFetchLaundromats(_ result: LaundromatListResult)
    func didFail(message: String)
}

protocol LaundromatListRouterProtocol: AnyObject {
    static func createModule() -> UIViewController
    func close()
}
