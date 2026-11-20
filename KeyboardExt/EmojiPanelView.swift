import UIKit

/// Full emoji picker that replaces the keys while the emoji key is active.
final class EmojiPanelView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var onEmoji: ((String) -> Void)?
    var onDelete: (() -> Void)?
    var onClose: (() -> Void)?

    private struct Section {
        let symbol: String
        let emojis: [String]
    }

    private var sections: [Section] = []
    private let layout = UICollectionViewFlowLayout()
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    private let bar = UIStackView()
    private let closeButton = UIButton(type: .custom)
    private let deleteButton = UIButton(type: .custom)
    private var categoryButtons: [UIButton] = []
    private var theme = KeyboardTheme.dark

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0, alpha: 0.001)

        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 2
        layout.sectionInset = UIEdgeInsets(top: 2, left: 6, bottom: 8, right: 6)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(EmojiCell.self, forCellWithReuseIdentifier: "emoji")
        addSubview(collectionView)

        closeButton.setTitle("ABC", for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 16)
        closeButton.layer.cornerRadius = 5.5
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let deleteSymbol = UIImage.SymbolConfiguration(pointSize: 19, weight: .regular)
        deleteButton.setImage(UIImage(systemName: "delete.left", withConfiguration: deleteSymbol), for: .normal)
        deleteButton.layer.cornerRadius = 5.5
        deleteButton.accessibilityLabel = "Delete"
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)

        bar.axis = .horizontal
        bar.alignment = .fill
        bar.distribution = .fill
        bar.spacing = 2
        addSubview(bar)
        reload(recents: [])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func reload(recents: [String]) {
        var built: [Section] = []
        if !recents.isEmpty { built.append(Section(symbol: "clock", emojis: recents)) }
        built += EmojiCatalog.categories.map { Section(symbol: $0.symbol, emojis: $0.emojis) }
        sections = built

        bar.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let symbol = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        categoryButtons = sections.enumerated().map { index, section in
            let button = UIButton(type: .custom)
            button.tag = index
            button.setImage(UIImage(systemName: section.symbol, withConfiguration: symbol), for: .normal)
            button.addTarget(self, action: #selector(categoryTapped(_:)), for: .touchUpInside)
            return button
        }
        bar.addArrangedSubview(closeButton)
        categoryButtons.forEach { bar.addArrangedSubview($0) }
        bar.addArrangedSubview(deleteButton)
        closeButton.widthAnchor.constraint(equalToConstant: 52).isActive = true
        deleteButton.widthAnchor.constraint(equalToConstant: 46).isActive = true
        if let first = categoryButtons.first {
            categoryButtons.dropFirst().forEach { $0.widthAnchor.constraint(equalTo: first.widthAnchor).isActive = true }
        }
        collectionView.reloadData()
        collectionView.contentOffset = .zero
        apply(theme: theme)
    }

    func apply(theme newTheme: KeyboardTheme) {
        theme = newTheme
        closeButton.backgroundColor = theme.key
        closeButton.setTitleColor(theme.label, for: .normal)
        deleteButton.backgroundColor = theme.key
        deleteButton.tintColor = theme.label
        categoryButtons.forEach { $0.tintColor = theme.secondaryLabel }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let barHeight: CGFloat = 38
        bar.frame = CGRect(x: 6.5, y: bounds.height - barHeight - 6, width: bounds.width - 13, height: barHeight)
        collectionView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bar.frame.minY - 4)
        let columns = max(floor((bounds.width - 12) / 44), 6)
        layout.itemSize = CGSize(width: floor((bounds.width - 12) / columns), height: 40)
    }

    // MARK: - Collection view

    func numberOfSections(in collectionView: UICollectionView) -> Int { sections.count }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].emojis.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "emoji", for: indexPath)
        (cell as? EmojiCell)?.label.text = sections[indexPath.section].emojis[indexPath.item]
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onEmoji?(sections[indexPath.section].emojis[indexPath.item])
    }

    @objc private func categoryTapped(_ sender: UIButton) {
        guard sender.tag < sections.count, !sections[sender.tag].emojis.isEmpty else { return }
        collectionView.scrollToItem(at: IndexPath(item: 0, section: sender.tag), at: .top, animated: false)
    }

    @objc private func closeTapped() { onClose?() }
    @objc private func deleteTapped() { onDelete?() }
}

private final class EmojiCell: UICollectionViewCell {
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 30)
        label.textAlignment = .center
        label.frame = contentView.bounds
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
