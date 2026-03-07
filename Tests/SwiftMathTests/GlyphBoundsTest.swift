import XCTest
@testable import SwiftMath
import CoreText
import CoreGraphics

final class GlyphBoundsTest: XCTestCase {

    var font: MTFont!

    override func setUp() {
        super.setUp()
        font = MTFontManager().termesFont(withSize: 20)
    }

    func testGlyphBounds() throws {
        // Get the actual glyph objects
        let circumflexGlyph = font.get(glyphWithName: "circumflex")
        let arrowGlyph = font.get(glyphWithName: "arrowright") // rightarrow for stretchy overrightarrow


        // Get bounding rects for both glyphs
        var circumflexRect = CGRect.zero
        var circumflexGlyphCopy = circumflexGlyph
        CTFontGetBoundingRectsForGlyphs(font.ctFont, .horizontal, &circumflexGlyphCopy, &circumflexRect, 1)

        var arrowRect = CGRect.zero
        var arrowGlyphCopy = arrowGlyph
        CTFontGetBoundingRectsForGlyphs(font.ctFont, .horizontal, &arrowGlyphCopy, &arrowRect, 1)



        // Check if circumflex has significant space at the bottom
        if -circumflexRect.minY < 1.0 && circumflexRect.maxY > 10.0 {
        }

        if -arrowRect.minY < 1.0 && arrowRect.maxY < 10.0 {
        }
    }
}
