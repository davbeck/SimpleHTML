import CustomDump
import Foundation
@testable import SimpleHTML
import SwiftUI
import Testing

@MainActor
struct BlockTextViewTests {
	@Test func markdownParagraphs() throws {
		let string = try AttributedString(markdown: "First paragraph.\n\nSecond paragraph.")
		let view = BlockTextView(attributedString: string)
		expectNoDifference(text(in: view), [["First paragraph."], ["Second paragraph."]])
	}

	@Test func htmlParagraphs() {
		let view = BlockTextView(attributedString: AttributedString(html: "<p>First</p><p>Second</p>"))
		expectNoDifference(text(in: view), [["First"], ["Second"]])
	}

	@Test func markdownListsAndNestedLists() throws {
		let string = try AttributedString(markdown: """
		Before

		1. First
		   1. Nested
		   2. Another nested item
		2. Second

		- Bullet
		- Another bullet

		After
		""")
		let view = BlockTextView(attributedString: string)
		expectNoDifference(text(in: view), [
			["Before"],
			["First", "Nested", "Another nested item", "Second"],
			["Bullet", "Another bullet"],
			["After"],
		])
		let intents = try view.blocks[1].map { try #require($0.presentationIntent) }
		expectNoDifference(intents.map(\.indentationLevel), [1, 2, 2, 1])
		expectNoDifference(intents.map(\.ordinal), [1, 1, 2, 2])
		expectNoDifference(intents.map { $0.list?.kind }, Array(repeating: .orderedList, count: 4))
		let bullet = try #require(view.blocks[2][0].presentationIntent)
		expectNoDifference(bullet.list?.kind, .unorderedList)
	}

	@Test func markdownInlineAttributesSurviveSplitting() throws {
		let string = try AttributedString(markdown: "**Bold** and *italic* with [a link](https://example.com).\n\nNext")
		let view = BlockTextView(attributedString: string)
		let paragraph = try #require(view.blocks.first?.first)
		expectNoDifference(AttributedString(paragraph), AttributedString(string[string.startIndex..<paragraph.endIndex]))
		#expect(paragraph.runs.contains { $0.inlinePresentationIntent == .stronglyEmphasized })
		#expect(paragraph.runs.contains { $0.inlinePresentationIntent == .emphasized })
		#expect(paragraph.runs.contains { $0.link == URL(string: "https://example.com") })
	}

	@Test func markdownListContinuationParagraphs() throws {
		let view = BlockTextView(attributedString: try AttributedString(markdown: """
		1. First paragraph

		   Continuation paragraph

		   - Nested bullet

		   After the nested list

		2. Second item
		"""))
		expectNoDifference(text(in: view), [[
			"First paragraph", "Continuation paragraph", "Nested bullet",
			"After the nested list", "Second item",
		]])
		let block = try #require(view.blocks.first)
		expectNoDifference(block.indices.map { view.showsListMarker(in: block, at: $0) }, [true, false, true, false, true])
	}

	@Test func plainTextAndEmptyText() {
		expectNoDifference(text(in: BlockTextView(attributedString: AttributedString("Plain\ntext"))), [["Plain\ntext"]])
		expectNoDifference(text(in: BlockTextView(attributedString: AttributedString())), [])
	}

	@Test func repeatedMarkdownParagraphsRemainSeparate() throws {
		let view = BlockTextView(attributedString: try AttributedString(markdown: "Repeat\n\nRepeat"))
		expectNoDifference(text(in: view), [["Repeat"], ["Repeat"]])
	}

	@Test func htmlViewDefaultAndCustomContent() {
		let html = "<p>Hello <strong>world</strong></p>"
		let defaultView: HTMLView<BlockTextView> = HTMLView(html: html)
		expectNoDifference(text(in: defaultView.content(AttributedString(html: defaultView.html))), [["Hello world"]])
		var received: AttributedString?
		let customView = HTMLView(html: html) { string in
			received = string
			return Text(string)
		}
		_ = customView.body
		expectNoDifference(received.map { String($0.characters) }, "Hello world")
		#expect(received?.runs.contains { $0.inlinePresentationIntent == .stronglyEmphasized } == true)
	}

	@Test func nestedOrderedListNumerals() {
		expectNoDifference(String(alphaNumerals: 1), "a")
		expectNoDifference(String(alphaNumerals: 26), "z")
		expectNoDifference(String(alphaNumerals: 27), "aa")
		expectNoDifference(String(romanNumerals: 4).lowercased(), "iv")
	}

	private func text(in view: BlockTextView) -> [[String]] {
		view.blocks.map { $0.map { String($0.characters) } }
	}
}
