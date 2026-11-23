#if ELIO_PERSONAL && DEBUG
import SwiftUI

/// A DEBUG-only look build: the real screen, fed fixed rows. The simulator
/// here has no pairing, so this is the only way to draw and photograph the
/// thread before it reaches a phone that is signed in.
struct ElioLookPreview: View {
    static let launchArgument = "-ElioLook"

    var body: some View {
        ElioChatScreen(onOpenSettings: {}, previewRows: Self.sample,
                       previewPicksReaction: ProcessInfo.processInfo.arguments
                        .contains("-ElioLookPicker"))
    }

    private static func row(_ id: String, _ kind: ElioRow.Kind, _ text: String,
                            start: Bool = true) -> ElioRow {
        ElioRow(id: id, kind: kind, text: text, groupStart: start)
    }

    static let sample: [ElioRow] = {
        var rows: [ElioRow] = [
            row("s1", .user, "Morning. What have I got today?"),
            row("s2", .agent, "Two things that cost you money if they slip: the SBS statement closes tonight, and the plyometrics site's renewal is tomorrow. Everything else can wait until after work."),
            row("s3", .agent, "Groceries are the only errand. Want the list now or on the way home?", start: false),
            row("s4", .user, "On the way home. What's the renewal worth?"),
            row("s5", .agent, "Sixty-nine a year, and it bills to the card that expires in March, so it is worth switching now rather than twice."),
            row("s6", .user, "Fine, do the switch."),
            row("s7", .agent, "Done. The domain now bills to the new card, and the next charge is the twelfth of December."),
            row("s8", .agent, "One more:\n\n```swift\nlet renewal = 69.00\n```\n\nThat is the whole cost.")
        ]

        rows[6].reactions = [MessageReaction(emoji: "\u{2764}\u{FE0F}", author: "user", at: nil)]

        var clarify = ElioRow(id: "s9", kind: .clarify, text: "Which list do you want?")
        clarify.clarify = ClarifyActivity(
            requestId: "preview",
            questions: [
                ClarifyQuestion(
                    id: "q1",
                    question: "Which list do you want?",
                    choices: [
                        ClarifyChoice(label: "The usual weekly shop", value: "usual"),
                        ClarifyChoice(label: "Just tonight's dinner", value: "dinner"),
                        ClarifyChoice(label: "Skip it this week", value: "skip")
                    ]
                )
            ]
        )
        rows.append(clarify)
        rows.append(row("s10", .user, "Just tonight's dinner."))
        rows.append(row("s11", .agent, "Done. Dinner for one, then: what's in the fridge decides it."))
        return rows
    }()
}
#endif
