//
//  HomeViewController.swift
//  wishywashy
//
//  Created by Shofia Ghazali on 3/11/26.
//

import UIKit

// What one machine cell displays. Later the Presenter will build these from Machine entities.
struct MachineCardViewModel {
    let name: String
    let isAvailable: Bool
    let subtitle: String
    let priceText: String?
    let detailText: String?
}

final class HomeViewController: UIViewController {
    
    var presenter: HomePresenterProtocol?

    // Data shown in the grid (filled by the presenter through showMachines)
    private var machines: [MachineCardViewModel] = []

    // Header
    private let headerView = UIView()
    private let welcomeLabel = UILabel()
    private let nameLabel = UILabel()
    private let profileButton = UIButton(type: .system)

    // Selected laundromat
    private let selectedLaundromatCard = CardView()
    private let awningView = AwningView()
    private let selectedLaundromatStack = UIStackView()
    private let laundromatTitleLabel = UILabel()
    private let pinImageView = UIImageView()
    private let laundromatSubtitleLabel = UILabel()
    private let statusDotView = UIView()
    private let storeStatusLabel = UILabel()
    private let changeLocationButton = UIButton(type: .system)

    // Available machines
    private let availableMachinesLabel = UILabel()
    private let refreshButton = UIButton(type: .system)
    private let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        setupHeaderView()
        setupSelectedLaundromatCard()
        setupAvailableMachinesSection()
        setupCollectionView()
        setupConstraints()
        presenter?.viewDidLoad()
    }

    // The empty navigation bar only wasted space on Home
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - Setup
    private func setupHeaderView() {
        welcomeLabel.text = "Welcome back,"
        welcomeLabel.font = Theme.font(16, .medium)
        welcomeLabel.textColor = Theme.inkSoft

        nameLabel.text = "Customer Name"
        nameLabel.font = Theme.font(28, .heavy)
        nameLabel.textColor = Theme.ink

        profileButton.setImage(UIImage(systemName: "person.crop.circle.fill",
                                       withConfiguration: UIImage.SymbolConfiguration(pointSize: 36)),
                               for: .normal)
        profileButton.tintColor = Theme.pink
        // UI-only navigation to the Profile tab
        profileButton.addAction(UIAction { [weak self] _ in
            self?.tabBarController?.selectedIndex = 3
        }, for: .touchUpInside)

        [welcomeLabel, nameLabel, profileButton].forEach { headerView.addSubview($0) }
    }

    private func setupSelectedLaundromatCard() {
        laundromatTitleLabel.text = "Selected Laundromat"
        laundromatTitleLabel.font = Theme.font(22, .bold)
        laundromatTitleLabel.textColor = Theme.ink
        laundromatTitleLabel.numberOfLines = 0

        pinImageView.image = UIImage(systemName: "mappin.circle.fill")
        pinImageView.tintColor = Theme.pink
        pinImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 26)

        laundromatSubtitleLabel.text = "Your selected store location"
        laundromatSubtitleLabel.font = Theme.font(15)
        laundromatSubtitleLabel.textColor = Theme.inkSoft

        statusDotView.backgroundColor = Theme.Tone.mint.tint
        statusDotView.layer.cornerRadius = 5
        storeStatusLabel.text = "Store operating"
        storeStatusLabel.font = Theme.font(15, .semibold)
        storeStatusLabel.textColor = Theme.Tone.mint.tint
        let statusStack = UIStackView(arrangedSubviews: [statusDotView, storeStatusLabel])
        statusStack.spacing = 8
        statusStack.alignment = .center

        var config = UIButton.Configuration.plain()
        config.title = "Change location →"
        config.baseForegroundColor = Theme.pink
        config.contentInsets = .zero
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = Theme.font(15, .bold)
            return attributes
        }
        changeLocationButton.configuration = config
        // UI-only navigation until the presenter/router is hooked up
        changeLocationButton.addAction(UIAction { [weak self] _ in
            let list = LaundromatListViewController()
            list.hidesBottomBarWhenPushed = true
            self?.navigationController?.pushViewController(list, animated: true)
        }, for: .touchUpInside)

        selectedLaundromatStack.axis = .vertical
        selectedLaundromatStack.spacing = 8
        selectedLaundromatStack.alignment = .leading
        [laundromatTitleLabel, laundromatSubtitleLabel, statusStack, changeLocationButton]
            .forEach { selectedLaundromatStack.addArrangedSubview($0) }
    }

    private func setupAvailableMachinesSection() {
        availableMachinesLabel.text = "Available Machines"
        availableMachinesLabel.font = Theme.font(22, .bold)
        availableMachinesLabel.textColor = Theme.ink

        var config = UIButton.Configuration.plain()
        config.title = "Refresh"
        config.image = UIImage(systemName: "arrow.clockwise")
        config.imagePlacement = .trailing
        config.imagePadding = 4
        config.baseForegroundColor = Theme.pink
        config.contentInsets = .zero
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = Theme.font(15, .bold)
            return attributes
        }
        refreshButton.configuration = config

    }

    private func setupCollectionView() {
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.alwaysBounceVertical = true
        // Horizontal inset lives on the content so the card shadows are not clipped at the edges
        collectionView.contentInset = UIEdgeInsets(top: 8, left: 20, bottom: 16, right: 20)
        collectionView.register(MachineCell.self, forCellWithReuseIdentifier: MachineCell.identifier)
    }

    private func setupConstraints() {
        let views: [UIView] = [headerView, welcomeLabel, nameLabel, profileButton,
                               selectedLaundromatCard, selectedLaundromatStack, pinImageView, statusDotView,
                               availableMachinesLabel, refreshButton, collectionView]
        views.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        [headerView, selectedLaundromatCard, availableMachinesLabel, refreshButton, collectionView]
            .forEach { view.addSubview($0) }
        selectedLaundromatCard.addSubview(awningView)
        selectedLaundromatCard.addSubview(selectedLaundromatStack)
        selectedLaundromatCard.addSubview(pinImageView)

        refreshButton.setContentHuggingPriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            welcomeLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            welcomeLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            nameLabel.topAnchor.constraint(equalTo: welcomeLabel.bottomAnchor, constant: 2),
            nameLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            nameLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            profileButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            profileButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            selectedLaundromatCard.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            selectedLaundromatCard.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            selectedLaundromatCard.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),

            awningView.topAnchor.constraint(equalTo: selectedLaundromatCard.topAnchor),
            awningView.leadingAnchor.constraint(equalTo: selectedLaundromatCard.leadingAnchor),
            awningView.trailingAnchor.constraint(equalTo: selectedLaundromatCard.trailingAnchor),

            selectedLaundromatStack.topAnchor.constraint(equalTo: awningView.bottomAnchor, constant: 14),
            selectedLaundromatStack.leadingAnchor.constraint(equalTo: selectedLaundromatCard.leadingAnchor, constant: 16),
            selectedLaundromatStack.trailingAnchor.constraint(equalTo: selectedLaundromatCard.trailingAnchor, constant: -16),
            selectedLaundromatStack.bottomAnchor.constraint(equalTo: selectedLaundromatCard.bottomAnchor, constant: -16),

            pinImageView.topAnchor.constraint(equalTo: awningView.bottomAnchor, constant: 14),
            pinImageView.trailingAnchor.constraint(equalTo: selectedLaundromatCard.trailingAnchor, constant: -16),

            statusDotView.widthAnchor.constraint(equalToConstant: 10),
            statusDotView.heightAnchor.constraint(equalToConstant: 10),

            availableMachinesLabel.topAnchor.constraint(equalTo: selectedLaundromatCard.bottomAnchor, constant: 24),
            availableMachinesLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            refreshButton.centerYAnchor.constraint(equalTo: availableMachinesLabel.centerYAnchor),
            refreshButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),

            collectionView.topAnchor.constraint(equalTo: availableMachinesLabel.bottomAnchor, constant: 12),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
}

// MARK: - HomeViewProtocol (presenter -> view)
extension HomeViewController: HomeViewProtocol {
    func showUser(name: String) {
        nameLabel.text = name
    }

    func showLaundromat(name: String, isOperating: Bool) {
        laundromatTitleLabel.text = name
        storeStatusLabel.text = isOperating ? "Store operating" : "Store closed"
        let tint = (isOperating ? Theme.Tone.mint : Theme.Tone.pink).tint
        storeStatusLabel.textColor = tint
        statusDotView.backgroundColor = tint
    }

    func showMachines(_ machines: [MachineCardViewModel]) {
        self.machines = machines
        collectionView.reloadData()
    }
}

// MARK: - Collection view (2-column grid)
extension HomeViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        machines.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MachineCell.identifier, for: indexPath) as! MachineCell
        cell.configure(with: machines[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.bounds.width - 40 - 12) / 2
        return CGSize(width: width, height: 290)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat { 12 }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat { 12 }
}



#Preview {
    HomeViewController()
}
