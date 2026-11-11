//
//  SavedLaundromatsViewController.swift
//  wishywashy
//

import UIKit

final class SavedLaundromatsViewController: ProfilePageViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Saved Laundromats"
        navigationItem.largeTitleDisplayMode = .never
        reload()
    }

    private func reload() {
        let saved = LaundromatStore.shared.saved
        guard !saved.isEmpty else {
            setContent([ProfileUI.caption("No saved laundromats yet. Tap the heart on a laundromat in Choose Laundromat to save it.")])
            return
        }
        setContent([ProfileUI.card(rows: saved.map(makeRow))])
    }

    private func makeRow(for laundromat: Laundromat) -> UIView {
        let heart = UIButton(type: .system)
        heart.setImage(UIImage(systemName: "heart.fill"), for: .normal)
        heart.tintColor = Theme.pink
        heart.setContentHuggingPriority(.required, for: .horizontal)
        heart.accessibilityLabel = "Remove from saved"
        heart.addAction(UIAction { [weak self] _ in
            LaundromatStore.shared.toggleSaved(laundromat)
            self?.reload()
        }, for: .touchUpInside)

        return ProfileRowView(title: laundromat.name, subtitle: laundromat.address,
                              symbol: "washer.fill", tone: .peach, accessory: heart)
    }
}

#Preview {
    UINavigationController(rootViewController: SavedLaundromatsViewController())
}
