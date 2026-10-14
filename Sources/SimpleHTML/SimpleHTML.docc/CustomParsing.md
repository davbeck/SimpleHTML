# Building a custom parser delegate

Create your own output from HTML events, without an intermediate Swift attributed string.

## Overview

Use ``HTMLParser`` when the default builder's tag mapping does not fit your app. A delegate can produce search text, structured records, or attributes for a custom renderer. Keep its state scoped to a single document.

## Extract plain text during parsing

This delegate inserts explicit separators for a small, known set of block tags, honors line breaks, and ignores script and style content. It demonstrates the callback requirements and diagnostic collection:

```swift
import Foundation
import SimpleHTML

final class PlainTextCollector: HTMLParserDelegate {
    var text = ""
    var errors: [ParseError] = []
    private var ignoredDepth = 0

    private func separateBlock() {
        if !text.isEmpty && !text.hasSuffix("\n") {
            text += "\n"
        }
    }

    func parser(_ parser: HTMLParser, didStartElement name: String,
                attributes: [AnyHashable: Any]) {
        if ignoredDepth > 0 || name == "script" || name == "style" {
            ignoredDepth += 1
            return
        }
        if ["p", "div", "li"].contains(name) {
            separateBlock()
        } else if name == "br" {
            text += "\n"
        } else if name == "img", let alt = attributes["alt"] as? String {
            text += alt
        }
    }

    func parser(_ parser: HTMLParser, didEndElement name: String) {
        if ignoredDepth > 0 {
            ignoredDepth -= 1
            return
        }
        if ["p", "div", "li"].contains(name) {
            separateBlock()
        }
    }

    func parser(_ parser: HTMLParser, foundCharacters string: String) {
        if ignoredDepth == 0 { text += string }
    }

    func parserFoundProcessingInstruction(_ parser: HTMLParser,
                                         target: String, data: String?) {}

    func parser(_ parser: HTMLParser, parseErrorOccurred error: ParseError) {
        errors.append(error)
    }
}

let collector = PlainTextCollector()
let parser = HTMLParser(
    data: Data("<p>Hello <strong>world</strong>.</p><p>Next.</p>".utf8),
    encoding: .utf8
)
parser.delegate = collector
let succeeded = parser.parse()
let text = collector.text.trimmingCharacters(in: .whitespacesAndNewlines)
```

The collector preserves source whitespace inside blocks and does not number lists. Add normalization and list state only if your input needs them. libxml2 may repair markup and insert wrapper elements; build your policy against the resulting events rather than assuming every element appeared literally in the source.

## Build Core Text attributes directly

For a renderer that already uses Core Text, constructing the required attributes during parsing avoids building and then translating a Swift `AttributedString`. The example below handles inherited bold text and paragraph boundaries. It uses Core Foundation attributed-string storage bridged to `NSMutableAttributedString`, and reuses the fonts within the document.

```swift
import CoreText
import Foundation
import SimpleHTML

final class CoreTextBuilder: HTMLParserDelegate {
    let text = CFAttributedStringCreateMutable(nil, 0)! as NSMutableAttributedString
    var errors: [ParseError] = []
    private var boldStack: [Bool] = []
    private let bodyFont: CTFont
    private let boldFont: CTFont

    init(font: CTFont) {
        bodyFont = font
        boldFont = CTFontCreateCopyWithSymbolicTraits(
            font, 0, nil, .traitBold, .traitBold
        ) ?? font
    }

    private func separateParagraph() {
        if text.length > 0 && !text.string.hasSuffix("\n") {
            append("\n")
        }
    }

    private func append(_ string: String) {
        let font = boldStack.last == true ? boldFont : bodyFont
        text.append(NSAttributedString(string: string, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font
        ]))
    }

    func parser(_ parser: HTMLParser, didStartElement name: String,
                attributes: [AnyHashable: Any]) {
        boldStack.append(boldStack.last == true || name == "strong" || name == "b")
        if name == "p" { separateParagraph() }
        if name == "br" { append("\n") }
    }

    func parser(_ parser: HTMLParser, didEndElement name: String) {
        if name == "p" { separateParagraph() }
        boldStack.removeLast()
    }

    func parser(_ parser: HTMLParser, foundCharacters string: String) {
        append(string)
    }

    func parserFoundProcessingInstruction(_ parser: HTMLParser,
                                         target: String, data: String?) {}

    func parser(_ parser: HTMLParser, parseErrorOccurred error: ParseError) {
        errors.append(error)
    }
}

let font = CTFontCreateWithName("Helvetica" as CFString, 18, nil)
let builder = CoreTextBuilder(font: font)
let parser = HTMLParser(
    data: Data("<p>Hello <strong>world</strong>.</p>".utf8),
    encoding: .utf8
)
parser.delegate = builder
let succeeded = parser.parse()
let framesetter = CTFramesetterCreateWithAttributedString(builder.text as CFAttributedString)
```

This is deliberately a small tag policy. A fuller renderer can maintain an inherited element context for italic text, colors, superscripts, links, or known CSS classes; flush separate paragraph buffers at block boundaries; and attach `CTParagraphStyle` attributes for alignment and indentation. Reuse derived fonts within a build instead of creating a font for every character callback.

Direct construction removes conversion work, but performance depends on the output attributes and document. Measure with your own HTML and renderer. The ``HTMLAttributedStringBuilder`` path remains useful when you want presentation intents, element metadata, or SwiftUI rendering.
