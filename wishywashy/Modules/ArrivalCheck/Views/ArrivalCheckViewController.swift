//
//  ArrivalCheckViewController.swift
//  wishywashy
//
//  Sheet that checks whether the user can reach the laundromat in time and offers a leave reminder.
//

import UIKit

final class ArrivalCheckViewController: UIViewController {
    var presenter: ArrivalCheckPresenterProtocol?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let titleLabel = UILabel()
    private var cardView: UIView?
    private let modeControl = UISegmentedControl()
    private var shownModeTitles: [String] = []
    private let privacyLabel = UILabel()

    // Manual input
    private let manualStack = UIStackView()
    private let manualMessageLabel = UILabel()
    private let placeField = UITextField()
    private let minutesLabel = UILabel()
    private let minutesStepper = UIStepper()

    // Result
    private let resultCard = CardView()
    private let verdictLabel = UILabel()
    private let detailLabel = UILabel()
    private let leaveByLabel = UILabel()
    private let countdownLabel = UILabel()
    private let estimateLabel = UILabel()
    private let reminderSwitch = UISwitch()
    private let reminderStatusLabel = UILabel()
    private let settingsButton = UIButton(type: .system)

    private let errorLabel = UILabel()
    private let checkButton = UIButton(type: .system)
    private var refreshTimer: Timer?
    private var isShowingError = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background

        titleLabel.text = "Can I arrive on time?"
        titleLabel.font = Theme.font(22, .bold)
        titleLabel.textColor = Theme.ink

        modeControl.selectedSegmentTintColor = Theme.pink
        modeControl.backgroundColor = Theme.Tone.pink.soft
        modeControl.setTitleTextAttributes([.font: Theme.font(14, .semibold), .foregroundColor: Theme.inkSoft], for: .normal)
        modeControl.setTitleTextAttributes([.font: Theme.font(14, .bold), .foregroundColor: UIColor.white], for: .selected)
        modeControl.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.presenter?.didSelectMode(at: self.modeControl.selectedSegmentIndex)
        }, for: .valueChanged)

        [privacyLabel, manualMessageLabel, estimateLabel, reminderStatusLabel].forEach {
            $0.font = Theme.font(13, .medium)
            $0.textColor = Theme.inkSoft
            $0.numberOfLines = 0
        }
        errorLabel.font = Theme.font(14, .semibold)
        errorLabel.textColor = Theme.Tone.pink.tint
        errorLabel.numberOfLines = 0

        setUpManualInput()
        setUpResultCard()
        setUpCheckButton()

        contentStack.axis = .vertical
        contentStack.spacing = 14
        // The booking card goes in at index 1 once it is known
        [titleLabel, modeControl, privacyLabel, manualStack, resultCard, errorLabel]
            .forEach { contentStack.addArrangedSubview($0) }
        manualStack.isHidden = true
        resultCard.isHidden = true
        errorLabel.isHidden = true

        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Done", for: .normal)
        closeButton.titleLabel?.font = Theme.font(16, .semibold)
        closeButton.tintColor = Theme.inkSoft
        closeButton.addAction(UIAction { [weak self] _ in self?.presenter?.didTapClose() }, for: .touchUpInside)

        let buttons = UIStackView(arrangedSubviews: [checkButton, closeButton])
        buttons.axis = .vertical
        buttons.spacing = 4

        [scrollView, buttons].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        scrollView.addSubview(contentStack)
        scrollView.keyboardDismissMode = .interactive
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshTimer?.invalidate()
        // Keeps the "leave in X min" countdown current while the sheet is open
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.presenter?.didRequestRefresh()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Setup
    private func setUpManualInput() {
        placeField.placeholder = "Starting place, e.g. Bedok or 460123 (optional)"
        placeField.font = Theme.font(15, .medium)
        placeField.textColor = Theme.ink
        placeField.borderStyle = .roundedRect
        placeField.returnKeyType = .done
        placeField.autocorrectionType = .no
        placeField.addAction(UIAction { [weak self] _ in self?.placeField.resignFirstResponder() }, for: .editingDidEndOnExit)

        minutesLabel.font = Theme.font(15, .semibold)
        minutesLabel.textColor = Theme.ink
        minutesStepper.minimumValue = 1
        minutesStepper.maximumValue = 240
        minutesStepper.stepValue = 5
        minutesStepper.value = 20
        minutesStepper.addAction(UIAction { [weak self] _ in self?.updateMinutesLabel() }, for: .valueChanged)
        updateMinutesLabel()
        let minutesRow = UIStackView(arrangedSubviews: [minutesLabel, UIView(), minutesStepper])
        minutesRow.alignment = .center

        var config = UIButton.Configuration.tinted()
        config.title = "Calculate"
        config.cornerStyle = .capsule
        config.baseBackgroundColor = Theme.pink
        config.baseForegroundColor = Theme.pink
        let calculate = UIButton(configuration: config)
        calculate.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.placeField.resignFirstResponder()
            self.presenter?.didTapCalculateManually(place: self.placeField.text ?? "", minutes: Int(self.minutesStepper.value))
        }, for: .touchUpInside)

        manualStack.axis = .vertical
        manualStack.spacing = 10
        [manualMessageLabel, placeField, minutesRow, calculate].forEach { manualStack.addArrangedSubview($0) }
    }

    private func updateMinutesLabel() {
        minutesLabel.text = "Travel time: \(Int(minutesStepper.value)) min"
    }

    private func setUpResultCard() {
        verdictLabel.font = Theme.font(19, .heavy)
        verdictLabel.numberOfLines = 0
        detailLabel.font = Theme.font(14, .medium)
        detailLabel.textColor = Theme.inkSoft
        detailLabel.numberOfLines = 0
        leaveByLabel.font = Theme.font(28, .heavy)
        leaveByLabel.textColor = Theme.ink
        countdownLabel.font = Theme.font(15, .bold)
        countdownLabel.textColor = Theme.pink

        reminderSwitch.onTintColor = Theme.pink
        reminderSwitch.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.presenter?.didToggleReminder(self.reminderSwitch.isOn)
        }, for: .valueChanged)
        let reminderTitle = UILabel()
        reminderTitle.text = "Remind me to leave"
        reminderTitle.font = Theme.font(16, .semibold)
        reminderTitle.textColor = Theme.ink
        let reminderRow = UIStackView(arrangedSubviews: [reminderTitle, UIView(), reminderSwitch])
        reminderRow.alignment = .center

        settingsButton.setTitle("Open Settings", for: .normal)
        settingsButton.titleLabel?.font = Theme.font(14, .semibold)
        settingsButton.tintColor = Theme.pink
        settingsButton.contentHorizontalAlignment = .leading
        settingsButton.addAction(UIAction { [weak self] _ in self?.presenter?.didTapOpenSettings() }, for: .touchUpInside)

        let divider = UIView()
        divider.backgroundColor = Theme.stroke
        divider.heightAnchor.constraint(equalToConstant: 1.5).isActive = true

        let stack = UIStackView(arrangedSubviews: [verdictLabel, detailLabel, leaveByLabel, countdownLabel,
                                                   estimateLabel, divider, reminderRow, reminderStatusLabel, settingsButton])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(14, after: detailLabel)
        stack.setCustomSpacing(14, after: estimateLabel)
        resultCard.addSubview(stack)
        stack.pin(to: resultCard, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
    }

    private func setUpCheckButton() {
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
        checkButton.configuration = config
        checkButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            if self.isShowingError { self.presenter?.didTapClose() } else { self.presenter?.didTapCheck() }
        }, for: .touchUpInside)
    }
}

extension ArrivalCheckViewController: ArrivalCheckViewProtocol {
    func render(_ model: ArrivalCheckViewModel) {
        let tone: Theme.Tone = model.icon == "dryer" ? .blue : .mint
        cardView?.removeFromSuperview()
        let card = ProfileUI.card(rows: [
            ProfileRowView(title: model.machineTitle, subtitle: model.placeText, symbol: model.icon, tone: tone),
            ProfileRowView(title: model.arriveByText, subtitle: "Your booking's start time", symbol: "clock.fill", tone: .peach)
        ])
        contentStack.insertArrangedSubview(card, at: 1)
        cardView = card

        if model.modeTitles != shownModeTitles {
            modeControl.removeAllSegments()
            for (index, title) in model.modeTitles.enumerated() {
                modeControl.insertSegment(withTitle: title, at: index, animated: false)
            }
            shownModeTitles = model.modeTitles
        }
        modeControl.selectedSegmentIndex = model.modeIndex
        modeControl.isHidden = model.modeTitles.isEmpty
        privacyLabel.text = model.privacyNote
        privacyLabel.isHidden = model.result != nil || model.privacyNote.isEmpty

        manualStack.isHidden = model.manualMessage == nil
        manualMessageLabel.text = model.manualMessage
        if minutesStepper.value != Double(model.manualMinutes) {
            minutesStepper.value = Double(model.manualMinutes)
            updateMinutesLabel()
        }

        if let result = model.result {
            resultCard.isHidden = false
            verdictLabel.text = result.verdictText
            verdictLabel.textColor = result.verdictTone.tint
            detailLabel.text = result.detailText
            leaveByLabel.text = result.leaveByText
            countdownLabel.text = result.countdownText
            countdownLabel.isHidden = result.countdownText == nil
            estimateLabel.text = result.estimateNote
            reminderSwitch.setOn(result.reminder.isOn, animated: true)
            reminderSwitch.isEnabled = result.reminder.isEnabled
            reminderStatusLabel.text = result.reminder.statusText
            settingsButton.isHidden = !result.reminder.showsSettingsButton
        } else {
            resultCard.isHidden = true
        }

        errorLabel.text = model.errorMessage
        errorLabel.isHidden = model.errorMessage == nil
        isShowingError = model.modeTitles.isEmpty

        checkButton.configuration?.title = model.checkButtonTitle
        checkButton.configuration?.showsActivityIndicator = model.isLoading
        checkButton.isEnabled = !model.isLoading
    }
}
