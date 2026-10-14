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
