import SimpleHTML
import SnapshotTesting
import SwiftUI
import Testing
#if os(macOS)
	import AppKit
#elseif os(iOS)
	import UIKit
#endif

@Suite(.snapshots(record: .never))
@MainActor
struct BlockTextViewSnapshotTests {
	enum Source: String, CaseIterable {
		case html, markdown

		@MainActor @ViewBuilder var view: some View {
			switch self {
			case .html:
				HTMLView(html: Self.htmlFixture)
			case .markdown:
				BlockTextView(attributedString: try! AttributedString(markdown: Self.markdownFixture))
			}
		}

		/// Equivalent content exercises wrapping, inline styles, three nesting levels,
		/// continuation paragraphs, and repeated paragraphs/items.
		private static let htmlFixture = """
		<p>A paragraph with <strong>bold</strong>, <em>italic</em>, and a <a href="https://example.com">link</a> that wraps onto another line.</p>
		<ol><li><p>First ordered item</p><p>Continuation of the same item.</p><ol><li>Nested ordered item<ol><li>Third level</li></ol></li></ol></li><li>Second ordered item</li></ol>
		<ul><li>A bullet<ul><li>A nested bullet<ul><li>Third level bullet</li></ul></li></ul></li><li>Repeated item</li><li>Repeated item</li></ul>
		<p>Repeated paragraph.</p><p>Repeated paragraph.</p>
		"""

		private static let markdownFixture = """
		A paragraph with **bold**, *italic*, and a [link](https://example.com) that wraps onto another line.

		1. First ordered item

		   Continuation of the same item.

		   1. Nested ordered item
		      1. Third level
		2. Second ordered item

		- A bullet
		  - A nested bullet
		    - Third level bullet
		- Repeated item
		- Repeated item

		Repeated paragraph.

		Repeated paragraph.
		"""
	}

	enum Appearance: String, CaseIterable {
		case light, dark

		var colorScheme: ColorScheme {
			self == .light ? .light : .dark
		}
	}

	enum TextSize: String, CaseIterable {
		case small, large, xxxLarge, accessibility3

		var dynamicTypeSize: DynamicTypeSize {
			switch self {
			case .small: .small
			case .large: .large
			case .xxxLarge: .xxxLarge
			case .accessibility3: .accessibility3
			}
		}
	}

	enum Styling: String, CaseIterable {
		case title, boldItalic, monospaced, coloredAndSpaced, centered, trailing

		@ViewBuilder func apply(to view: some View) -> some View {
			switch self {
			case .title:
				view.font(.title)
			case .boldItalic:
				view.bold().italic()
			case .monospaced:
				view.font(.system(.body, design: .monospaced))
			case .coloredAndSpaced:
				view.foregroundColor(.purple).tint(.orange).lineSpacing(6)
			case .centered:
				view.multilineTextAlignment(.center)
			case .trailing:
				view.multilineTextAlignment(.trailing)
			}
		}
	}

	@Test(arguments: Appearance.allCases)
	func appearance(appearance: Appearance) {
		snapshot(
			Source.html.view,
			appearance: appearance,
			name: appearance.rawValue,
			testName: "appearance",
		)
	}

	@Test(arguments: Source.allCases, TextSize.allCases)
	func dynamicType(source: Source, textSize: TextSize) {
		snapshot(
			source.view,
			textSize: textSize,
			name: "\(source.rawValue)-\(textSize.rawValue)",
			testName: "dynamicType",
		)
	}

	@Test(arguments: Source.allCases, Styling.allCases)
	func topLevelTextModifiers(source: Source, styling: Styling) {
		snapshot(
			styling.apply(to: source.view),
			name: "\(source.rawValue)-\(styling.rawValue)",
			testName: "topLevelTextModifiers",
		)
	}

	@Test(arguments: Source.allCases)
	func narrowLayout(source: Source) {
		snapshot(
			source.view,
			width: 220,
			name: source.rawValue,
			testName: "narrowLayout",
		)
	}

	private func snapshot(
		_ content: some View,
		appearance: Appearance = .light,
		textSize: TextSize = .large,
		width: CGFloat = 360,
		name: String,
		testName: String,
		file: StaticString = #filePath,
		line: UInt = #line,
	) {
		let view = content
			.padding(16)
			.frame(width: width)
			.fixedSize(horizontal: false, vertical: true)
			.background(appearance == .light ? Color.white : Color.black)
			.environment(\.colorScheme, appearance.colorScheme)
			.environment(\.dynamicTypeSize, textSize.dynamicTypeSize)
			.environment(\.locale, Locale(identifier: "en_US"))

		#if os(macOS)
			let hostingView = NSHostingView(rootView: view)
			hostingView.appearance = NSAppearance(named: appearance == .light ? .aqua : .darkAqua)
			hostingView.frame.size = hostingView.fittingSize
			hostingView.layoutSubtreeIfNeeded()
			assertSnapshot(
				of: hostingView, as: .image, named: "macOS-\(name)",
				file: file, testName: testName, line: line,
			)
		#elseif os(iOS)
			assertSnapshot(
				of: view, as: .image(layout: .sizeThatFits, traits: UITraitCollection(displayScale: 2)),
				named: "iOS-\(name)", file: file, testName: testName, line: line,
			)
		#endif
	}
}
