import Foundation

public struct Lab: Sendable, Hashable {
    public var l: Double
    public var a: Double
    public var b: Double
    public init(_ l: Double, _ a: Double, _ b: Double) { self.l = l; self.a = a; self.b = b }
}

/// Color differences for acceptance criteria (spec 03 SC-003, spec 05 SC-002).
public enum ColorScience {
    /// Gamma-encoded sRGB (0…1) → CIE L*a*b* (D65).
    public static func lab(fromSRGB c: (Double, Double, Double)) -> Lab {
        let r = linear(c.0), g = linear(c.1), b = linear(c.2)
        let x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047
        let y = (0.2126729 * r + 0.7151522 * g + 0.0721750 * b)
        let z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883
        func f(_ t: Double) -> Double { t > 216.0 / 24389 ? cbrt(t) : (24389.0 / 27 * t + 16) / 116 }
        let fx = f(x), fy = f(y), fz = f(z)
        return Lab(116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))
    }

    /// CIEDE2000 (Sharma, Wu & Dalal 2005).
    public static func deltaE2000(_ p: Lab, _ q: Lab) -> Double {
        let deg = Double.pi / 180
        let c1 = hypot(p.a, p.b), c2 = hypot(q.a, q.b)
        let cMean = (c1 + c2) / 2
        let c7 = pow(cMean, 7)
        let g = 0.5 * (1 - sqrt(c7 / (c7 + pow(25, 7))))
        let a1 = (1 + g) * p.a, a2 = (1 + g) * q.a
        let c1p = hypot(a1, p.b), c2p = hypot(a2, q.b)
        func hue(_ b: Double, _ a: Double) -> Double {
            if a == 0 && b == 0 { return 0 }
            let h = atan2(b, a) / deg
            return h < 0 ? h + 360 : h
        }
        let h1 = hue(p.b, a1), h2 = hue(q.b, a2)

        let dL = q.l - p.l
        let dC = c2p - c1p
        var dh = 0.0
        if c1p * c2p != 0 {
            dh = h2 - h1
            if dh > 180 { dh -= 360 } else if dh < -180 { dh += 360 }
        }
        let dH = 2 * sqrt(c1p * c2p) * sin(dh / 2 * deg)

        let lMean = (p.l + q.l) / 2
        let cpMean = (c1p + c2p) / 2
        var hMean = h1 + h2
        if c1p * c2p != 0 {
            if abs(h1 - h2) <= 180 { hMean /= 2 }
            else if h1 + h2 < 360 { hMean = (h1 + h2 + 360) / 2 }
            else { hMean = (h1 + h2 - 360) / 2 }
        }
        let t = 1 - 0.17 * cos((hMean - 30) * deg) + 0.24 * cos(2 * hMean * deg)
            + 0.32 * cos((3 * hMean + 6) * deg) - 0.20 * cos((4 * hMean - 63) * deg)
        let dTheta = 30 * exp(-pow((hMean - 275) / 25, 2))
        let cp7 = pow(cpMean, 7)
        let rc = 2 * sqrt(cp7 / (cp7 + pow(25, 7)))
        let sl = 1 + 0.015 * pow(lMean - 50, 2) / sqrt(20 + pow(lMean - 50, 2))
        let sc = 1 + 0.045 * cpMean
        let sh = 1 + 0.015 * cpMean * t
        let rt = -sin(2 * dTheta * deg) * rc
        return sqrt(pow(dL / sl, 2) + pow(dC / sc, 2) + pow(dH / sh, 2) + rt * (dC / sc) * (dH / sh))
    }
}
