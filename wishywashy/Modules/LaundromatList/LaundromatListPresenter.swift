//
//  LaundromatListPresenter.swift
//  wishywashy
//
//  Created by Shofia Ghazali on 3/11/26.
//
/*
 protocol LaundromatListPresenterProtocol: AnyObject {
 func viewDidLoad()
 func didTapRetry()
 func didSelectLaundromat(at index: Int)
 // later: didChangeSearchText(_:), didTapFilter()
 }
 
 class LaundromatListPresenter{
 private weak var view: LaundromatListViewProtocol?   // weak
 private let interactor: LaundromatListInteractorInputProtocol
 private let router: LaundromatListRouterProtocol
 
 // LaundromatListInteractorOutputProtocol
 func didFetchLaundromats(_ laundromats: [Laundromat])
 func didFail(with error: Error)
 
 /*
  Tell the View which state to show: loading, list, empty, error.
  Convert Laundromat into a view model with display strings, e.g. distanceMeters 850 becomes "850 m", isOpenNow becomes "Open" or "Closed", and rating becomes "4.5 ★".
  Turn errors into user-friendly messages (location denied, no internet, nothing found).
  Keep a copy of the fetched [Laundromat], so didSelectLaundromat(at:) can find the right entity to pass to the Router.
  */
 
 func didSelectLaundromat(at index: Int) {
 router.navigateToDetail(with: laundromats[index])
 }
 }
 
 */
