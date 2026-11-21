import Foundation

/// The per-pixel part of a look, as a pure function on gamma-encoded sRGB values in 0…1.
/// Every step is smooth and monotonic in brightness, so the result has no banding (SC-001) and
/// can be baked into a 3D LUT. Same input always gives the same output (FR-003).
public struct ColorTransform: Sendable {
    public let adjustments: LookAdjustments

    public init(_ adjustments: LookAdjustments) { self.adjustments = adjustments }

    public func apply(_ r0: Double, _ g0: Double, _ b0: Double) -> (Double, Double, Double) {
        let a = adjustments
        var r = r0, g = g0, b = b0

        // 1. Exposure (±1 stop) and white balance, in linear light.
        if a.exposure != 0 || a.temperature != 0 || a.tint != 0 {
            var lr = linear(r), lg = linear(g), lb = linear(b)
            let gain = pow(2, a.exposure)
            let rt = 1 + 0.10 * a.temperature, bt = 1 - 0.10 * a.temperature, gt = 1 - 0.06 * a.tint
            let norm = 0.2126 * rt + 0.7152 * gt + 0.0722 * bt // keep brightness
            lr *= gain * rt / norm; lg *= gain * gt / norm; lb *= gain * bt / norm
            r = gamma(softClip(lr)); g = gamma(softClip(lg)); b = gamma(softClip(lb))
        }

        // 2. Contrast: symmetric S-curve with fixed 0, 0.5 and 1.
        if a.contrast != 0 {
            let k = pow(2, a.contrast * 0.8)
            r = sCurve(r, k); g = sCurve(g, k); b = sCurve(b, k)
        }

        // 3. Shadows / highlights on luminance, hue preserved.
        if a.shadows != 0 || a.highlights != 0 {
            let l = luma(r, g, b)
            let delta = a.shadows * 0.6 * l * pow(1 - l, 3) + a.highlights * 0.6 * pow(l, 3) * (1 - l)
            if l > 1e-6 {
                let s = (l + delta) / l
                r *= s; g *= s; b *= s
            }
        }

        // 4. Saturation and vibrance (vibrance favors muted colors).
        if a.saturation != 0 || a.vibrance != 0 {
            let l = luma(r, g, b)
            let chroma = max(r, g, b) - min(r, g, b)
            let factor = max(0, (1 + a.saturation) * (1 + a.vibrance * (1 - min(1, chroma))))
            r = l + (r - l) * factor; g = l + (g - l) * factor; b = l + (b - l) * factor
        }

        // 5. Color ranges (hue / saturation / luminance per hue band). Grays are untouched.
        if !a.ranges.isEmpty {
            (r, g, b) = (clamp(r), clamp(g), clamp(b))
            var (h, s, v) = rgbToHSV(r, g, b)
            let colorful = smoothstep(0.02, 0.15, s)
            if colorful > 0 {
                var dh = 0.0, ds = 1.0, dv = 1.0
                for (range, adj) in a.ranges {
                    let w = bandWeight(h, center: range.center) * colorful
                    guard w > 0 else { continue }
                    dh += w * adj.hue / 24
                    ds *= 1 + w * adj.saturation
                    dv *= 1 + w * adj.luminance * 0.25
                }
                h = (h + dh).truncatingRemainder(dividingBy: 1); if h < 0 { h += 1 }
                s = clamp(s * ds); v = clamp(v * dv)
                (r, g, b) = hsvToRGB(h, s, v)
            }
        }

        // 6. Split toning: tint shadows and highlights.
        let st = a.splitTone
        if st.shadowAmount != 0 || st.highlightAmount != 0 {
            let l = luma(clamp(r), clamp(g), clamp(b))
            let ws = st.shadowAmount * 0.15 * pow(1 - l, 2), wh = st.highlightAmount * 0.15 * pow(l, 2)
            let cs = hsvToRGB(st.shadowHue, 1, 1), ch = hsvToRGB(st.highlightHue, 1, 1)
            r += ws * (cs.0 - 0.5) + wh * (ch.0 - 0.5)
            g += ws * (cs.1 - 0.5) + wh * (ch.1 - 0.5)
            b += ws * (cs.2 - 0.5) + wh * (ch.2 - 0.5)
        }

        // 7. Fade: lifted blacks.
        if a.fade != 0 {
            let f = a.fade * 0.12
            r = f + r * (1 - f); g = f + g * (1 - f); b = f + b * (1 - f)
        }

        return (clamp(r), clamp(g), clamp(b))
    }

    /// RGBA float cube for `CIColorCubeWithColorSpace`: red varies fastest, then green, then blue.
    public func lutData(size: Int = 33) -> Data {
        var values = [Float](repeating: 1, count: size * size * size * 4)
        let step = 1.0 / Double(size - 1)
        var i = 0
        for bi in 0..<size {
            for gi in 0..<size {
                for ri in 0..<size {
                    let (r, g, b) = apply(Double(ri) * step, Double(gi) * step, Double(bi) * step)
                    values[i] = Float(r); values[i + 1] = Float(g); values[i + 2] = Float(b)
                    i += 4
                }
            }
        }
        return values.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}

// MARK: - Math helpers

func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
func luma(_ r: Double, _ g: Double, _ b: Double) -> Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }
func smoothstep(_ e0: Double, _ e1: Double, _ x: Double) -> Double {
    let t = clamp((x - e0) / (e1 - e0)); return t * t * (3 - 2 * t)
}

func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
func gamma(_ c: Double) -> Double {
    let c = max(0, c)
    return c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055
}

/// Rolls values above 0.9 smoothly toward 1 instead of clipping (keeps highlight detail).
func softClip(_ x: Double) -> Double {
    let knee = 0.9
    guard x > knee else { return x }
    let over = x - knee
    return knee + (1 - knee) * (1 - exp(-over / (1 - knee)))
}

func sCurve(_ x: Double, _ k: Double) -> Double {
    let x = clamp(x)
    let a = pow(x, k), b = pow(1 - x, k)
    return a + b == 0 ? x : a / (a + b)
}

/// Raised-cosine weight of a hue around a band center, 30° wide on each side.
func bandWeight(_ h: Double, center: Double) -> Double {
    var d = abs(h - center)
    d = min(d, 1 - d)
    let width = 1.0 / 12
    return d < width ? 0.5 * (1 + cos(.pi * d / width)) : 0
}

func rgbToHSV(_ r: Double, _ g: Double, _ b: Double) -> (Double, Double, Double) {
    let mx = max(r, g, b), mn = min(r, g, b), d = mx - mn
    var h = 0.0
    if d > 0 {
        if mx == r { h = ((g - b) / d).truncatingRemainder(dividingBy: 6) }
        else if mx == g { h = (b - r) / d + 2 }
        else { h = (r - g) / d + 4 }
        h /= 6; if h < 0 { h += 1 }
    }
    return (h, mx == 0 ? 0 : d / mx, mx)
}

func hsvToRGB(_ h: Double, _ s: Double, _ v: Double) -> (Double, Double, Double) {
    let h6 = (h - floor(h)) * 6
    let i = Int(h6) % 6, f = h6 - floor(h6)
    let p = v * (1 - s), q = v * (1 - s * f), t = v * (1 - s * (1 - f))
    switch i {
    case 0: return (v, t, p)
    case 1: return (q, v, p)
    case 2: return (p, v, t)
    case 3: return (p, q, v)
    case 4: return (t, p, v)
    default: return (v, p, q)
    }
}
