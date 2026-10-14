# ``SimpleHTML``

Parse HTML into attributed strings and render paragraphs and lists in SwiftUI.

## Overview

SimpleHTML separates HTML parsing, attributed-string construction, and view rendering. Use the highest layer that fits your app, and move down a layer when you need more control.

| Layer | Use it for |
| --- | --- |
| ``HTMLView`` | Parsing HTML and displaying it in a SwiftUI view |
| ``BlockTextView`` | Displaying any presentation-intent attributed string, including Markdown |
| ``HTMLAttributedStringBuilder`` | Creating attributed strings and inspecting HTML metadata without rendering a view |
| ``HTMLParser`` | Handling HTML events yourself to build plain text, Core Text attributes, or another representation |

```swift
import SimpleHTML
import SwiftUI

HTMLView(html: "<p>Hello <strong>world</strong>.</p><ul><li>A list item</li></ul>")
```

![HTML rendered as a paragraph and a bulleted list.](documentation.overview.png)

The default builder translates selected tags into semantic attributes rather than reproducing browser styling. It preserves element attributes and ancestry so your app can interpret the CSS classes and media it expects. There is no CSS engine, JavaScript execution, or network media loading.

The parser uses the system's libxml2 and was originally based on [DTCoreText](https://github.com/Cocoanetics/DTCoreText) and its DTFoundation parser.

## Topics

### Rendering text

- ``HTMLView``
- ``BlockTextView``
- <doc:EmbeddedMedia>

### Building attributed strings

- ``HTMLAttributedStringBuilder``
- ``Foundation/AttributedString/init(html:preserveWhitespace:)``
- <doc:CustomizingHTML>

### Inspecting HTML metadata

- ``HTMLElement``
- ``HTMLElementAttribute``
- ``HTMLRawTextAttribute``
- ``Foundation/AttributeScopes/HTMLAttributes``
- ``Foundation/AttributeScopes/html``

### Handling parser events

- ``HTMLParser``
- ``HTMLParserDelegate``
- ``ParseError``
- <doc:CustomParsing>
