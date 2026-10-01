import SwiftUI

/// Uses only receipt facts. No asset lookup is needed after deletion.
struct DeletionResultCard: View {
    let result: DeletionResult
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: result.outcome == .succeeded ? "checkmark.circle" : "info.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(result.outcome == .succeeded ? PhotoTheme.success : PhotoTheme.warning)
                .accessibilityHidden(true)
            Text(result.title).font(.title.bold()).multilineTextAlignment(.center)
            Text(result.detail).multilineTextAlignment(.center).accessibilityIdentifier("deletion.result")
            Text(result.remainingText).font(.subheadline).foregroundStyle(PhotoTheme.secondary)
                .multilineTextAlignment(.center).accessibilityIdentifier("deletion.remaining")
        }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity)
            .padding(24).photoGlass(radius: 32)
    }
}
