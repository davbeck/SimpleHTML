public import SwiftUI

/// Displays attributed text as blocks, including paragraphs and nested lists.
///
/// ## Overview
///
/// `BlockTextView` lays out attributed text using Foundation's block presentation intents. Its input can come from HTML, Markdown, or your own attributed-string construction.
///
/// ```swift
/// import SimpleHTML
/// import SwiftUI
///
/// let text = try AttributedString(markdown: """
///     A paragraph with **bold** and *italic* text.
///
///     1. First item
///
///        A continuation paragraph.
///
///        - A nested bullet
///     2. Second item
///     """)
///
/// BlockTextView(attributedString: text)
///     .font(.body)
///     .multilineTextAlignment(.leading)
/// ```
///
/// ![Markdown with bold and italic text, a continuation paragraph, and a nested bullet.](documentation.block-text-view.png)
///
/// Use Foundation's full Markdown parsing, which is the default, to retain block presentation intents. Inline-only parsing does not supply the paragraph and list structure this view uses.
///
/// ### Block layout
///
/// The view groups consecutive presentation-intent runs by their root block. Paragraphs receive space between blocks, while content inside the same list uses closer spacing. List nesting controls indentation; only the first paragraph of a list item receives a marker, so continuation paragraphs remain aligned with the item.
///
/// Ordered lists use numeric markers at the first nesting level, lowercase letters at the second, and lowercase Roman numerals at deeper levels. Unordered lists use filled circles, outlined circles, and squares. Spacing and indentation use scaled metrics relative to the body font.
///
/// SwiftUI `Text` renders each text run, including its supported inline emphasis and link attributes. Normal modifiers such as `.font`, `.foregroundColor`, `.tint`, and `.lineSpacing` apply to the view. `.multilineTextAlignment(.center)` and `.multilineTextAlignment(.trailing)` align both the paragraph text and the block containers.
///
/// ### Scope
///
/// The view accepts other presentation intents, but it does not provide specialized layouts for headings, block quotes, code blocks, or tables. It also does not load images or render iframes. For those cases, inspect the attributed string and provide your own layout.
///
/// A string without block intents is displayed as ordinary text. Paragraph boundaries stored as intents are not automatically converted into newline characters. See <doc:CustomizingHTML> for explicit plain-text conversion.
public struct BlockTextView: View {
	@Environment(\.multilineTextAlignment) private var textAlignment
	@ScaledMetric(relativeTo: .body) private var spacing: CGFloat = 10

	/// The attributed text whose presentation intents define the block layout.
	public var attributedString: AttributedString

	/// Creates a block renderer for HTML, Markdown, or custom attributed text.
	///
	/// - Parameter attributedString: Text with Foundation block presentation intents.
	public init(attributedString: AttributedString) {
		self.attributedString = attributedString
	}

	/// Group consecutive presentation-intent runs by their root block.
	var blocks: [[AttributedSubstring]] {
		var result: [[AttributedSubstring]] = []
		var previousRoot: PresentationIntent.IntentType?
		for (intent, range) in attributedString.runs[\.presentationIntent] {
			let root = intent?.components.last
			if result.isEmpty || root != previousRoot {
				result.append([])
			}
			result[result.count - 1].append(attributedString[range])
			previousRoot = root
		}
		return result
	}

	/// Markdown list items can contain several paragraphs or a nested list.
	/// Only the first paragraph of each item receives its marker.
	func showsListMarker(in block: [AttributedSubstring], at index: Int) -> Bool {
		guard let item = block[index].presentationIntent?.listItem else { return false }
		return !block[..<index].contains { $0.presentationIntent?.listItem == item }
	}

	private var horizontalAlignment: HorizontalAlignment {
		switch textAlignment {
		case .leading: .leading
		case .center: .center
		case .trailing: .trailing
		}
	}

	public var body: some View {
		VStack(alignment: horizontalAlignment, spacing: spacing) {
			// Positions distinguish repeated, identical paragraphs and list items.
			ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
				VStack(alignment: horizontalAlignment, spacing: spacing / 8) {
					ForEach(Array(block.enumerated()), id: \.offset) { index, string in
						BlockTextLine(string: string, showsListMarker: showsListMarker(in: block, at: index))
					}
				}
			}
		}
		.lineLimit(nil)
		.frame(maxWidth: .infinity, alignment: Alignment(horizontal: horizontalAlignment, vertical: .center))
		.fixedSize(horizontal: false, vertical: true)
	}
}
