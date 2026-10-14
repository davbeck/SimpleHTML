public import SwiftUI

/// Parses HTML and displays its paragraphs and lists using ``BlockTextView``.
///
/// ## Overview
///
/// Use `HTMLView` to parse an HTML string and display paragraphs, lists, and inline formatting with ``BlockTextView``.
///
/// ```swift
/// import SimpleHTML
/// import SwiftUI
///
/// HTMLView(html: """
///     <p>A <strong>bold</strong> idea with a <a href="https://example.com">link</a>.</p>
///     <ol><li>Start here</li><li>Keep going</li></ol>
///     """)
///     .font(.body)
///     .tint(.orange)
///     .lineSpacing(4)
/// ```
///
/// ![A paragraph with bold text and an orange link above a numbered list.](documentation.html-view.png)
///
/// The view inherits SwiftUI text styling. The built-in layout supports multiline alignment, paragraphs, nested lists, and continuation paragraphs. See ``BlockTextView`` for layout details.
///
/// ### Supply a custom view
///
/// The content initializer supplies the parsed attributed string to your own view builder. This is useful for post-processing the string or using another renderer.
///
/// ```swift
/// HTMLView(html: "<p>A short <em>caption</em>.</p>") { text in
///     Text(text)
///         .font(.caption)
/// }
/// ```
///
/// SwiftUI `Text` renders inline formatting but does not lay out block presentation intents. Use ``BlockTextView`` inside the closure when you want paragraph and list layout too.
///
/// ### Parsing and lifetime
///
/// Parsing happens synchronously when SwiftUI evaluates the view's body. The view does not cache parsed output. For repeated content or expensive post-processing, parse once in your app's model and pass the result to ``BlockTextView``.
///
/// This convenience view uses default whitespace normalization and does not expose parser diagnostics. Use ``HTMLAttributedStringBuilder`` directly when you need preserved whitespace or ``HTMLAttributedStringBuilder/parseErrors``.
///
/// Images and embedded media retain metadata in the string, but the default view does not load them. See <doc:EmbeddedMedia> for images and YouTube players, or <doc:CustomizingHTML> for inline custom emoji.
public struct HTMLView<Content: View>: View {
	/// The HTML source parsed when the view body is evaluated.
	public var html: String
	/// Creates the view that displays the parsed attributed string.
	public var content: (AttributedString) -> Content

	/// Creates a view using the default paragraph and list renderer.
	/// - Parameter html: The HTML source to parse.
	public init(html: String) where Content == BlockTextView {
		self.init(html: html) { BlockTextView(attributedString: $0) }
	}

	/// Supplies parsed HTML to a custom view, preserving its attributes.
	/// - Parameters:
	///   - html: The HTML source to parse.
	///   - content: A view builder receiving the parsed string. Use ``BlockTextView`` to retain block layout.
	public init(
		html: String,
		@ViewBuilder content: @escaping (AttributedString) -> Content
	) {
		self.html = html
		self.content = content
	}

	public var body: some View {
		content(AttributedString(html: html))
	}
}
