#if DEBUG
import SwiftUI

struct DeletionResultTestHost: View {
    @State private var index = 0
    private let receipts: [DeletionCoordinator.Result] = [.succeeded, .cancelled, .failed, .needsReview, .succeededJournalPending]
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                DeletionResultCard(result: DeletionResult(receipts[index], count: 11, remaining: 0)).padding(20)
            }.clipped().accessibilityIdentifier("result.scroll")
            Button("下一个结果") { index = (index + 1) % receipts.count }
                .buttonStyle(PhotoGlassButtonStyle()).padding(20).accessibilityIdentifier("result.next")
        }.background(PhotoPaletteBackground()).photoPage()
    }
}
#endif
