import SwiftUI

struct Sparkline: View {
    let values: [Double]
    var maxValue: Double = 100
    var lineWidth: CGFloat = 1.5

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                guard values.count > 1 else { return }
                let safeMax = max(maxValue, 0.0001)
                let stepX = proxy.size.width / CGFloat(values.count - 1)
                let h = proxy.size.height
                for (index, value) in values.enumerated() {
                    let clamped = min(max(value, 0), safeMax)
                    let x = CGFloat(index) * stepX
                    let y = h - CGFloat(clamped / safeMax) * h
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(
                Color.secondary,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(height: 18)
        .accessibilityHidden(true)
    }
}

#Preview("Sparkline samples") {
    VStack(spacing: 8) {
        Sparkline(values: (0..<60).map { _ in Double.random(in: 0...100) })
        Sparkline(values: stride(from: 0, to: 100, by: 1.67).map { $0 })
        Sparkline(values: [])
    }
    .padding()
    .frame(width: 240)
}
