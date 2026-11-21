import CoreGraphics

/// Maps a point on the portrait preview to the camera's point of interest (0–1, sensor orientation).
/// The preview shows the full sensor frame upright with the same 3:4 aspect, so the mapping is a rotation:
/// sensor x runs top→bottom on screen, sensor y runs right→left (back camera, portrait).
public enum DevicePoint {
    public static func fromPortraitPreview(_ point: CGPoint, viewSize: CGSize) -> CGPoint {
        guard viewSize.width > 0, viewSize.height > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        let x = min(1, max(0, point.y / viewSize.height))
        let y = min(1, max(0, 1 - point.x / viewSize.width))
        return CGPoint(x: x, y: y)
    }
}
