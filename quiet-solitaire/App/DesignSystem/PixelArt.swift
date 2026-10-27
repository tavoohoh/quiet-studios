import SwiftUI

/// Bitmaps for the Pixel deck (same grids as the canvas): suits 9×9, ranks 3×5, courts 11×14.
enum PixelArt {
    static let suits: [[String]] = [
        ["....x....", "...xxx...", "..xxxxx..", ".xxxxxxx.", "xxxxxxxxx", "xxxxxxxxx", ".xx.x.xx.", "....x....", "..xxxxx.."],
        [".........", ".xx...xx.", "xxxx.xxxx", "xxxxxxxxx", "xxxxxxxxx", ".xxxxxxx.", "..xxxxx..", "...xxx...", "....x...."],
        ["....x....", "...xxx...", "..xxxxx..", ".xxxxxxx.", "xxxxxxxxx", ".xxxxxxx.", "..xxxxx..", "...xxx...", "....x...."],
        ["...xxx...", "..xxxxx..", "...xxx...", ".xx.x.xx.", "xxxxxxxxx", "xxxxxxxxx", ".xx.x.xx.", "....x....", "..xxxxx.."],
    ]

    private static let glyphs: [Character: [String]] = [
        "A": [".x.", "x.x", "xxx", "x.x", "x.x"], "2": ["xx.", "..x", ".x.", "x..", "xxx"], "3": ["xx.", "..x", ".x.", "..x", "xx."],
        "4": ["x.x", "x.x", "xxx", "..x", "..x"], "5": ["xxx", "x..", "xx.", "..x", "xx."], "6": [".xx", "x..", "xxx", "x.x", "xxx"],
        "7": ["xxx", "..x", ".x.", ".x.", ".x."], "8": ["xxx", "x.x", "xxx", "x.x", "xxx"], "9": ["xxx", "x.x", "xxx", "..x", "xx."],
        "1": [".x.", "xx.", ".x.", ".x.", "xxx"], "0": ["xxx", "x.x", "x.x", "x.x", "xxx"],
        "J": ["..x", "..x", "..x", "x.x", ".x."], "Q": [".x.", "x.x", "x.x", "xx.", ".xx"], "K": ["x.x", "x.x", "xx.", "x.x", "x.x"],
    ]

    /// A rank as one bitmap ("10" is two glyphs one pixel apart).
    static func rank(_ label: String) -> [String] {
        var rows = Array(repeating: "", count: 5)
        for (i, character) in label.enumerated() {
            for y in 0..<5 { rows[y] += (i > 0 ? "." : "") + glyphs[character]![y] }
        }
        return rows
    }

    /// Courts by color key: r robe (suit color), g gold, s skin, h hair, b blue, k ink.
    static let courts: [String: [String]] = [
        "K": [".g..g.g..g.", ".ggggggggg.", ".gg.grg.gg.", "..sssssss..", "..sksssks..", "..sssssss..", "..shhhhhs..",
              "..hhhhhhh..", "...hhhhh...", "....hhh....", ".rrrrgrrrr.", "rrrrrgrrrrr", "rrrrrgrrrrr", "rrrrrgrrrrr"],
        "Q": ["...g.g.g...", "...ggggg...", "..hhhhhhh..", ".hsssssssh.", ".hsksssksh.", ".hsssssssh.", ".hsssrsssh.",
              ".hh.sss.hh.", ".hh..s..hh.", ".hh.....hh.", "..rrrgrrr..", ".rrrrgrrrr.", "rrrrrgrrrrr", "rrrrrgrrrrr"],
        "J": [".........g.", "...bbbbbg..", "..bbbbbbb..", ".bbbbbbbbb.", "..hsssssh..", "..sksssks..", "..sssssss..",
              "..sssrsss..", "...sssss...", "....sss....", "..rrrgrrr..", ".rrrrgrrrr.", "rrrrrgrrrrr", "rrrrrgrrrrr"],
    ]
    static let hair: [String: Color] = ["K": .hex("#D9D0C0"), "Q": .hex("#8A4B2A"), "J": .hex("#6B4A2E")]
}

/// One-color bitmap, `unit` points per pixel.
struct PixelGlyph: View {
    let rows: [String]
    let unit: CGFloat
    let color: Color

    var body: some View {
        Canvas { context, _ in
            var path = Path()
            for (y, row) in rows.enumerated() {
                for (x, pixel) in row.enumerated() where pixel == "x" {
                    path.addRect(CGRect(x: CGFloat(x) * unit, y: CGFloat(y) * unit, width: unit, height: unit))
                }
            }
            context.fill(path, with: .color(color))
        }
        .frame(width: CGFloat(rows.first?.count ?? 0) * unit, height: CGFloat(rows.count) * unit)
    }
}

struct PixelPortrait: View {
    let rank: String
    let unit: CGFloat
    let robe: Color

    var body: some View {
        Canvas { context, _ in
            let palette: [Character: Color] = [
                "r": robe, "g": .hex("#DFB43A"), "s": .hex("#E9B98C"), "h": PixelArt.hair[rank] ?? .brown,
                "b": .hex("#3F5FA8"), "k": .hex("#222034"),
            ]
            for (y, row) in (PixelArt.courts[rank] ?? []).enumerated() {
                for (x, pixel) in row.enumerated() {
                    guard let color = palette[pixel] else { continue }
                    context.fill(Path(CGRect(x: CGFloat(x) * unit, y: CGFloat(y) * unit, width: unit + 0.3, height: unit + 0.3)), with: .color(color))
                }
            }
        }
    }
}
