public import SwiftUI

/// Parses HTML and displays its paragraphs and lists using ``BlockTextView``.
public struct HTMLView<Content: View>: View {
	public var html: String
	public var content: (AttributedString) -> Content

	public init(html: String) where Content == BlockTextView {
		self.init(html: html) { BlockTextView(attributedString: $0) }
	}

	/// Supplies parsed HTML to a custom view, preserving its attributes.
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
