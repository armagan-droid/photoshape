import CompositionKit
import SwiftUI

/// "Ayarlar" on the example card (spec 05 Hikâye 8): the example's real camera values when the photo has them,
/// the approximate values read from the picture always, each with what it did to the photo, next to what the
/// camera is doing now. Information only: nothing here can be changed (Constitution II).
struct ExampleSettingsView: View {
    let settings: ExampleSettings?
    let measurements: ExampleMeasurements
    let live: LiveExposure?
    /// Brightness the app applies for this example, EV.
    let appBias: Double
    let lensKey: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("settings.title").font(.headline)
            if let settings {
                section("settings.real") { realRows(settings) }
            } else {
                Text("settings.noCameraData").font(.footnote).foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.noCameraData")
            }
            section("settings.estimated") { estimatedRows }
            if settings == nil, let live {
                SettingRow(title: "settings.yourCameraNow", value: Fmt.cameraSummary(live), explanation: nil, camera: nil)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.08)))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings")
    }

    private func section(_ title: LocalizedStringKey, @ViewBuilder rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.6)).textCase(.uppercase)
            rows()
        }
    }

    @ViewBuilder private func realRows(_ s: ExampleSettings) -> some View {
        if let t = s.exposureTime {
            SettingRow(title: "settings.shutter", value: Fmt.seconds(t), explanation: s.shutterExplanation,
                       camera: live.map { Fmt.seconds($0.exposureTime) }).accessibilityIdentifier("settings.shutter")
        }
        if let f = s.fNumber {
            SettingRow(title: "settings.aperture", value: Fmt.fNumber(f), explanation: s.apertureExplanation,
                       camera: live.map { Fmt.fNumber($0.fNumber) })
        }
        if let iso = s.iso {
            SettingRow(title: "settings.iso", value: "ISO \(iso)", explanation: s.isoExplanation,
                       camera: live.map { "ISO \(Int($0.iso.rounded()))" }).accessibilityIdentifier("settings.iso")
        }
        if let f35 = s.focalLength35 {
            SettingRow(title: "settings.focal", value: "\(Int(f35.rounded())) mm", explanation: s.lensKey,
                       camera: String(localized: String.LocalizationValue(lensKey)))
        }
        if let bias = s.exposureBias {
            SettingRow(title: "settings.bias", value: Fmt.ev(bias), explanation: s.biasExplanation, camera: nil)
        }
        if let flash = s.flashKey {
            SettingRow(title: "settings.flash", value: String(localized: String.LocalizationValue(flash)), explanation: nil, camera: nil)
        }
        if let model = s.cameraModel {
            SettingRow(title: "settings.device", value: model, explanation: nil, camera: nil)
        }
    }

    @ViewBuilder private var estimatedRows: some View {
        let m = measurements
        SettingRow(title: "settings.brightness", value: Fmt.ev(m.brightnessEV), explanation: m.brightnessKey,
                   camera: Fmt.appAdjustment(appBias)).accessibilityIdentifier("settings.brightness")
        SettingRow(title: "settings.contrast", value: Fmt.stops(m.contrastStops), explanation: m.contrastKey, camera: nil)
        if let clip = m.highlightClip {
            SettingRow(title: "settings.highlights", value: Fmt.percent(clip), explanation: m.highlightKey, camera: nil)
        }
        if let clip = m.shadowClip {
            SettingRow(title: "settings.shadows", value: Fmt.percent(clip), explanation: m.shadowKey, camera: nil)
        }
        if let k = m.colorTemperature {
            SettingRow(title: "settings.temperature", value: Fmt.kelvin(k), explanation: m.temperatureKey,
                       camera: live?.whiteBalance.map { Fmt.yourCamera(Fmt.kelvin($0)) }).accessibilityIdentifier("settings.temperature")
        }
        if let tint = m.tintKey {
            SettingRow(title: "settings.tint", value: String(localized: String.LocalizationValue(tint)), explanation: nil, camera: nil)
        }
    }
}

/// One value: title, the number, what it did, and the camera's value now.
private struct SettingRow: View {
    let title: LocalizedStringKey
    let value: String
    let explanation: String?
    /// Already formatted, including "Kameran: …" / "Uygulama: …" where it applies.
    let camera: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).foregroundStyle(.white.opacity(0.75))
                Spacer(minLength: 8)
                Text(verbatim: value).font(.body.monospacedDigit().weight(.semibold))
            }
            if explanation != nil || camera != nil {
                HStack(alignment: .firstTextBaseline) {
                    if let explanation { Text(LocalizedStringKey(explanation)).foregroundStyle(.white.opacity(0.6)) }
                    Spacer(minLength: 8)
                    if let camera { Text(verbatim: camera).foregroundStyle(.yellow.opacity(0.9)) }
                }
                .font(.footnote)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Numbers in the user's language and region (spec 05 FR-021): decimal comma in Turkish, units from the catalog.
enum Fmt {
    static func seconds(_ t: Double) -> String {
        let text = t >= 1 ? t.formatted(.number.precision(.fractionLength(0...1))) : ExampleSettings.shutterText(t)
        return String(localized: "settings.unit.seconds \(text)")
    }

    static func fNumber(_ f: Double) -> String { "f/" + f.formatted(.number.precision(.fractionLength(1))) }

    static func ev(_ v: Double) -> String {
        let text = v.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always(includingZero: false)))
        return text + " EV"
    }

    static func stops(_ v: Double) -> String { String(localized: "settings.unit.stops \(v.formatted(.number.precision(.fractionLength(0...1))))") }

    static func percent(_ v: Double) -> String { v.formatted(.percent.precision(.fractionLength(0))) }

    static func kelvin(_ k: Double) -> String { "≈ " + Int(k.rounded()).formatted() + " K" }

    static func yourCamera(_ value: String) -> String { String(localized: "settings.yourCamera \(value)") }

    static func appAdjustment(_ bias: Double) -> String { String(localized: "settings.appAdjustment \(ev((bias * 3).rounded() / 3))") }

    static func cameraSummary(_ live: LiveExposure) -> String {
        var parts = [seconds(live.exposureTime), "ISO \(Int(live.iso.rounded()))", fNumber(live.fNumber)]
        if let k = live.whiteBalance { parts.append(kelvin(k)) }
        return parts.joined(separator: " · ")
    }
}
