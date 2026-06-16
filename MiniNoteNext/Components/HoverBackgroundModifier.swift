import SwiftUI

struct HoverBackgroundModifier: ViewModifier {
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Layout.controlRadius)
                    .fill(.primary.opacity(isHovered ? Layout.controlOpacity : 0))
            )
            .animation(.easeInOut(duration: 0.1), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

extension View {
    func hoverBackground() -> some View {
        modifier(HoverBackgroundModifier())
    }

    func activeBackground(_ isActive: Bool = false) -> some View {
        background(
            isActive ? Color.accentColor : Color.primary.opacity(Layout.controlOpacity),
            in: RoundedRectangle(cornerRadius: Layout.controlRadius)
        )
    }
}
