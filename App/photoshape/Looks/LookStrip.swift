import LookKit
import SwiftUI

/// Horizontal strip of looks: swipe or tap; the centered look is the selected one and the live preview
/// follows it (spec 03 Hikâye 1). "Doğal" comes first.
struct LookStrip: View {
    @Bindable var selection: LookSelection
    let isLocked: (LookRecipe) -> Bool
    let onInteract: () -> Void

    private let itemWidth: CGFloat = 64
    @State private var scrolledID: String?

    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal) {
                HStack(spacing: 14) { // few looks; all exist, so VoiceOver and tests can reach each one
                    ForEach(selection.strip) { look in
                        item(look)
                            .id(look.id)
                            .onTapGesture {
                                onInteract()
                                withAnimation(.snappy) { scrolledID = look.id }
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, max(0, (geo.size.width - itemWidth) / 2), for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrolledID, anchor: .center)
            .scrollIndicators(.hidden)
            .onScrollPhaseChange { _, phase in if phase == .interacting { onInteract() } }
            .accessibilityIdentifier("lookStrip")
        }
        .frame(height: 96)
        .onAppear { scrolledID = selection.selectedID }
        // Fast swipes may skip intermediate looks; the one the strip settles on is shown (uç durum "hızlı kaydırma").
        .onChange(of: scrolledID) { _, id in
            if let id, id != selection.selectedID { selection.selectedID = id }
        }
    }

    private func item(_ look: LookRecipe) -> some View {
        let isSelected = look.id == selection.selectedID
        return VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let image = selection.sample(for: look) {
                        Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        ZStack {
                            Color.white.opacity(0.12)
                            Image(systemName: "circle.slash").font(.title3).foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
                .frame(width: itemWidth, height: itemWidth * 5 / 4)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.yellow : .clear, lineWidth: 2))

                if isLocked(look) {
                    Image(systemName: "lock.fill").font(.caption2).padding(4)
                        .background(Circle().fill(.black.opacity(0.6))).foregroundStyle(.white).padding(3)
                }
            }
            Text(selection.name(of: look))
                .font(.caption2.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.yellow : .white.opacity(0.85))
                .lineLimit(1)
                .frame(width: itemWidth + 10)
        }
        .frame(width: itemWidth)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(selection.name(of: look)))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("look.\(look.id)")
    }
}
