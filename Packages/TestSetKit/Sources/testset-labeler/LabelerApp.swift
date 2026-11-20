// testset-labeler — mark subject_region / neutral_region by dragging on the frame (spec 00 FR-009).
//
//   swift run testset-labeler [DIR]
//
// Drag to draw. S: subject mode · N: neutral mode · ⌫: remove last region of the current mode
// ← / →: previous / next frame. Every change is saved to the frame's JSON immediately.
// Only the two region keys are written; all other label fields are left as they are.

import AppKit
import SwiftUI
import TestSetKit

@main
struct LabelerApp: App {
    @State private var model = LabelerModel(rootArgument: CommandLine.arguments.dropFirst().first)

    init() {
        // Running from `swift run` has no app bundle; make the window come to the front.
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async { NSApp.activate() }
    }

    var body: some Scene {
        WindowGroup("photoshape labeler") {
            LabelerView(model: model).frame(minWidth: 900, minHeight: 640)
        }
    }
}

enum RegionMode: String, CaseIterable, Identifiable {
    case subject = "Subject"
    case neutral = "Neutral"
    var id: Self { self }
}

enum FrameStatus { case unlabeled, invalid, gaps, complete }

@MainActor @Observable
final class LabelerModel {
    var root: URL?
    var files: [URL] = []
    var statuses: [URL: FrameStatus] = [:]
    var selection: URL? { didSet { if selection != oldValue { loadSelection() } } }
    var image: CGImage?
    var subject: Region?
    var neutral: [Region] = []
    var mode: RegionMode = .subject
    var message: String?

    init(rootArgument: String?) {
        do {
            let set: TestSet
            if let rootArgument {
                set = try TestSet.load(at: URL(fileURLWithPath: rootArgument, isDirectory: true))
            } else {
                set = try TestSet.locate(startingAt: FileManager.default.currentDirectoryPath + "/.")
            }
            root = set.root
            files = Self.imageFiles(in: set.root)
            files.forEach(refreshStatus)
            selection = files.first(where: { statuses[$0] == .gaps }) ?? files.first
            if files.isEmpty { message = "No images in \(set.root.path)" }
        } catch {
            message = "\(error)"
        }
    }

    static func imageFiles(in root: URL) -> [URL] {
        let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        var result: [URL] = []
        while let url = e?.nextObject() as? URL {
            if TestSet.imageExtensions.contains(url.pathExtension.lowercased()) { result.append(url) }
        }
        return result.sorted { $0.path < $1.path }
    }

    func name(_ url: URL) -> String { root.map { TestSet.relativePath(of: url, in: $0) } ?? url.lastPathComponent }
    private func labelURL(_ image: URL) -> URL { image.deletingPathExtension().appendingPathExtension("json") }

    func refreshStatus(_ url: URL) {
        let labelURL = labelURL(url)
        guard FileManager.default.fileExists(atPath: labelURL.path) else { statuses[url] = .unlabeled; return }
        guard let dict = try? LabelFile.readDictionary(at: labelURL),
              case .success(let labels) = LabelSchema.parse(dict, expectedID: url.deletingPathExtension().lastPathComponent)
        else { statuses[url] = .invalid; return }
        statuses[url] = LabelSchema.gaps(for: labels).isEmpty ? .complete : .gaps
    }

    private func loadSelection() {
        image = nil; subject = nil; neutral = []
        guard let url = selection else { return }
        do {
            image = try TestFrame.loadOrientedImage(url, maxPixelSize: 1800)
            (subject, neutral) = LabelFile.regions(in: try LabelFile.readDictionary(at: labelURL(url)))
            message = nil
        } catch {
            message = "\(error)"
        }
    }

    func add(_ region: Region) {
        switch mode {
        case .subject: subject = region          // one subject: a new drag replaces it
        case .neutral: neutral.append(region)
        }
        save()
    }

    func removeLast() {
        switch mode {
        case .subject: subject = nil
        case .neutral: if !neutral.isEmpty { neutral.removeLast() }
        }
        save()
    }

    private func save() {
        guard let url = selection else { return }
        do {
            try LabelFile.setRegions(subject: subject, neutral: neutral, at: labelURL(url))
            refreshStatus(url)
            message = "Saved \(name(labelURL(url)))"
        } catch {
            message = "Save failed: \(error)"
        }
    }

    func step(_ delta: Int) {
        guard let current = selection, let i = files.firstIndex(of: current) else { return }
        let j = i + delta
        if files.indices.contains(j) { selection = files[j] }
    }
}

struct LabelerView: View {
    @Bindable var model: LabelerModel

    var body: some View {
        NavigationSplitView {
            List(model.files, id: \.self, selection: $model.selection) { url in
                HStack {
                    statusIcon(model.statuses[url] ?? .unlabeled)
                    Text(model.name(url)).lineLimit(1)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            VStack(spacing: 8) {
                toolbar
                if let image = model.image {
                    RegionCanvas(image: image, subject: model.subject, neutral: model.neutral, onDraw: model.add)
                } else {
                    Spacer(); Text(model.message ?? "Select a frame").foregroundStyle(.secondary); Spacer()
                }
                Text(model.message ?? " ").font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
        }
    }

    private var toolbar: some View {
        HStack {
            Picker("Mode", selection: $model.mode) {
                ForEach(RegionMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).frame(width: 220).labelsHidden()
            Button("Subject") { model.mode = .subject }.keyboardShortcut("s", modifiers: []).hidden().frame(width: 0)
            Button("Neutral") { model.mode = .neutral }.keyboardShortcut("n", modifiers: []).hidden().frame(width: 0)
            Button("Remove last", systemImage: "delete.left") { model.removeLast() }
                .keyboardShortcut(.delete, modifiers: [])
            Spacer()
            Text(model.mode == .subject ? "Drag around the main subject" : "Drag over a really white/grey surface (not blown)")
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
            Button("Previous", systemImage: "chevron.left") { model.step(-1) }.keyboardShortcut(.leftArrow, modifiers: [])
            Button("Next", systemImage: "chevron.right") { model.step(1) }.keyboardShortcut(.rightArrow, modifiers: [])
        }
    }

    @ViewBuilder private func statusIcon(_ status: FrameStatus) -> some View {
        switch status {
        case .complete: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .gaps: Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
        case .invalid: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case .unlabeled: Image(systemName: "circle.dashed").foregroundStyle(.secondary)
        }
    }
}

struct RegionCanvas: View {
    let image: CGImage
    let subject: Region?
    let neutral: [Region]
    let onDraw: (Region) -> Void
    @State private var drag: (start: CGPoint, end: CGPoint)?

    var body: some View {
        GeometryReader { geo in
            let frame = fittedFrame(in: geo.size)
            ZStack(alignment: .topLeading) {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: frame.minY)
                if let subject { box(subject, in: frame, color: .yellow, label: "subject") }
                ForEach(Array(neutral.enumerated()), id: \.offset) { i, r in
                    box(r, in: frame, color: .cyan, label: "neutral \(i + 1)")
                }
                if let drag {
                    Rectangle().stroke(.white, style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                        .frame(width: abs(drag.end.x - drag.start.x), height: abs(drag.end.y - drag.start.y))
                        .offset(x: min(drag.start.x, drag.end.x), y: min(drag.start.y, drag.end.y))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .local)
                    .onChanged { drag = ($0.startLocation, $0.location) }
                    .onEnded { value in
                        drag = nil
                        if let r = Region.fromDrag(start: (value.startLocation.x, value.startLocation.y),
                                                   end: (value.location.x, value.location.y),
                                                   imageFrame: (frame.minX, frame.minY, frame.width, frame.height)) {
                            onDraw(r)
                        }
                    }
            )
        }
    }

    private func fittedFrame(in size: CGSize) -> CGRect {
        let scale = min(size.width / CGFloat(image.width), size.height / CGFloat(image.height))
        let w = CGFloat(image.width) * scale, h = CGFloat(image.height) * scale
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }

    private func box(_ r: Region, in frame: CGRect, color: Color, label: String) -> some View {
        let rect = CGRect(x: frame.minX + r.x * frame.width, y: frame.minY + r.y * frame.height,
                          width: r.w * frame.width, height: r.h * frame.height)
        return ZStack(alignment: .topLeading) {
            Rectangle().fill(color.opacity(0.12))
            Rectangle().stroke(color, lineWidth: 2)
            Text(label).font(.caption2.bold()).padding(2).background(color).foregroundStyle(.black)
        }
        .frame(width: rect.width, height: rect.height)
        .offset(x: rect.minX, y: rect.minY)
        .allowsHitTesting(false)
    }
}
