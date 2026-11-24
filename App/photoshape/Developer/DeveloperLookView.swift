#if DEBUG
import CoreImage
import LookKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Developer builds only (spec 03 Hikâye 4, FR-010): every color and tone parameter of a recipe with a named,
/// numbered control, applied live; a frozen frame or a library image to compare on; export in the app's own recipe
/// format through the share sheet, and import of an existing recipe file. Never in an App Store build (4.5).
struct DeveloperLookView: View {
    let liveSource: () -> CIImage?
    let renderer: LookRenderer
    @State var recipe: LookRecipe
    @State private var frozen: CIImage?
    @State private var picked: PhotosPickerItem?
    @State private var importing = false
    @State private var exportURL: URL?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                LookPreview(source: { frozen ?? liveSource() }, look: recipe, strength: 1, renderer: renderer, onTap: { _, _ in })
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .frame(maxHeight: 300)
                    .accessibilityIdentifier("dev.preview")
                frameButtons
                Form {
                    Section("dev.section.tone") {
                        slider("exposure", \.exposure); slider("contrast", \.contrast)
                        slider("highlights", \.highlights); slider("shadows", \.shadows)
                        slider("fade", \.fade, 0...1)
                    }
                    Section("dev.section.color") {
                        slider("temperature", \.temperature); slider("tint", \.tint)
                        slider("saturation", \.saturation); slider("vibrance", \.vibrance)
                    }
                    Section("dev.section.ranges") {
                        ForEach(LookAdjustments.ColorRange.allCases, id: \.self) { range in
                            DisclosureGroup(range.rawValue) {
                                rangeSlider(range, "hue", \.hue); rangeSlider(range, "saturation", \.saturation)
                                rangeSlider(range, "luminance", \.luminance)
                            }
                        }
                    }
                    Section("dev.section.splitTone") {
                        slider("shadowHue", \.splitTone.shadowHue, 0...1); slider("shadowAmount", \.splitTone.shadowAmount, 0...1)
                        slider("highlightHue", \.splitTone.highlightHue, 0...1); slider("highlightAmount", \.splitTone.highlightAmount, 0...1)
                    }
                    Section("dev.section.effects") {
                        slider("grain", \.grain, 0...1); slider("vignette", \.vignette, 0...1)
                    }
                }
            }
            .navigationTitle("dev.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.close") { dismiss() } }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("dev.import") { importing = true }.accessibilityIdentifier("dev.import")
                    if let exportURL {
                        ShareLink(item: exportURL) { Text("dev.export") }.accessibilityIdentifier("dev.export")
                    }
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                guard case .success(let url) = result else { return }
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url), let look = try? JSONDecoder().decode(LookRecipe.self, from: data) {
                    recipe = look
                }
            }
            .onChange(of: picked) {
                Task {
                    if let data = try? await picked?.loadTransferable(type: Data.self), let image = CIImage(data: data, options: [.applyOrientationProperty: true]) {
                        frozen = image
                    }
                }
            }
            .onChange(of: recipe) { writeExport() }
            .onAppear { writeExport() }
        }
        .preferredColorScheme(.dark)
    }

    private var frameButtons: some View {
        HStack(spacing: 16) {
            Button(frozen == nil ? "dev.freeze" : "dev.live") {
                frozen = frozen == nil ? liveSource() : nil
            }
            .accessibilityIdentifier("dev.freeze")
            PhotosPicker(selection: $picked, matching: .images) { Text("dev.openImage") }
            Button("dev.reset") { recipe.adjustments = .zero }
        }
        .font(.footnote)
        .padding(.vertical, 8)
    }

    private func slider(_ name: String, _ path: WritableKeyPath<LookAdjustments, Double>, _ range: ClosedRange<Double> = -1...1) -> some View {
        ValueSlider(name: name, value: Binding(get: { recipe.adjustments[keyPath: path] },
                                               set: { recipe.adjustments[keyPath: path] = $0 }), range: range)
    }

    private func rangeSlider(_ range: LookAdjustments.ColorRange, _ name: String,
                             _ path: WritableKeyPath<LookAdjustments.RangeAdjustment, Double>) -> some View {
        ValueSlider(name: name, value: Binding(
            get: { recipe.adjustments.ranges[range]?[keyPath: path] ?? 0 },
            set: { var r = recipe.adjustments.ranges[range] ?? .init(); r[keyPath: path] = $0; recipe.adjustments.ranges[range] = r }
        ), range: -1...1)
    }

    /// The file the share sheet sends: the app's own recipe format (FR-010), validated before it is offered.
    private func writeExport() {
        var look = recipe
        if look.id == LookRecipe.natural.id { look.id = "dev-look"; look.category = "cafe_food" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(look), (try? JSONDecoder().decode(LookRecipe.self, from: data)) != nil else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(look.id).look.json")
        try? data.write(to: url)
        exportURL = url
    }
}

/// Parameter names stay as in the recipe file (developer tool), with the value as a number.
private struct ValueSlider: View {
    let name: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(verbatim: name).font(.caption.monospaced())
                Spacer()
                Text(value, format: .number.precision(.fractionLength(2))).font(.caption.monospacedDigit())
            }
            Slider(value: $value, in: range)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("dev.slider.\(name)")
    }
}
#endif
