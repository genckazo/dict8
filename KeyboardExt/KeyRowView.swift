import UIKit

/// One row of keys. Widths are expressed in letter-key units (a tenth of the
/// row, like the system keyboard) so every row lines up on the same grid.
final class KeyRowView: UIView {
    enum Width {
        /// A multiple of the standard letter key width.
        case unit(CGFloat)
        /// Takes whatever space is left in the row.
        case flex
    }

    enum Item {
        case key(KeyButton, Width)
        /// Flexible empty space, used to centre shorter rows.
        case gap
    }

    var spacing: CGFloat = 6
    var edgeInset: CGFloat = 6.5
    /// Vertical space between this row's keys and the next row's.
    var rowGap: CGFloat = 11.7 {
        didSet { setNeedsLayout() }
    }

    private(set) var keys: [KeyButton] = []
    private var items: [Item] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        // Fully transparent areas of a keyboard extension do not receive touches.
        backgroundColor = UIColor(white: 0, alpha: 0.001)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setItems(_ newItems: [Item]) {
        keys.forEach { $0.removeFromSuperview() }
        items = newItems
        keys = newItems.compactMap { if case let .key(key, _) = $0 { return key } else { return nil } }
        keys.forEach { addSubview($0) }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !items.isEmpty else { return }
        let contentWidth = max(bounds.width - edgeInset * 2, 0)
        let unit = (contentWidth - spacing * 9) / 10

        // Fixed widths first, then split what is left between the flexible items.
        var fixed: CGFloat = 0
        var flexCount: CGFloat = 0
        var previousWasKey = false
        for item in items {
            switch item {
            case let .key(_, width):
                if previousWasKey { fixed += spacing }
                switch width {
                case let .unit(multiple): fixed += unit * multiple
                case .flex: flexCount += 1
                }
                previousWasKey = true
            case .gap:
                flexCount += 1
                previousWasKey = false
            }
        }
        let flexWidth = flexCount > 0 ? max((contentWidth - fixed) / flexCount, 0) : 0

        let keyHeight = max(bounds.height - rowGap, 0)
        let y = (bounds.height - keyHeight) / 2
        var x = edgeInset
        previousWasKey = false
        for item in items {
            switch item {
            case let .key(key, width):
                if previousWasKey { x += spacing }
                let keyWidth: CGFloat
                switch width {
                case let .unit(multiple): keyWidth = unit * multiple
                case .flex: keyWidth = flexWidth
                }
                key.frame = CGRect(x: x, y: y, width: keyWidth, height: keyHeight)
                x += keyWidth
                previousWasKey = true
            case .gap:
                x += flexWidth
                previousWasKey = false
            }
        }

        // Stretch each key's touch target halfway to its neighbours and out to the row edges.
        for (index, key) in keys.enumerated() {
            let left = index == 0 ? key.frame.minX : (key.frame.minX - keys[index - 1].frame.maxX) / 2
            let right = index == keys.count - 1
                ? bounds.width - key.frame.maxX
                : (keys[index + 1].frame.minX - key.frame.maxX) / 2
            key.touchOutsets = UIEdgeInsets(top: y, left: left, bottom: y, right: right)
        }
    }
}
