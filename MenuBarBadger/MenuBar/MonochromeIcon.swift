import AppKit

/// Makes a template image from an app icon. The alpha of a macOS 26 icon is only a filled rounded square, so the
/// mask comes from the colour distance to the tile background, row by row (tiles often have a vertical gradient).
/// Brightness steps inside a shape become thin gaps, so that details like the flap of the Mail envelope stay.
enum MonochromeIcon {
    private static let side = 128
    private static let solidAlpha: UInt8 = 240
    private static let tileCoverage = 0.55
    private static let rimInset = side / 24
    private static let distanceRange = 0.08...0.3
    private static let innerEdgeStep = 0.06
    private static let innerEdgeAlpha = 0.1

    static func make(from icon: NSImage, size: CGFloat, scale: CGFloat) -> NSImage? {
        guard let source = Bitmap(icon: icon, side: side) else { return nil }
        let mask = alphaMask(of: source)
        guard let maskImage = maskImage(mask), let crop = contentBounds(of: mask) else { return nil }

        let pixels = Int((size * scale).rounded())
        guard let context = CGContext(
            data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        let fit = CGFloat(pixels) / crop.width
        context.draw(maskImage, in: CGRect(
            x: -crop.minX * fit, y: -crop.minY * fit,
            width: CGFloat(side) * fit, height: CGFloat(side) * fit
        ))
        guard let cgImage = context.makeImage() else { return nil }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
        image.isTemplate = true
        return image
    }

    private static func alphaMask(of bitmap: Bitmap) -> [Double] {
        let isTile = Double(bitmap.solidCount) / Double(side * side) > tileCoverage
        guard isTile else { return bitmap.alphas }

        let rows = (0..<side).map { bitmap.solidSpan(row: $0) }
        let backgrounds = rowBackgrounds(of: bitmap, rows: rows)
        let filledRows = rows.indices.filter { rows[$0] != nil }
        guard let top = filledRows.first, let bottom = filledRows.last else { return bitmap.alphas }

        var mask = [Double](repeating: 0, count: side * side)
        for y in (top + rimInset)...max(top + rimInset, bottom - rimInset) {
            guard let span = rows[y] else { continue }
            for x in (span.lowerBound + rimInset)...max(span.lowerBound + rimInset, span.upperBound - rimInset) {
                let distance = bitmap.color(x, y).distance(to: backgrounds[y])
                mask[y * side + x] = smoothstep(distance, in: distanceRange) * bitmap.alpha(x, y)
            }
        }
        return cutInnerEdges(of: mask, in: bitmap)
    }

    private static func rowBackgrounds(of bitmap: Bitmap, rows: [ClosedRange<Int>?]) -> [Color] {
        let sampled = rows.enumerated().map { y, span -> Color? in
            guard let span, span.count > 4 * rimInset else { return nil }
            return bitmap.color(span.lowerBound + rimInset, y).mixed(with: bitmap.color(span.upperBound - rimInset, y))
        }
        let known = sampled.indices.filter { sampled[$0] != nil }
        return sampled.indices.map { y in
            sampled[y] ?? known.min { abs($0 - y) < abs($1 - y) }.flatMap { sampled[$0] } ?? Color(r: 1, g: 1, b: 1)
        }
    }

    private static func cutInnerEdges(of mask: [Double], in bitmap: Bitmap) -> [Double] {
        var result = mask
        for y in 0..<(side - 1) {
            for x in 0..<(side - 1) where mask[y * side + x] > 0.5 {
                let here = bitmap.color(x, y).luminance
                for (dx, dy) in [(1, 0), (0, 1)] where mask[(y + dy) * side + x + dx] > 0.5 {
                    if abs(bitmap.color(x + dx, y + dy).luminance - here) > innerEdgeStep {
                        result[y * side + x] *= innerEdgeAlpha
                    }
                }
            }
        }
        return result
    }

    private static func contentBounds(of mask: [Double]) -> CGRect? {
        var minX = side, minY = side, maxX = -1, maxY = -1
        for y in 0..<side {
            for x in 0..<side where mask[y * side + x] > 0.3 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX else { return nil }
        let width = maxX - minX + 1, height = maxY - minY + 1, square = max(width, height)
        // The bitmap rows run from the top; CoreGraphics draws from the bottom.
        return CGRect(
            x: CGFloat(minX) - CGFloat(square - width) / 2,
            y: CGFloat(side - 1 - maxY) - CGFloat(square - height) / 2,
            width: CGFloat(square), height: CGFloat(square)
        )
    }

    private static func maskImage(_ mask: [Double]) -> CGImage? {
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        for index in mask.indices {
            bytes[index * 4 + 3] = UInt8((min(max(mask[index], 0), 1) * 255).rounded())
        }
        guard let context = CGContext(
            data: &bytes, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        return context.makeImage()
    }

    private static func smoothstep(_ value: Double, in range: ClosedRange<Double>) -> Double {
        let t = min(max((value - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
        return t * t * (3 - 2 * t)
    }

    private struct Color {
        var r, g, b: Double

        var luminance: Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }

        func distance(to other: Color) -> Double {
            let dr = r - other.r, dg = g - other.g, db = b - other.b
            return (dr * dr + dg * dg + db * db).squareRoot() / 3.0.squareRoot()
        }

        func mixed(with other: Color) -> Color {
            Color(r: (r + other.r) / 2, g: (g + other.g) / 2, b: (b + other.b) / 2)
        }
    }

    /// RGBA pixels with the first row at the top.
    private struct Bitmap {
        private var bytes: [UInt8]

        init?(icon: NSImage, side: Int) {
            bytes = [UInt8](repeating: 0, count: side * side * 4)
            let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
                guard let context = CGContext(
                    data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ) else { return false }
                var rect = CGRect(x: 0, y: 0, width: side, height: side)
                guard let image = icon.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return false }
                context.interpolationQuality = .high
                context.draw(image, in: rect)
                return true
            }
            guard drawn else { return nil }
        }

        var alphas: [Double] {
            stride(from: 3, to: bytes.count, by: 4).map { Double(bytes[$0]) / 255 }
        }

        var solidCount: Int {
            stride(from: 3, to: bytes.count, by: 4).count(where: { bytes[$0] > MonochromeIcon.solidAlpha })
        }

        func solidSpan(row y: Int) -> ClosedRange<Int>? {
            let solid = (0..<MonochromeIcon.side).filter { rawAlpha($0, y) > MonochromeIcon.solidAlpha }
            guard let first = solid.first, let last = solid.last else { return nil }
            return first...last
        }

        func alpha(_ x: Int, _ y: Int) -> Double { Double(rawAlpha(x, y)) / 255 }

        func color(_ x: Int, _ y: Int) -> Color {
            let index = (y * MonochromeIcon.side + x) * 4
            let alpha = max(Double(bytes[index + 3]) / 255, 1 / 255)
            return Color(
                r: Double(bytes[index]) / 255 / alpha,
                g: Double(bytes[index + 1]) / 255 / alpha,
                b: Double(bytes[index + 2]) / 255 / alpha
            )
        }

        private func rawAlpha(_ x: Int, _ y: Int) -> UInt8 { bytes[(y * MonochromeIcon.side + x) * 4 + 3] }
    }
}
