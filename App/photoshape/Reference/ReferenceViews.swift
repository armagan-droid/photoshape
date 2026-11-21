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
    }
}

/// System photo picker: no library permission needed (Constitution I, spec 05 Hikâye 1.1).
struct ReferencePicker<Label: View>: View {
    let store: ReferenceStore
    @Binding var item: PhotosPickerItem?
    @ViewBuilder let label: () -> Label

    var body: some View {
        PhotosPicker(selection: $item, matching: .images, photoLibrary: .shared()) { label() }
            .onChange(of: item) { _, picked in
                guard let picked else { return }
                Task {
                    if let data = try? await picked.loadTransferable(type: Data.self) { await store.add(imageData: data) }
                    item = nil
                }
            }
    }
}

/// Small example icon on the camera screen; opens "Örneklerim" (Hikâye 0.2).
struct ReferenceChip: View {
    let store: ReferenceStore
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 10) {
                if let current = store.current, let image = store.thumbnail(current.id) {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                        .frame(width: 30, height: 38).clipShape(RoundedRectangle(cornerRadius: 5))
                    Text("reference.current").font(.subheadline.weight(.medium))
                } else {
                    Image(systemName: "photo.badge.plus").font(.title3)
                    Text("reference.choose").font(.subheadline.weight(.medium))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Capsule().fill(.white.opacity(0.12)))
        }
        .accessibilityIdentifier("referenceChip")
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
    }
}
