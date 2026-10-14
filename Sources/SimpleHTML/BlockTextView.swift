public import SwiftUI

/// Displays attributed text as blocks, including paragraphs and nested lists.
///
/// Accepts strings parsed from HTML or Foundation's full Markdown parser.
/// SwiftUI's `Text` handles inline attributes such as emphasis and links.
public struct BlockTextView: View {
	@ScaledMetric(relativeTo: .body) private var spacing: CGFloat = 10

	public var attributedString: AttributedString

	public init(attributedString: AttributedString) {
		self.attributedString = attributedString
	}

	// Group consecutive presentation-intent runs by their root block.
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

	// Markdown list items can contain several paragraphs or a nested list.
	// Only the first paragraph of each item receives its marker.
	func showsListMarker(in block: [AttributedSubstring], at index: Int) -> Bool {
		guard let item = block[index].presentationIntent?.listItem else { return false }
		return !block[..<index].contains { $0.presentationIntent?.listItem == item }
	}

	public var body: some View {
		VStack(alignment: .leading, spacing: spacing) {
			// Positions distinguish repeated, identical paragraphs and list items.
			ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
				VStack(alignment: .leading, spacing: spacing / 8) {
					ForEach(Array(block.enumerated()), id: \.offset) { index, string in
						BlockTextLine(string: string, showsListMarker: showsListMarker(in: block, at: index))
					}
				}
			}
		}
		.lineLimit(nil)
		.frame(maxWidth: .infinity, alignment: .leading)
		.fixedSize(horizontal: false, vertical: true)
	}
}
