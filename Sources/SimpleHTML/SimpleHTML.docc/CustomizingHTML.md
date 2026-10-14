# Customizing HTML

Use preserved element metadata to interpret the HTML your app expects.

## Overview

The default builder handles common text tags and preserves attributes from the source. This gives your app enough information to implement specific styling conventions without a general CSS engine. Use ``HTMLElement/classes`` to inspect the current element, or ``HTMLElement/has(class:)`` to check it and its ancestors.

## Recognize known CSS classes

A service might use `invisible` to hide part of a link and `ellipsis` to indicate a shortened display label. Preserve the original whitespace, then build a new string containing only the visible runs:

```swift
import Foundation
import SimpleHTML

func visibleText(html: String) -> AttributedString {
    let original = AttributedString(html: html, preserveWhitespace: true)
    var result = AttributedString()
    for run in original.runs {
        let element = run.html.element
        if element?.has(class: "invisible") == true {
            continue
        }
        result.append(original[run.range])
        if element?.has(class: "ellipsis") == true {
            result.append(AttributedString("…", attributes: run.attributes))
        }
    }
    return result
}

let text = visibleText(html: """
    <p>Visit <a href="https://example.com/articles/long-title"><span class="invisible">https://</span><span class="ellipsis">example.com/articles</span><span class="invisible">/long-title</span></a>.</p>
    """)
```

Render the result with `BlockTextView(attributedString: text)`:

![A shortened link label with an ellipsis.](documentation.visible-link.png)

The link target remains intact because the kept text retains its attributes. This policy adds an ellipsis to each matching run; if a service nests formatting inside an `ellipsis` element, group runs by that element's identity before appending a single ellipsis.

You can similarly map a known `warning` class to your app's foreground color, or inspect `element.attributes["style"]` for a specific declaration your source emits. Such mappings are app policies. They do not implement selector matching, the CSS cascade, inherited computed styles, or arbitrary stylesheets.

Build a new string when removing or replacing characters so ranges from the original stay valid. For attribute-only edits, take a snapshot of the runs before mutating.

## Export plain text

Discarding attributes alone loses paragraph separation because block boundaries are stored as presentation intents. Insert separators between consecutive intent ranges:

```swift
func plainText(from text: AttributedString, separator: String = "\n") -> String {
    text.runs[\.presentationIntent]
        .map { String(text[$0.1].characters) }
        .joined(separator: separator)
}

let text = AttributedString(html: "<p>Hello <strong>world</strong>.</p><p>Next paragraph.</p>")
let paragraphs = plainText(from: text)
let preview = plainText(from: text, separator: " ")
```

This simple policy produces one segment per consecutive presentation-intent range. It keeps literal `br` line breaks but does not generate list markers, indentation, or table structure. A richer export can inspect each intent's components and insert the markers your app wants.

## Recognize custom emoji and media

An `img` creates a run whose characters are the `alt` value, or U+FFFC if `alt` is empty. The run has `imageURL` plus element metadata such as `src`, `width`, `height`, and `class`. An `iframe` produces a placeholder and retains its source in the element metadata. The built-in views do not fetch or display either kind of media.

For full-size images and YouTube players displayed between text sections, see <doc:EmbeddedMedia>. The example below handles small images embedded inline in text.

To render graphical emoji inline, supply images that your app has already loaded from the source URLs. This single-paragraph example uses SwiftUI `Text` interpolation to preserve surrounding inline formatting and insert the image:

```swift
import SwiftUI

func emojiText(html: String, images: [URL: Image]) -> Text {
    let original = AttributedString(html: html)
    var result = Text("")
    for run in original.runs {
        if let element = run.html.element,
           element.name == "img",
           element.has(class: "emoji"),
           let url = run.imageURL,
           let image = images[url] {
            result = Text("\(result)\(Text(image).baselineOffset(-3))")
        } else {
            result = Text("\(result)\(Text(AttributedString(original[run.range])))")
        }
    }
    return result
}

let emojiURL = URL(string: "https://cdn.masto.host/tnkuco/custom_emojis/images/000/000/604/original/9a2294c91c6c88ed.png")!
let html = """
    <p>Nice work <img class="emoji" src="https://cdn.masto.host/tnkuco/custom_emojis/images/000/000/604/original/9a2294c91c6c88ed.png" alt=":swift:" width="20" height="20"></p>
    """
```

On macOS, download the [Swift emoji image](https://cdn.masto.host/tnkuco/custom_emojis/images/000/000/604/original/9a2294c91c6c88ed.png) and add it to your app's image assets as `swift-emoji`. Size the cached image before embedding it in `Text`:

```swift
import AppKit

let asset = NSImage(named: "swift-emoji")!.copy() as! NSImage
asset.size = NSSize(width: 20, height: 20)
emojiText(html: html, images: [emojiURL: Image(nsImage: asset)])
```

![A Swift logo custom emoji rendered inline after Nice work.](documentation.custom-emoji.png)

The example uses a 20-point image with a small baseline adjustment. For other fonts or Dynamic Type sizes, scale your cached images relative to the surrounding font. On iOS, supply an `Image` backed by a suitably sized `UIImage` instead. Your app owns image fetching and caching; the snapshot uses a bundled copy of the same image.

Missing images retain their alt text as a loading fallback. This renderer handles inline content in one paragraph; use your own block layout for multiple paragraphs or lists. Preserve the emoji's alt text in your app's accessibility description. For a text-only representation, copy the image run's attributes, clear `imageURL`, and append its alt text to an attributed string.

If changing attributes after parsing becomes expensive, or you need to suppress whole subtrees before any text is built, move the policy into your own ``HTMLParserDelegate``. See <doc:CustomParsing>.
