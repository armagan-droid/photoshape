import CompositionKit
import SwiftUI

/// "Bu fotoğraf nasıl çekilmiş?" (spec 05 Hikâye 7, Constitution 2.0.0 II). Shows only what `ExampleReading`
/// says: lines it could not read are simply absent (7.3). Information and navigation only, no shooting control.
struct ExampleCardView: View {
    let store: ReferenceStore
    let reference: ReferenceStore.Reference
    let change: () -> Void
    let shootWithout: () -> Void
    /// For the settings section (Hikâye 8.5): the camera now and what the app applies.
    var live: LiveExposure?
    var appBias = 0.0
    var lensKey = "lens.normal"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let reading = reference.reading
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(reading.lines, id: \.topic) { line in
                            LineRow(line: line).accessibilityIdentifier("card.line.\(line.topic.rawValue)")
                        }
                    }
                    ExampleSettingsView(settings: reference.settings, measurements: reference.measurements,
                                        live: live, appBias: appBias, lensKey: lensKey)
                    steps(reading.steps)
                    buttons
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.close") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("exampleCard")
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            if let image = store.thumbnail(reference.id) {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: 64, height: 80).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Text("card.title").font(.title3.bold()).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func steps(_ keys: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("card.steps").font(.headline)
            ForEach(Array(keys.enumerated()), id: \.offset) { index, key in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(index + 1)").font(.subheadline.monospacedDigit().bold())
                        .frame(width: 24, height: 24).background(Circle().fill(.yellow)).foregroundStyle(.black)
                    Text(LocalizedStringKey(key)).fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("card.step")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.08)))
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            Button { dismiss() } label: {
                Text("card.start").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.white, in: Capsule()).foregroundStyle(.black)
            }
            .accessibilityIdentifier("card.start")
            HStack {
                Button("card.change", action: change).accessibilityIdentifier("card.change")
                Spacer()
                Button("card.none", action: shootWithout).accessibilityIdentifier("card.none")
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.top, 4)
    }
}

private struct LineRow: View {
    let line: ExampleReading.Line

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.title3).frame(width: 28).foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                // A plain String variable: an interpolated literal would become the format key "reading.topic.%@".
                Text(LocalizedStringKey(titleKey)).font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6)).textCase(.uppercase)
                sentences.fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var titleKey: String { "reading.topic." + line.topic.rawValue }

    /// The line's short sentences, one after the other.
    private var sentences: Text {
        var text = Text(LocalizedStringKey(line.phraseKeys.first ?? ""))
        for key in line.phraseKeys.dropFirst() { text = text + Text(verbatim: " ") + Text(LocalizedStringKey(key)) }
        return text
    }

    private var symbol: String {
        switch line.topic {
        case .light: "sun.max"
        case .tone: "circle.lefthalf.filled"
        case .color: "paintpalette"
        case .angle: "camera.viewfinder"
        case .subject: "viewfinder.rectangular"
        }
    }
}
