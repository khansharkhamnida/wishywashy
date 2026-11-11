//
//  ReserveViewController.swift
//  wishywashy
//
//  Bottom sheet to reserve a machine now, or book it for later.
//

import UIKit

final class ReserveViewController: UIViewController {
    var presenter: ReservePresenterProtocol?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let titleLabel = UILabel()
    private let modeControl = UISegmentedControl(items: ["Now", "Later"])
    private let nowLabel = UILabel()
    private let dayControl = UISegmentedControl()
    private let slotsStack = UIStackView()
    private let slotsEmptyLabel = UILabel()
    private let noteLabel = UILabel()
    private let errorLabel = UILabel()
    private let reserveButton = UIButton(type: .system)
    private var cardView: UIView?
    private var shownDayTitles: [String] = []

    private let slotsPerRow = 4

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background

        titleLabel.text = "Reserve machine"
        titleLabel.font = Theme.font(22, .bold)
        titleLabel.textColor = Theme.ink

        styleSegmented(modeControl)
        styleSegmented(dayControl)
        modeControl.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            let mode: ReserveMode = self.modeControl.selectedSegmentIndex == 0 ? .now : .later
            if mode == .later { self.expandSheet() }
            self.presenter?.didSelectMode(mode)
        }, for: .valueChanged)
        dayControl.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.presenter?.didSelectDay(at: self.dayControl.selectedSegmentIndex)
        }, for: .valueChanged)

        [nowLabel, slotsEmptyLabel, noteLabel].forEach {
            $0.font = Theme.font(14, .medium)
            $0.textColor = Theme.inkSoft
            $0.numberOfLines = 0
        }
        errorLabel.font = Theme.font(14, .semibold)
        errorLabel.textColor = Theme.Tone.pink.tint
        errorLabel.numberOfLines = 0

        slotsStack.axis = .vertical
        slotsStack.spacing = 8

        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.baseBackgroundColor = Theme.pink
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = Theme.font(17, .bold)
            return attributes
        }
        reserveButton.configuration = config
        reserveButton.addAction(UIAction { [weak self] _ in self?.presenter?.didTapReserve() }, for: .touchUpInside)

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Not now", for: .normal)
        cancelButton.titleLabel?.font = Theme.font(16, .semibold)
        cancelButton.tintColor = Theme.inkSoft
        cancelButton.addAction(UIAction { [weak self] _ in self?.presenter?.didTapCancel() }, for: .touchUpInside)

        contentStack.axis = .vertical
        contentStack.spacing = 14
        // The machine card goes in at index 1 once it is known
        [titleLabel, modeControl, nowLabel, dayControl, slotsStack, slotsEmptyLabel, errorLabel, noteLabel]
            .forEach { contentStack.addArrangedSubview($0) }

        let buttons = UIStackView(arrangedSubviews: [reserveButton, cancelButton])
        buttons.axis = .vertical
        buttons.spacing = 4

        [scrollView, buttons].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        scrollView.addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -8),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 28),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -8),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),

            buttons.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttons.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttons.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])

        presenter?.viewDidLoad()
    }

    private func expandSheet() {
        sheetPresentationController?.animateChanges {
            sheetPresentationController?.selectedDetentIdentifier = .large
        }
    }

    private func styleSegmented(_ control: UISegmentedControl) {
        control.selectedSegmentTintColor = Theme.pink
        control.backgroundColor = Theme.Tone.pink.soft
        control.setTitleTextAttributes([.font: Theme.font(14, .semibold), .foregroundColor: Theme.inkSoft], for: .normal)
        control.setTitleTextAttributes([.font: Theme.font(14, .bold), .foregroundColor: UIColor.white], for: .selected)
    }

    private func makeSlotButton(_ slot: SlotViewModel, index: Int) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = slot.title
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4)
        config.baseBackgroundColor = slot.isSelected ? Theme.pink : Theme.Tone.pink.soft
        config.baseForegroundColor = slot.isSelected ? .white : Theme.ink
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = Theme.font(14, slot.isSelected ? .bold : .semibold)
            return attributes
        }
        let button = UIButton(configuration: config)
        button.addAction(UIAction { [weak self] _ in self?.presenter?.didSelectSlot(at: index) }, for: .touchUpInside)
        return button
    }
}

extension ReserveViewController: ReserveViewProtocol {
    func render(_ model: ReserveViewModel) {
        let tone: Theme.Tone = model.icon == "dryer" ? .blue : .mint
        cardView?.removeFromSuperview()
        let card = ProfileUI.card(rows: [
            ProfileRowView(title: model.machineTitle, subtitle: model.machineSubtitle, symbol: model.icon, tone: tone),
            ProfileRowView(title: model.priceText, subtitle: model.cycleText, symbol: "tag.fill", tone: .pink)
        ])
        contentStack.insertArrangedSubview(card, at: 1)
        cardView = card

        let isNow = model.mode == .now
        modeControl.selectedSegmentIndex = isNow ? 0 : 1
        nowLabel.text = model.nowText
        nowLabel.isHidden = !isNow

        if model.dayTitles != shownDayTitles {
            dayControl.removeAllSegments()
            for (index, title) in model.dayTitles.enumerated() {
                dayControl.insertSegment(withTitle: title, at: index, animated: false)
            }
            shownDayTitles = model.dayTitles
        }
        dayControl.selectedSegmentIndex = model.selectedDay
        dayControl.isHidden = isNow

        slotsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let buttons = model.slots.enumerated().map { makeSlotButton($1, index: $0) }
        for start in stride(from: 0, to: buttons.count, by: slotsPerRow) {
            let chunk = Array(buttons[start..<min(start + slotsPerRow, buttons.count)])
            // Pad the last row so every chip keeps the same width
            let padding = (0..<(slotsPerRow - chunk.count)).map { _ in UIView() }
            let row = UIStackView(arrangedSubviews: chunk + padding)
            row.distribution = .fillEqually
            row.spacing = 8
            slotsStack.addArrangedSubview(row)
        }
        slotsStack.isHidden = isNow
        slotsEmptyLabel.text = model.slotsEmptyText
        slotsEmptyLabel.isHidden = isNow || model.slotsEmptyText == nil

        errorLabel.text = model.errorMessage
        errorLabel.isHidden = model.errorMessage == nil
        noteLabel.text = model.paymentNote

        reserveButton.configuration?.title = model.buttonTitle
        reserveButton.isEnabled = model.isButtonEnabled
    }

    func showReserving(_ isReserving: Bool) {
        reserveButton.configuration?.showsActivityIndicator = isReserving
        if isReserving { reserveButton.isEnabled = false }
    }
}
