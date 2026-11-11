//
//  LaundromatListViewController.swift
//  wishywashy
//
//  Lists laundromats with sort, search and selection.
//

import UIKit

final class LaundromatListViewController: UIViewController {
    
    var presenter: LaundromatListPresenterProtocol?
    
    private var laundromats: [LaundromatListViewModel] = []
    private var currentSort: SortingCriteria = .distance
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
    private let searchController = UISearchController(searchResultsController: nil)
    private let emptyLabel = UILabel()
    private let noticeLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let sortScrollView = UIScrollView()
    private let sortStack = UIStackView()
    private var sortButtons: [SortingCriteria: UIButton] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Choose Laundromat"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = Theme.background
        
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 16, right: 0)
        collectionView.register(LaundromatCell.self, forCellWithReuseIdentifier: LaundromatCell.identifier)
        view.addSubview(collectionView)
        
        emptyLabel.font = Theme.font(16, .semibold)
        emptyLabel.textColor = Theme.inkSoft
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0

        noticeLabel.font = Theme.font(13, .medium)
        noticeLabel.textColor = Theme.inkSoft
        noticeLabel.numberOfLines = 0
        noticeLabel.isHidden = true

        spinner.hidesWhenStopped = true
        spinner.color = Theme.pink
        
        setupSearch()
        setupSortChips()
        
        presenter?.viewDidLoad()
    }
    
    private func setupSearch() {
        // Searching a place hits the network, so it runs on Search instead of on every key
        searchController.searchBar.delegate = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search a place or postal code"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }
    
    // A visible "Sort by" row of chips above the list
    private func setupSortChips() {
        sortStack.axis = .horizontal
        sortStack.spacing = 8
        sortStack.alignment = .center

        let label = UILabel()
        label.text = "Sort by"
        label.font = Theme.font(14, .semibold)
        label.textColor = Theme.inkSoft
        sortStack.addArrangedSubview(label)

        for criteria in SortingCriteria.allCases {
            let button = UIButton(configuration: .filled())
            button.addAction(UIAction { [weak self] _ in
                guard let self, self.currentSort != criteria else { return }
                self.currentSort = criteria
                self.updateSortChipStyles()
                self.presenter?.didSelectSort(criteria)
            }, for: .touchUpInside)
            sortButtons[criteria] = button
            sortStack.addArrangedSubview(button)
        }
        updateSortChipStyles()

        sortScrollView.showsHorizontalScrollIndicator = false
        sortScrollView.alwaysBounceHorizontal = true
        [sortScrollView, noticeLabel, collectionView, spinner].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        sortScrollView.addSubview(sortStack)
        sortStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            sortScrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            sortScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sortScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sortScrollView.heightAnchor.constraint(equalToConstant: 48),

            sortStack.leadingAnchor.constraint(equalTo: sortScrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            sortStack.trailingAnchor.constraint(equalTo: sortScrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            sortStack.topAnchor.constraint(equalTo: sortScrollView.contentLayoutGuide.topAnchor),
            sortStack.bottomAnchor.constraint(equalTo: sortScrollView.contentLayoutGuide.bottomAnchor),
            sortStack.heightAnchor.constraint(equalTo: sortScrollView.frameLayoutGuide.heightAnchor),

            noticeLabel.topAnchor.constraint(equalTo: sortScrollView.bottomAnchor),
            noticeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            noticeLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: noticeLabel.bottomAnchor, constant: 24),

            collectionView.topAnchor.constraint(equalTo: noticeLabel.bottomAnchor, constant: 4),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func updateSortChipStyles() {
        for (criteria, button) in sortButtons {
            let isOn = criteria == currentSort
            var config = UIButton.Configuration.filled()
            config.title = criteria.title
            config.cornerStyle = .capsule
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
            config.baseBackgroundColor = isOn ? Theme.pink : Theme.Tone.pink.soft
            config.baseForegroundColor = isOn ? .white : Theme.ink
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = Theme.font(14, isOn ? .bold : .semibold)
                return attributes
            }
            button.configuration = config
        }
    }

    private func makeLayout() -> UICollectionViewLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .plain)
        config.backgroundColor = .clear
        config.showsSeparators = false
        return UICollectionViewCompositionalLayout.list(using: config)
    }
}

private extension SortingCriteria {
    var title: String {
        switch self {
        case .distance: return "Distance"
        case .rating: return "Rating"
        case .name: return "Name"
        case .price: return "Price"
        case .open: return "Open now"
        }
    }
}

extension LaundromatListViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        presenter?.didSearchLocation(searchBar.text ?? "")
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Clearing the field goes back to laundromats near the user
        if searchText.isEmpty { presenter?.didSearchLocation("") }
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        presenter?.didSearchLocation("")
    }
}

extension LaundromatListViewController: UICollectionViewDelegate {
    func collectionView(_ cv: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        presenter?.didSelectLaundromat(at: indexPath.item)
    }
}

extension LaundromatListViewController: UICollectionViewDataSource {
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return laundromats.count
    }
    func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell =
        collectionView.dequeueReusableCell(withReuseIdentifier: LaundromatCell.identifier, for: indexPath) as! LaundromatCell
        let item = laundromats[indexPath.item]
        cell.configure(name: item.name, address: item.address, distance: item.distance, rating: item.rating,
                       status: item.status, tone: item.tone, isSelected: item.isSelected, isSaved: item.isSaved, showsMachines: item.showsMachines,
                       washersFree: item.washersFree, dryersFree: item.dryersFree)
        cell.onToggleSave = { [weak self] in self?.presenter?.didToggleSaved(at: indexPath.item) }
        return cell
    }
}

extension LaundromatListViewController: LaundromatListViewProtocol {
    func showLoading(_ isLoading: Bool) {
        isLoading ? spinner.startAnimating() : spinner.stopAnimating()
    }

    func showLaundromats(_ items: [LaundromatListViewModel], notice: String?) {
        laundromats = items
        noticeLabel.text = notice
        noticeLabel.isHidden = notice == nil
        emptyLabel.text = "No laundromats found nearby.\nTry searching another place."
        collectionView.backgroundView = items.isEmpty ? emptyLabel : nil
        collectionView.reloadData()
    }

    func showError(_ message: String) {
        laundromats = []
        noticeLabel.isHidden = true
        emptyLabel.text = message
        collectionView.backgroundView = emptyLabel
        collectionView.reloadData()
    }
}

#Preview {
    UINavigationController(rootViewController: LaundromatListRouter.createModule())
}
