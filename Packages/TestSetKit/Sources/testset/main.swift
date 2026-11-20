// testset — spec 00 validation tool.
//
//   testset validate [DIR] [--strict] [--json]   report label errors, unlabeled frames, coverage
//   testset schema                               print the label JSON Schema (derived from LabelSchema)
//   testset init-labels [DIR]                    write a label skeleton next to every unlabeled image
//
// DIR defaults to $PHOTOSHAPE_TESTSET or the nearest TestSet/ above the current directory.
// Exit code: 0 ok, 1 label errors (or, with --strict, unmet quotas), 2 usage/IO error.

import Foundation
import TestSetKit

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(2)
}

func loadSet(_ path: String?) -> TestSet {
    do {
        if let path { return try TestSet.load(at: URL(fileURLWithPath: path, isDirectory: true)) }
        let cwd = FileManager.default.currentDirectoryPath + "/."
        return try TestSet.locate(startingAt: cwd)
    } catch {
        fail("\(error)")
    }
}

var args = Array(CommandLine.arguments.dropFirst())
let command = args.isEmpty ? "validate" : args.removeFirst()
let flags = Set(args.filter { $0.hasPrefix("--") })
let positional = args.filter { !$0.hasPrefix("--") }

switch command {
case "validate":
    let unknown = flags.subtracting(["--strict", "--json"])
    if !unknown.isEmpty { fail("unknown option \(unknown.sorted().joined(separator: ", "))") }
    let set = loadSet(positional.first)
    let coverage = CoverageReport(set)
    let strict = flags.contains("--strict")

    if flags.contains("--json") {
        let json: [String: Any] = [
            "root": set.root.path,
            "valid_frames": set.frames.count,
            "issues": set.report.issues.map { ["file": $0.file, "field": $0.field as Any? ?? NSNull(), "message": $0.message] as [String: Any] },
            "unlabeled": set.report.unlabeled,
            "orphan_labels": set.report.orphanLabels,
            "distribution": coverage.distribution,
            "quotas": coverage.quotas.map { ["id": $0.id, "required": $0.required, "actual": $0.actual, "met": $0.isMet] },
        ]
        let data = try! JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        print(String(decoding: data, as: UTF8.self))
    } else {
        print("Test set: \(set.root.path)")
        print("Valid frames: \(set.frames.count)\n")

        if !set.report.issues.isEmpty {
            print("✗ Label errors (\(set.report.issues.count))")
            for issue in set.report.issues {
                print("  \(issue.file)\(issue.field.map { " · \($0)" } ?? ""): \(issue.message)")
            }
            print()
        }
        if !set.report.orphanLabels.isEmpty {
            print("✗ Label files without an image (\(set.report.orphanLabels.count))")
            set.report.orphanLabels.forEach { print("  \($0)") }
            print()
        }
        if !set.report.unlabeled.isEmpty {
            print("• Unlabeled, not used in tests (\(set.report.unlabeled.count)) — run `testset init-labels`")
            set.report.unlabeled.forEach { print("  \($0)") }
            print()
        }

        print("Quotas")
        for q in coverage.quotas {
            print("  \(q.isMet ? "✓" : "·") \(q.title.padding(toLength: 42, withPad: " ", startingAt: 0)) \(q.actual)/\(q.required)")
        }
        print("\nDistribution")
        for field in LabelSchema.fields.map(\.key) + ["has_depth"] {
            guard let values = coverage.distribution[field] else { continue }
            let parts = values.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }
            print("  \(field): \(parts.joined(separator: " · "))")
        }
        print()
        print(set.report.isValid ? "Labels OK." : "Labels have errors.")
        print(coverage.allQuotasMet ? "All quotas met — brain acceptance criteria can be measured."
                                    : "Quotas not met yet — brain acceptance criteria are not \"measured\" (spec 00).")
    }
    let ok = set.report.isValid && (!strict || coverage.allQuotasMet)
    exit(ok ? 0 : 1)

case "schema":
    print(String(decoding: try! LabelSchema.jsonSchema(), as: UTF8.self))

case "init-labels":
    let set = loadSet(positional.first)
    var created = 0
    for relative in set.report.unlabeled {
        let image = set.root.appendingPathComponent(relative)
        let target = image.deletingPathExtension().appendingPathExtension("json")
        guard !FileManager.default.fileExists(atPath: target.path) else { continue }
        // Empty strings fail validation on purpose until the frame is actually labeled.
        let skeleton = """
        {
          "id": "\(image.deletingPathExtension().lastPathComponent)",
          "category": "cafe_food",
          "scene_type": "",
          "light": [],
          "exposure": "",
          "white_balance": "",
          "highlights_clipped": false,
          "sharpness": "",
          "composition": "",
          "people_visible": "none"
        }

        """
        do { try Data(skeleton.utf8).write(to: target); created += 1 } catch { fail("\(error)") }
        print("created \(TestSet.relativePath(of: target, in: set.root))")
    }
    print("\(created) label skeleton(s) created. Fill them in, then run `testset validate`.")

default:
    fail("unknown command \"\(command)\". Use: validate | schema | init-labels")
}
