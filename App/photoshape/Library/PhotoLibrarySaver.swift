import CaptureKit
import Photos
import UniformTypeIdentifiers

enum SaveOutcome: Sendable {
    case saved
    /// The user declined "add photos" access.
    case denied
    /// Saving failed for another reason (e.g. storage full).
    case failed
}

/// Saves with add-only access (Constitution I). The original capture stays the Photos original and the 4:5 edit
/// is attached as an edit with our adjustment data, so "Revert" in Photos brings back the full frame (FR-004).
enum PhotoLibrarySaver {
    static func save(_ capture: ProcessedCapture, formatIdentifier: String) async -> SaveOutcome {
        var status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .notDetermined { status = await PHPhotoLibrary.requestAuthorization(for: .addOnly) }
        guard status == .authorized || status == .limited else { return .denied }

        let recordData: Data
        do { recordData = try capture.record.encoded() } catch { return .failed }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: capture.original, options: nil)
                guard let placeholder = request.placeholderForCreatedAsset else { return }
                let output = PHContentEditingOutput(placeholderForCreatedAsset: placeholder)
                output.adjustmentData = PHAdjustmentData(formatIdentifier: formatIdentifier,
                                                         formatVersion: EditRecord.formatVersion, data: recordData)
                // If the edit cannot be attached the original is still saved; the photo is never lost.
                guard let url = try? output.renderedContentURL(for: capture.editedType),
                      (try? capture.edited.write(to: url)) != nil else { return }
                request.contentEditingOutput = output
            }
            return .saved
        } catch {
            return .failed
        }
    }
}
