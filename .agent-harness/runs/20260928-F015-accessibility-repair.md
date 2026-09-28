# F015 home accessibility repair

Initial full root recovery failed only HomeTests.testRealHomeRandomAndPersistedContinue: home.pending hit area too small. .build/test-run.4wtKoC/Tests.xcresult. Increasing label frame alone to44pt did not fix audit; second failure .build/test-run.0BmBHt/Tests.xcresult. Exported issue description and element/app screenshots from first result: accessibility element captured only label/icon area, not surrounding custom glass panel padding.

Changed new pending entry from plain button wrapping custom glass panel to native glass ButtonStyle, large control size, explicit44pt label frame and rectangular content shape. Did not modify or suppress existing accessibility audit. Focused three HomeTests pass in .build/F015-home-audit.xcresult: ordinary hit region/description/text clipping, large dynamic type, reduced transparency. Final full root recovery pending at this record's creation. Primary failure domain implementation_gap; no harness change needed because existing audit detected the regression and remained intact.

F015 review/confirmation screenshots exported from the passing new UI test in the first full run and visually inspected; saved docs/design/F015-deletion-review.png and F015-fixed-confirmation.png. This run's separate home failure does not count as complete recovery.
