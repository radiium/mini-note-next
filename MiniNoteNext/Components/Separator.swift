
import SwiftUI

// MARK: - Separator

struct Separator: View {
    var body: some View {
        Rectangle()
              .fill(Color.primary.opacity(0.08))
              .frame(height: 0.5)
    }
}
