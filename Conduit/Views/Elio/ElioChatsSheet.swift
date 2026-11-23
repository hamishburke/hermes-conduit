#if ELIO_PERSONAL
import SwiftUI
import UIKit

/// The way out of the one thread and into the rest of Elio's work: every chat
/// on this gateway, so the conversation he is having elsewhere can be carried
/// on here. Settings hangs off the bottom of the same sheet, because a hidden
/// title tap was the only way in.
struct ElioChatsSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    var onOpenSettings: () -> Void
    @StateObject private var releases = ElioReleases()
    @State private var showsUpdate = false
    @State private var copied = false
    @State private var opening: String?
    @State private var openFailure: String?

    private var openSessionID: String? { appState.activeSessionId }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if appState.sessions.isEmpty {
                        Text(verbatim: "No chats yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(appState.sessions) { session in
                        Button {
                            open(session)
                        } label: {
                            row(session)
                        }
                        .buttonStyle(.plain)
                        .disabled(opening != nil)
                    }
                } header: {
                    Text(verbatim: "Your chats with Elio")
                }

                if let openFailure {
                    Section {
                        Text(verbatim: openFailure)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if let newest = releases.newerThanRunning {
                    Section {
                        Button {
                            showsUpdate = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: "Update available")
                                    Text(verbatim: newest.version)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        dismiss()
                        onOpenSettings()
                    } label: {
                        Label {
                            Text(verbatim: "Settings")
                        } icon: {
                            Image(systemName: "gearshape")
                        }
                    }
                } footer: {
                    Text(verbatim: "Elio \(ElioBuild.version) (\(ElioBuild.number))")
                }
            }
            .listStyle(.insetGrouped)
            .task { releases.check() }
            .sheet(isPresented: $showsUpdate) {
                updateSheet
            }
            .navigationTitle(Text(verbatim: "Elio"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appState.startNewChat()
                        dismiss()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel(Text(verbatim: "New chat"))
                }
            }
        }
    }

    private var installCommand: String {
        "~/Developer/elio-iphone/scripts/elio-install.sh"
    }

    private var updateSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let newest = releases.newerThanRunning {
                        Text(verbatim: "Elio \(newest.version)")
                            .font(.title3.weight(.semibold))
                        Text(verbatim: newest.notes.isEmpty ? "No notes for this one." : newest.notes)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Text(verbatim: "An iPhone cannot install its own build. This one is built and installed from fedora, which drives your Mac:")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button {
                        UIPasteboard.general.string = installCommand
                        copied = true
                    } label: {
                        Label(copied ? "Copied" : "Copy install command",
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)
                    Text(verbatim: installCommand)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemBackground))
                        )
                }
                .padding(20)
            }
            .navigationTitle(Text(verbatim: "Update"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showsUpdate = false
                    } label: {
                        Text(verbatim: "Done")
                    }
                }
            }
        }
    }

    private func row(_ session: SessionSummary) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: session.title.isEmpty ? "Untitled chat" : session.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(verbatim: session.updatedLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if opening == session.id {
                ProgressView()
            } else if session.id == openSessionID {
                Image(systemName: "checkmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    private func open(_ session: SessionSummary) {
        guard opening == nil else { return }
        opening = session.id
        openFailure = nil
        // Claim the chat before the open lands, so the screen never falls to
        // "unavailable" in the frame between the switch and the proof.
        if let scope = appState.elioConversationScope {
            appState.elioEnteredChat = ElioEnteredChat(sessionIDs: [session.id],
                                                       dashboardID: scope.dashboardID,
                                                       profile: appState.activeProfile)
        }
        Task {
            let opened = await appState.openSession(session.id)
            if !opened {
                appState.elioEnteredChat = nil
                opening = nil
                openFailure = "Couldn't open that chat. Try again."
                return
            }
            // The open can resolve a runtime id that differs from the listed
            // one; the chat is whichever ids are live now.
            if let scope = appState.elioConversationScope {
                var ids = Set(appState.liveChatSessionIDs())
                ids.insert(session.id)
                if let active = appState.activeSessionId { ids.insert(active) }
                appState.elioEnteredChat = ElioEnteredChat(sessionIDs: ids,
                                                           dashboardID: scope.dashboardID,
                                                           profile: appState.activeProfile)
            }
            if var proof = appState.elioOpenedConversation {
                // The shell's proof of "this is Elio's thread" gains the chat
                // he just walked into, so it is shown rather than refused.
                proof.sessionIDs.insert(session.id)
                appState.elioOpenedConversation = proof
            }
            opening = nil
            dismiss()
        }
    }
}
#endif
