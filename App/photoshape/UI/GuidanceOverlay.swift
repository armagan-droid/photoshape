import CaptureKit
import CompositionKit
import FrameKit
import SwiftUI

/// The example's outline and, for people, its skeleton, fitted into the 4:5 frame (spec 04 "Taslak").
struct GhostOverlay: View {
    let ghost: UIImage?
    let subject: Subject?
    let aspect: Double
    let isReady: Bool
    /// Developer builds only: the live subject, drawn in blue to check detection on the device.
    var debugLive: Subject? = nil

    static let bones: [(Joint, Joint)] = [
        (.neck, .nose), (.leftShoulder, .rightShoulder), (.neck, .root),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist), (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftHip, .rightHip), (.leftHip, .leftKnee), (.leftKnee, .leftAnkle), (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
    ]

    var body: some View {
        GeometryReader { geo in
            let crop = CropGeometry.normalizedCrop(aspectWidth: geo.size.width, aspectHeight: geo.size.height)
            let frame = CGRect(x: crop.x * geo.size.width, y: crop.y * geo.size.height,
                               width: crop.w * geo.size.width, height: crop.h * geo.size.height)
            let r = exampleRegion(exampleAspect: CGFloat(aspect))
            let region = CGRect(x: frame.minX + r.minX * frame.width, y: frame.minY + r.minY * frame.height,
                                width: r.width * frame.width, height: r.height * frame.height)
            ZStack(alignment: .topLeading) {
                if let ghost {
                    Image(uiImage: ghost).resizable()
                        .frame(width: region.width, height: region.height)
                        .offset(x: region.minX, y: region.minY)
                        .opacity(isReady ? 0.15 : 0.55)
                }
                if let pose = subject?.pose {
                    Path { path in
                        for (a, b) in Self.bones {
                            guard let p = pose.joints[a], let q = pose.joints[b] else { continue }
                            path.move(to: CGPoint(x: region.minX + p.x * region.width, y: region.minY + p.y * region.height))
                            path.addLine(to: CGPoint(x: region.minX + q.x * region.width, y: region.minY + q.y * region.height))
                        }
                    }
                    .stroke(Color.yellow.opacity(isReady ? 0.25 : 0.8), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }
                if let live = debugLive {
                    let b = live.box
                    Rectangle().stroke(Color.cyan.opacity(0.7), lineWidth: 1)
                        .frame(width: b.width * frame.width, height: b.height * frame.height)
                        .offset(x: frame.minX + b.minX * frame.width, y: frame.minY + b.minY * frame.height)
                    if let pose = live.pose {
                        Path { path in
                            for (a, c) in Self.bones {
                                guard let p = pose.joints[a], let q = pose.joints[c] else { continue }
                                path.move(to: CGPoint(x: frame.minX + p.x * frame.width, y: frame.minY + p.y * frame.height))
                                path.addLine(to: CGPoint(x: frame.minX + q.x * frame.width, y: frame.minY + q.y * frame.height))
                            }
                        }
                        .stroke(Color.cyan, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isReady)
        }
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityIdentifier("ghost")
    }
}

/// One short sentence with an arrow (Constitution II, spec 04 FR-K4, FR-K6).
struct GuidanceBanner: View {
    let instruction: GuidanceInstruction

    var body: some View {
        HStack(spacing: 8) {
            if let symbol = symbol { Image(systemName: symbol).font(.headline) }
            Text(LocalizedStringKey(instruction.phraseKey)).font(.headline)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Capsule().fill(.black.opacity(0.6)))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("guidance")
    }

    private var symbol: String? {
        switch instruction.direction {
        case .left: "arrow.left"
        case .right: "arrow.right"
        case .up: "arrow.up"
        case .down: "arrow.down"
        case .closer: "arrow.up.left.and.arrow.down.right"
        case .farther: "arrow.down.right.and.arrow.up.left"
        case nil: "viewfinder"
        }
    }
}

/// What the app just did, or the comparison label, in plain words (spec 02 FR-010/011).
struct StatusCaption: View {
    let key: String
    var body: some View {
        Text(LocalizedStringKey(key))
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Capsule().fill(.black.opacity(0.5)))
    }
}
