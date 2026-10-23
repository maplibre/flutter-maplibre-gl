import UIKit

/*
 *  Loads an icon the style names by its Flutter asset path, such as assets/pins/pin.png.
 *
 *  With resolution variants (2.0x/pin.png, 3.0x/pin.png) the icon is sized like Image.asset: the
 *  file nearest the screen scale, drawn at its own ratio, the main file at 1. A file without
 *  variants keeps the addImage default, one image pixel per device pixel. AssetIcons.java and the
 *  web loader do the same.
 */
enum AssetIcons {
    // A variant folder as Flutter's asset bundler names them: 2.0x, 3x, 1.5x.
    private static let variantFolder = try! NSRegularExpression(pattern: "^(\\d+(\\.\\d*)?)x$")

    /// The icon at `mainPath`, a path in the app bundle, or nil when neither the file nor a
    /// variant of it exists.
    static func load(mainPath: String, screenScale: CGFloat) -> UIImage? {
        guard let bundlePath = Bundle.main.resourcePath else { return nil }
        let main = (bundlePath as NSString).appendingPathComponent(mainPath)
        let folder = (main as NSString).deletingLastPathComponent
        let fileName = (main as NSString).lastPathComponent
        let fileManager = FileManager.default

        // Ratio to path. A 1.0x folder replaces the main file, as in Flutter.
        var files: [CGFloat: String] = [:]
        if fileManager.fileExists(atPath: main) {
            files[1] = main
        }
        var hasVariants = false
        for child in (try? fileManager.contentsOfDirectory(atPath: folder)) ?? [] {
            guard let ratio = variantRatio(child), ratio > 0 else { continue }
            let path = ((folder as NSString).appendingPathComponent(child) as NSString)
                .appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: path) {
                files[ratio] = path
                hasVariants = true
            }
        }

        let ratio = bestRatio(Array(files.keys), scale: screenScale)
        guard let path = files[ratio], let data = fileManager.contents(atPath: path) else {
            return nil
        }
        return UIImage(data: data, scale: hasVariants ? ratio : screenScale)
    }

    /// The ratio Flutter's AssetImage picks: the exact one, else below a scale of 2 the next
    /// larger one, which upscales less, and above it the nearest one.
    static func bestRatio(_ ratios: [CGFloat], scale: CGFloat) -> CGFloat {
        if ratios.contains(scale) {
            return scale
        }
        let lower = ratios.filter { $0 < scale }.max()
        let upper = ratios.filter { $0 > scale }.min()
        guard let below = lower else { return upper ?? scale }
        guard let above = upper else { return below }
        return scale < 2 || scale > (below + above) / 2 ? above : below
    }

    private static func variantRatio(_ folderName: String) -> CGFloat? {
        let range = NSRange(folderName.startIndex..., in: folderName)
        guard let match = variantFolder.firstMatch(in: folderName, range: range),
              let number = Range(match.range(at: 1), in: folderName),
              let ratio = Double(folderName[number])
        else { return nil }
        return CGFloat(ratio)
    }
}
