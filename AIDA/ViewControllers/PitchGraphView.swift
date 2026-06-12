import UIKit

/// A live graph of the last 15 seconds of device pitch, drawn with CoreGraphics.
/// The line is red while pitch is in the detection zone (20°–70°), green outside.
/// Includes labelled X (time) and Y (degrees) axes and dashed threshold lines.
final class PitchGraphView: UIView {
    private let windowSeconds: Double = 15
    private let sampleRate: Double = 10            // Hz
    private let minDegrees: Double = -90
    private let maxDegrees: Double = 90
    private let lowerBound: Double = 0
    private let upperBound: Double = 70

    private let leftInset: CGFloat = 32
    private let bottomInset: CGFloat = 16
    private let topInset: CGFloat = 6
    private let rightInset: CGFloat = 8

    private var samples: [Double] = []
    private var maxSamples: Int { Int(windowSeconds * sampleRate) }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.cardBackground
        layer.cornerRadius = 12
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addSample(_ pitch: Double) {
        samples.append(pitch)
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let plot = CGRect(x: leftInset,
                          y: topInset,
                          width: rect.width - leftInset - rightInset,
                          height: rect.height - topInset - bottomInset)

        drawAxes(in: plot, context: context)
        drawThreshold(lowerBound, in: plot, context: context)
        drawThreshold(upperBound, in: plot, context: context)
        drawLine(in: plot, context: context)
    }

    // MARK: - Axes

    private func drawAxes(in plot: CGRect, context: CGContext) {
        let gridColor = UIColor.separator
        let labelColor = UIColor.secondaryLabel

        // Y: degree gridlines + labels.
        for value in [90.0, 45, 0, -45, -90] {
            let y = yPosition(forValue: value, in: plot)
            context.setStrokeColor(gridColor.withAlphaComponent(0.4).cgColor)
            context.setLineWidth(0.5)
            context.beginPath()
            context.move(to: CGPoint(x: plot.minX, y: y))
            context.addLine(to: CGPoint(x: plot.maxX, y: y))
            context.strokePath()
            drawText("\(Int(value))",
                     in: CGRect(x: 0, y: y - 6, width: leftInset - 5, height: 12),
                     color: labelColor, align: .right)
        }

        // X: time labels (seconds ago; right edge = now).
        for secondsAgo in [0.0, 5, 10, 15] {
            let x = plot.maxX - CGFloat(secondsAgo / windowSeconds) * plot.width
            let title = secondsAgo == 0 ? "0s" : "\(Int(secondsAgo))s"
            drawText(title,
                     in: CGRect(x: x - 16, y: plot.maxY + 2, width: 32, height: 12),
                     color: labelColor, align: .center)
        }
    }

    private func drawThreshold(_ degrees: Double, in plot: CGRect, context: CGContext) {
        let y = yPosition(forValue: degrees, in: plot)
        context.setStrokeColor(UIColor.systemOrange.cgColor)
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [4, 4])
        context.beginPath()
        context.move(to: CGPoint(x: plot.minX, y: y))
        context.addLine(to: CGPoint(x: plot.maxX, y: y))
        context.strokePath()
        context.setLineDash(phase: 0, lengths: [])
        drawText("\(Int(degrees))°",
                 in: CGRect(x: plot.minX + 2, y: y - 12, width: 30, height: 11),
                 color: .systemOrange, align: .left)
    }

    private func drawLine(in plot: CGRect, context: CGContext) {
        guard samples.count >= 2 else { return }
        context.setLineWidth(2.5)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        for index in 1..<samples.count {
            let p0 = point(forIndex: index - 1, value: samples[index - 1], in: plot)
            let p1 = point(forIndex: index, value: samples[index], in: plot)
            let inZone = samples[index] >= lowerBound && samples[index] <= upperBound
            context.setStrokeColor((inZone ? UIColor.systemRed : UIColor.systemGreen).cgColor)
            context.beginPath()
            context.move(to: p0)
            context.addLine(to: p1)
            context.strokePath()
        }
    }

    // MARK: - Helpers

    private func drawText(_ string: String, in rect: CGRect, color: UIColor, align: NSTextAlignment) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = align
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        (string as NSString).draw(in: rect, withAttributes: attributes)
    }

    private func point(forIndex index: Int, value: Double, in plot: CGRect) -> CGPoint {
        let denominator = CGFloat(max(1, maxSamples - 1))
        let x = plot.minX + plot.width * CGFloat(index) / denominator
        return CGPoint(x: x, y: yPosition(forValue: value, in: plot))
    }

    private func yPosition(forValue value: Double, in plot: CGRect) -> CGFloat {
        let clamped = max(minDegrees, min(maxDegrees, value))
        let normalized = (clamped - minDegrees) / (maxDegrees - minDegrees)
        return plot.minY + plot.height * (1 - CGFloat(normalized))
    }
}
