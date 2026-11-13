//
//  GamesViewController.swift
//  wishywashy
//
//  Pick a mini game to play while the laundry runs.
//

import UIKit

final class GamesViewController: UIViewController {

    private struct Entry {
        let emoji: String
        let title: String
        let blurb: String
        let tone: Theme.Tone
        let best: () -> String
        let make: () -> UIViewController
    }

    private let entries: [Entry] = [
        Entry(emoji: "🫧", title: "Bubble Pop", blurb: "Pop the bubbles before they float away", tone: .blue,
              best: { GameScores.bubblePopBest == 0 ? "No score yet" : "Best: \(GameScores.bubblePopBest) pts" },
              make: { BubblePopViewController() }),
        Entry(emoji: "🧦", title: "Sock Match", blurb: "Match the pairs as the levels get harder", tone: .pink,
              best: { GameScores.sockMatchBestLevel == 0 ? "No score yet" : "Best: level \(GameScores.sockMatchBestLevel)" },
              make: { SockMatchViewController() }),
        Entry(emoji: "🧺", title: "Laundry Sort", blurb: "Sort lights, darks and colors", tone: .lilac,
              best: { GameScores.laundrySortBest == 0 ? "No score yet" : "Best: \(GameScores.laundrySortBest) sorted" },
              make: { LaundrySortViewController() })
    ]

    private var bestLabels: [UILabel] = []
    private let contentStack = UIStackView()
    private let scrollView = UIScrollView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Play Time"
        view.backgroundColor = Theme.background

        contentStack.axis = .vertical
        contentStack.spacing = 18
        contentStack.addArrangedSubview(makeHeader())
        for (index, entry) in entries.enumerated() {
            contentStack.addArrangedSubview(makeCard(entry, index: index))
        }

        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Pick up any new best scores when coming back from a game
        for (label, entry) in zip(bestLabels, entries) { label.text = entry.best() }
    }

    // MARK: - Views
    private func makeHeader() -> UIView {
        let card = GradientView()
        let title = UILabel()
        title.text = "Pass the spin cycle ✨"
        title.font = Theme.font(24, .heavy)
        title.textColor = .white
        title.numberOfLines = 0
        let subtitle = UILabel()
        subtitle.text = "Quick games for while your laundry runs"
        subtitle.font = Theme.font(15, .medium)
        subtitle.textColor = UIColor.white.withAlphaComponent(0.92)
        subtitle.numberOfLines = 0
        let stack = UIStackView(arrangedSubviews: [title, subtitle])
        stack.axis = .vertical
        stack.spacing = 4
        card.addSubview(stack)
        stack.pin(to: card, insets: UIEdgeInsets(top: 22, left: 20, bottom: 22, right: 20))
        return card
    }

    private func makeCard(_ entry: Entry, index: Int) -> UIView {
        let card = CardView()
        card.tag = index

        let bubble = EmojiBubble(size: 60)
        bubble.configure(emoji: entry.emoji, tone: entry.tone)

        let title = UILabel()
        title.text = entry.title
        title.font = Theme.font(20, .heavy)
        title.textColor = Theme.ink
        let blurb = UILabel()
        blurb.text = entry.blurb
        blurb.font = Theme.font(14)
        blurb.textColor = Theme.inkSoft
        blurb.numberOfLines = 0
        let best = UILabel()
        best.font = Theme.font(14, .bold)
        best.textColor = entry.tone.tint
        bestLabels.append(best)

        let texts = UIStackView(arrangedSubviews: [title, blurb, best])
        texts.axis = .vertical
        texts.spacing = 3

        let play = IconBubble(size: 40, symbolSize: 16)
        play.configure(symbol: "play.fill", tone: .pink)

        let row = UIStackView(arrangedSubviews: [bubble, texts, play])
        row.spacing = 14
        row.alignment = .center
        card.addSubview(row)
        row.pin(to: card, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))

        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cardTapped(_:))))
        return card
    }

    @objc private func cardTapped(_ gesture: UITapGestureRecognizer) {
        guard let index = gesture.view?.tag, entries.indices.contains(index) else { return }
        let game = entries[index].make()
        game.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(game, animated: true)
    }
}

#Preview {
    UINavigationController(rootViewController: GamesViewController())
}
