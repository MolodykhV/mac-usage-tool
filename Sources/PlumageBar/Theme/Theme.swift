import SwiftUI

enum Theme {
    static let cardCornerRadius: CGFloat = 12
    static let cardPaddingHorizontal: CGFloat = 10
    static let cardPaddingVertical: CGFloat = 8
    static let popoverPadding: CGFloat = 12
    static let popoverWidth: CGFloat = 300

    static let menuBarSymbolFont = Font.system(size: 11, weight: .semibold)
    static let menuBarValueFont = Font.system(size: 11, weight: .medium, design: .rounded)
    static let cardTitleFont = Font.system(size: 11, weight: .medium)
    static let cardValueFont = Font.system(size: 13, weight: .semibold, design: .rounded)
    static let sectionTitleFont = Font.system(size: 10, weight: .semibold)
    static let processNameFont = Font.system(size: 11)
    static let processValueFont = Font.system(size: 11, design: .rounded)
}

extension View {
    /// Applies the system Liquid Glass material inside the given shape on
    /// macOS 26+, falling back to `.thinMaterial` on earlier systems.
    /// Plumage Bar's minimum is macOS 26, but the fallback keeps SwiftUI
    /// previews honest if someone opens the package on an older toolchain.
    ///
    /// A subtle hairline overlay is layered on top so tiles stay visually
    /// distinct from each other and from whatever sits behind them. Without
    /// it the glass blends into bright desktops.
    @ViewBuilder
    func plumageGlass(cornerRadius: CGFloat = Theme.cardCornerRadius) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                .overlay(shape.stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
        } else {
            self.background(shape.fill(.thinMaterial))
                .overlay(shape.stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
        }
    }
}
