# SimpleHTML

Parse HTML into Foundation attributed strings and display paragraphs and nested
lists in SwiftUI.

```swift
import SimpleHTML

HTMLView(html: "<p>Hello <strong>world</strong>.</p><ul><li>A list item</li></ul>")
```

`HTMLView` also accepts a view builder for displaying the parsed string yourself:

```swift
HTMLView(html: html) { attributedString in
    Text(attributedString)
}
```

Use `BlockTextView` directly with an attributed string from either HTML or Markdown:

```swift
let markdown = try AttributedString(markdown: "First paragraph.\n\n1. First item\n2. Second item")
BlockTextView(attributedString: markdown)
```

Use Foundation's full Markdown parsing (the default) to retain block presentation
intents. `BlockTextView` separates root blocks, indents nested lists, and uses
numbered or bulleted markers. Inline formatting and links are rendered by SwiftUI
`Text`. It does not provide specialized layouts for Markdown tables, headings,
block quotes, or code blocks.

## Snapshot tests

`BlockTextViewSnapshotTests` records separate macOS and iOS images for both HTML
and Markdown. One light/dark pair covers appearance; the remaining cases run in
light mode. It covers small, large, XXXL, and
accessibility Dynamic Type sizes; top-level font, bold/italic, monospaced font,
foreground color/tint/line spacing, and multiline alignment; and a narrow layout.
Fixtures include wrapped text, links, three levels of ordered and unordered lists,
continuation paragraphs, and repeated content.

Run the macOS tests with `swift test`. The iOS references were recorded on an
iPhone 17 simulator running iOS 26.5 at a fixed 2× display scale:

```sh
xcodebuild -scheme SimpleHTML \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' test
```

The macOS references were recorded on macOS 27.0.1. Use the same OS versions when
comparing images: platform font rendering can change between releases. Dynamic
Type sizes affect the iOS references; macOS currently keeps the same text size.

To intentionally update baselines, temporarily apply
`@Suite(.snapshots(record: .all))` to `BlockTextViewSnapshotTests`, run the tests
on both platforms, inspect the generated PNGs in `__Snapshots__`, and restore
the suite's `.never` recording policy before committing.
