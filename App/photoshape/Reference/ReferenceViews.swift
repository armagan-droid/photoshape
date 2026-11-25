import PhotosUI
import SwiftUI

/// First thing the user sees without an example (spec 05 Hikâye 0.1).
struct ReferencePromptView: View {
    @Bindable var store: ReferenceStore
    @State private var item: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled").font(.system(size: 52)).foregroundStyle(.white.opacity(0.85))
            Text("reference.prompt.title").font(.title2.bold()).multilineTextAlignment(.center).foregroundStyle(.white)
            Text("reference.prompt.body").multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.75))
            if store.isAnalyzing {
                ProgressView().tint(.white).padding(.top, 8)
                Text("reference.analyzing").font(.footnote).foregroundStyle(.white.opacity(0.7))
            } else {
                ReferencePicker(store: store, item: $item) {
                    Label("reference.pick", systemImage: "photo")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.white, in: Capsule()).foregroundStyle(.black)
                }
                .accessibilityIdentifier("pickReference")
                if store.failedToRead {
                    Text("reference.failed").font(.footnote).foregroundStyle(.orange).multilineTextAlignment(.center)
                }
                Button("reference.skip") { store.skippedPrompt = true }
                    .foregroundStyle(.white.opacity(0.85))
                    .accessibilityIdentifier("skipReference")
            }
            Spacer()
        }
        .padding(.horizontal, 36)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("referencePrompt")
        .paywall(store: store)
    }
}

extension View {
    /// The paywall over whatever screen asked to add an example (spec 07 Hikâye 2.3).
    func paywall(store: ReferenceStore) -> some View {
        sheet(isPresented: Binding(get: { store.paywallRequested }, set: { store.paywallRequested = $0 })) {
            if let entitlements = store.entitlements as? StoreEntitlements { PaywallView(store: entitlements) }
        }
    }
}

/// System photo picker: no library permission needed (Constitution I, spec 05 Hikâye 1.1).
struct ReferencePicker<Label: View>: View {
    let store: ReferenceStore
    @Binding var item: PhotosPickerItem?
    @ViewBuilder let label: () -> Label

    var body: some View {
        // With the quota full the same button opens the paywall, so no photo is picked for nothing (Hikâye 5.2).
        if store.mayAddExample {
            PhotosPicker(selection: $item, matching: .images, photoLibrary: .shared()) { label() }
                .onChange(of: item) { _, picked in
                    guard let picked else { return }
                    Task {
                        if let data = try? await picked.loadTransferable(type: Data.self) { await store.add(imageData: data) }
                        item = nil
                    }
                }
        } else {
            Button { store.paywallRequested = true } label: { label() }
        }
    }
}

/// The example in the preview's top left corner (spec 05 "Yerleşim" 1): a tap opens its card, holding shows it
/// bigger until released. Without an example the same corner opens Örneklerim (Hikâye 0.2, 7.2).
struct ExampleCorner: View {
    let store: ReferenceStore
    let open: () -> Void
    @State private var peeking = false

    static let size = CGSize(width: 48, height: 60)

    var body: some View {
        Group {
            if let current = store.current, let image = store.thumbnail(current.id) {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: Self.size.width, height: Self.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.85), lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 1)
                    .overlay(alignment: .topLeading) {
                        if peeking { enlarged(image).allowsHitTesting(false) }
                    }
                    .onTapGesture(perform: open)
                    .onLongPressGesture(minimumDuration: 0.25, maximumDistance: 60) {
                        withAnimation(.spring(duration: 0.25)) { peeking = true }
                    } onPressingChanged: { pressing in
                        if !pressing { withAnimation(.easeOut(duration: 0.2)) { peeking = false } }
                    }
                    .accessibilityLabel(Text("reference.current"))
                    .accessibilityHint(Text("reference.corner.hint"))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction(named: Text("reference.corner.peek")) { peeking.toggle() }
            } else {
                Button(action: open) {
                    Image(systemName: "photo.badge.plus").font(.title3).foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.black.opacity(0.4)))
                }
                .accessibilityLabel(Text("reference.choose"))
            }
        }
        .accessibilityIdentifier("referenceChip")
    }

    /// Up to 3.5 times the corner, the example's own shape; the stored image is small (Hikâye 6.2).
    private func enlarged(_ image: UIImage) -> some View {
        let aspect = image.size.width / max(image.size.height, 1)
        let height = Self.size.height * 3.5
        return Image(uiImage: image).resizable().aspectRatio(contentMode: .fit)
            .frame(width: height * aspect, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.85), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.5), radius: 10, y: 3)
            .transition(.scale(scale: 0.3, anchor: .topLeading).combined(with: .opacity))
            .accessibilityHidden(true)
    }
}

/// "Örneklerim": pick another example, add a new one or shoot without one (spec 05 Hikâye 0.2, 6).
struct ReferencesSheet: View {
    @Bindable var store: ReferenceStore
    @Environment(\.dismiss) private var dismiss
    @State private var item: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ReferencePicker(store: store, item: $item) {
                        Label("references.new", systemImage: "plus").font(.headline)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.white, in: Capsule()).foregroundStyle(.black)
                    }
                    .accessibilityIdentifier("newReference")
                    if store.isAnalyzing { ProgressView().frame(maxWidth: .infinity) }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                        ForEach(store.references) { ref in
                            Button { store.select(ref.id); dismiss() } label: {
                                Group {
                                    if let image = store.thumbnail(ref.id) {
                                        Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                                    } else { Color.gray.opacity(0.3) }
                                }
                                .frame(height: 120).frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .stroke(ref.id == store.currentID ? Color.yellow : .clear, lineWidth: 2))
                            }
                            .contextMenu {
                                Button("references.delete", systemImage: "trash", role: .destructive) { store.delete(ref.id) }
                            }
                            .accessibilityIdentifier("reference.item")
                        }
                    }

                    Button("references.none") { store.shootWithoutExample(); dismiss() }
                        .frame(maxWidth: .infinity).padding(.top, 8)
                        .accessibilityIdentifier("noReference")
                }
                .padding(20)
            }
            .navigationTitle(Text("references.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.close") { dismiss() } }
            }
            .onChange(of: store.currentID) { old, new in if new != nil, old != new, !store.isAnalyzing { dismiss() } }
        }
        .preferredColorScheme(.dark)
        .paywall(store: store)
    }
}
