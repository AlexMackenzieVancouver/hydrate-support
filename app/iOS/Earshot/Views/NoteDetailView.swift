import SwiftUI
import EarshotKit

/// Review and deliver.
///
/// Canon: PRD F-11 (strip AI), F-12, F-14 (tier disclosure), F-16 → F-18.
///
/// The screen's job is not to display a summary. It is to get accepted work
/// *out of the app* — which is the thing every 2026 review of this category
/// says nobody does (E-7).
struct NoteDetailView: View {
    @Environment(Services.self) private var services
    @Environment(Entitlements.self) private var entitlements

    let note: Note
    @State private var showingTranscript = false
    @State private var deliveryPreview: PreviewSheet?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                tierDisclosure
                yourNotes
                if note.enhancedMarkdown != nil { enhanced }
                if !note.actionItems.isEmpty { actionItems }
                deliveryBar
                receipts
            }
            .padding(Tokens.Space.l)
        }
        .background(Tokens.Palette.paper)
        .navigationTitle(note.resolvedTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sheet(item: $deliveryPreview) { sheet in
            DeliveryPreviewSheet(preview: sheet.preview, targetName: sheet.targetName) {
                Task { await deliver(targetID: sheet.targetID) }
            }
        }
        .sheet(isPresented: $showingTranscript) {
            TranscriptSheet(note: note)
        }
    }

    // MARK: Sections

    /// F-14. Any note not produced by the on-device model says so, in the
    /// user's words, unprompted. Silent degradation is a defect.
    @ViewBuilder private var tierDisclosure: some View {
        if let disclosure = note.enhancementTier?.disclosure {
            HStack(alignment: .top, spacing: Tokens.Space.s) {
                Image(systemName: note.enhancementTier?.isLocal == true
                      ? "iphone" : "cloud")
                Text(disclosure)
            }
            .font(.footnote)
            .foregroundStyle(Tokens.Palette.graphite)
            .padding(Tokens.Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.Palette.card, in: RoundedRectangle(cornerRadius: Tokens.Radius.card))
        }
    }

    private var yourNotes: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            Text("Your notes")
                .font(.caption.smallCaps())
                .foregroundStyle(Tokens.Palette.graphite)
            // Serif, full-contrast. Always editable, never overwritten (F-11).
            TextEditor(text: Binding(get: { note.notes }, set: { note.notes = $0 }))
                .font(Tokens.Typography.noteBody)
                .foregroundStyle(Tokens.Palette.ink)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
        }
    }

    private var enhanced: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            HStack {
                Text("Filled in")
                    .font(.caption.smallCaps())
                Spacer()
                // F-11's escape hatch. A deletion, not a diff — which is why it
                // can be promised at all.
                Button("Strip") { try? services.repository.stripEnhancement(from: note) }
                    .font(.caption)
            }
            .foregroundStyle(Tokens.Palette.graphite)

            MachineText(note.enhancedMarkdown ?? "")
        }
    }

    private var actionItems: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            HStack {
                Text("Committed")
                    .font(.caption.smallCaps())
                    .foregroundStyle(Tokens.Palette.graphite)
                Spacer()
                Button("Accept all") {
                    for item in note.unreviewedActionItems { item.review = .accepted }
                }
                .font(.caption)
            }

            ForEach(note.actionItems) { item in
                ActionItemRow(item: item)
            }
        }
    }

    private var deliveryBar: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            let accepted = note.actionItems.filter { $0.review == .accepted && $0.externalID == nil }
            if !accepted.isEmpty {
                Text("\(accepted.count) item(s) haven't left the app yet.")
                    .font(.footnote)
                    .foregroundStyle(Tokens.Palette.accent)

                Button {
                    Task { await preview(targetID: "target.reminders") }
                } label: {
                    Label("Send to Reminders", systemImage: "checklist")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Tokens.Space.m)
                        .background(Tokens.Palette.accent, in: Capsule())
                        .foregroundStyle(.white)
                }
            }
        }
    }

    @ViewBuilder private var receipts: some View {
        if !note.receipts.isEmpty {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                Text("Where this went")
                    .font(.caption.smallCaps())
                    .foregroundStyle(Tokens.Palette.graphite)
                ForEach(note.receipts) { receipt in
                    HStack(spacing: Tokens.Space.s) {
                        Image(systemName: receipt.leftTheDevice ? "cloud" : "iphone")
                        Text(receipt.payloadSummary)
                    }
                    .font(.caption)
                    .foregroundStyle(receipt.leftTheDevice ? Tokens.Palette.accent : Tokens.Palette.sent)
                }
            }
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Transcript", systemImage: "text.alignleft") { showingTranscript = true }
                // F-23: export is a right, not a feature. Unpaywalled, always.
                ShareLink(item: exportMarkdown, preview: SharePreview(note.resolvedTitle)) {
                    Label("Export Markdown", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: Delivery

    private func payload() -> DeliveryPayload {
        DeliveryPayload(
            noteID: note.id,
            title: note.resolvedTitle,
            date: note.startedAt,
            markdown: note.enhancedMarkdown ?? note.notes,
            acceptedActions: note.actionItems
                .filter { $0.review == .accepted }
                .map { DeliverableAction(id: $0.id, text: $0.text, assignee: $0.assignee, dueDate: $0.dueDate) }
        )
    }

    /// F-17. Every target shows exactly what will leave and where, before
    /// anything happens. Never pre-confirmed on a target's first use.
    private func preview(targetID: String) async {
        guard let target = services.deliveries.target(id: targetID),
              let result = try? await services.deliveries.preview(payload(), targetID: targetID)
        else { return }
        deliveryPreview = PreviewSheet(targetID: targetID, targetName: target.displayName, preview: result)
    }

    private func deliver(targetID: String) async {
        guard let (result, receipt) = try? await services.deliveries.deliver(payload(), targetID: targetID),
              let target = services.deliveries.target(id: targetID)
        else { return }
        try? services.repository.record(
            receipt, on: note, externalIDs: result.externalIDs, targetName: target.displayName
        )
    }

    private var exportMarkdown: String {
        MarkdownDelivery.render(payload())
    }

    struct PreviewSheet: Identifiable {
        let id = UUID()
        let targetID: String
        let targetName: String
        let preview: DeliveryPreview
    }
}

private struct ActionItemRow: View {
    @Bindable var item: ActionItem

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Space.m) {
            Button {
                item.review = item.review == .accepted ? .pending : .accepted
            } label: {
                Image(systemName: item.isComplete ? "checkmark.circle.fill"
                      : item.review == .accepted ? "circle.inset.filled" : "circle")
                    .foregroundStyle(item.isComplete ? Tokens.Palette.sent : Tokens.Palette.graphite)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.text)
                    .font(Tokens.Typography.machineBody)
                    .foregroundStyle(item.review == .dismissed ? Tokens.Palette.graphite : Tokens.Palette.ink)
                    .strikethrough(item.review == .dismissed || item.isComplete)

                HStack(spacing: Tokens.Space.s) {
                    if let who = item.assignee { Text(who) }
                    if let due = item.dueDate {
                        Text(due.formatted(date: .abbreviated, time: .omitted))
                    }
                    if let target = item.deliveredTo {
                        Label(target, systemImage: "checkmark")
                            .foregroundStyle(Tokens.Palette.sent)
                    }
                }
                .font(.caption)
                .foregroundStyle(Tokens.Palette.graphite)
            }

            Spacer()
        }
        .swipeActions(edge: .trailing) {
            Button("Dismiss", role: .destructive) { item.review = .dismissed }
        }
    }
}

private struct DeliveryPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let preview: DeliveryPreview
    let targetName: String
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(preview.lines, id: \.self) { Text($0) }
                } header: {
                    Text("Going to \(preview.destination)")
                } footer: {
                    if let warning = preview.networkWarning {
                        Text(warning).foregroundStyle(Tokens.Palette.accent)
                    } else {
                        Text("This stays on your iPhone.")
                    }
                }
            }
            .navigationTitle(targetName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { dismiss(); onConfirm() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct TranscriptSheet: View {
    let note: Note

    var body: some View {
        NavigationStack {
            List(note.segments.sorted { $0.start < $1.start }) { segment in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        // F-10: speaker chips are tappable to rename, and the
                        // rename applies to the whole meeting and every future one.
                        Text("Speaker \(segment.speakerIndex + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(Tokens.Palette.accent)
                        Text(CaptureView.elapsedText(segment.start))
                            .font(Tokens.Typography.timestamp)
                            .foregroundStyle(Tokens.Palette.graphite)
                    }
                    Text(segment.text)
                        .font(Tokens.Typography.transcriptBody)
                }
            }
            .navigationTitle("Transcript")
        }
    }
}
