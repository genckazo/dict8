import UIKit

/// Lays keys out edge to edge with per-key weights, like the system keyboard.
final class KeyRowView: UIView {
    var spacing: CGFloat = 6
    var horizontalInset: CGFloat = 0
    private(set) var keys: [KeyButton] = []
    private var weights: [CGFloat] = []

    func setKeys(_ newKeys: [KeyButton], weights newWeights: [CGFloat]) {
        keys.forEach { $0.removeFromSuperview() }
        keys = newKeys
        weights = newWeights
        newKeys.forEach { addSubview($0) }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !keys.isEmpty, keys.count == weights.count else { return }
        let totalWeight = weights.reduce(0, +)
        let gaps = spacing * CGFloat(keys.count - 1)
        let usable = max(bounds.width - gaps - horizontalInset * 2, 0)
        var x: CGFloat = horizontalInset
        for (index, key) in keys.enumerated() {
            let width = usable * weights[index] / totalWeight
            key.frame = CGRect(x: x, y: 0, width: width, height: bounds.height)
            x += width + spacing
        }
    }
}
