@testable import SimpleHTML
#if canImport(AppKit)
	import AppKit
#elseif canImport(UIKit)
	import UIKit
#endif
import XCTest

extension AttributedString {
	var string: String {
		String(characters)
	}
}

extension AttributedSubstring {
	var string: String {
		String(characters)
	}
}

extension AttributeContainer {
	var platformUnderlineStyle: NSUnderlineStyle? {
		#if canImport(AppKit)
			self[AttributeScopes.AppKitAttributes.UnderlineStyleAttribute.self]
		#elseif canImport(UIKit)
			self[AttributeScopes.UIKitAttributes.UnderlineStyleAttribute.self]
		#endif
	}
}

struct TestRequireFailure: Swift.Error {
	var message: String
}

func XCTRequireEqual<T: Equatable>(
	_ expression1: T,
	_ expression2: T,
	_ message: @autoclosure () -> String = "",
	file: StaticString = #filePath,
	line: UInt = #line
) throws {
	if expression1 != expression2 {
		let m = message()
		throw TestRequireFailure(
			message: m.isEmpty ? "\(expression1) != \(expression2)" : m)
	}
}

class HTMLAttributedStringBuilderTests: XCTestCase {
	func testBasicString() throws {
		let builder = HTMLAttributedStringBuilder(html: "Hello World!")
		let string = builder.generatedAttributedString()

		XCTAssertEqual(string.string, "Hello World!")
	}

	func testStrongText() throws {
		let builder = HTMLAttributedStringBuilder(
			html: "Hello <strong>World</strong>!"
		)
		let string = builder.generatedAttributedString()

		let runs = Array(string.runs)
		try XCTRequireEqual(runs.count, 3)

		XCTAssertEqual(string[runs[0].range].string, "Hello ")
		XCTAssertEqual(runs[0].attributes.inlinePresentationIntent, nil)

		XCTAssertEqual(string[runs[1].range].string, "World")
		XCTAssertEqual(
			runs[1].attributes.inlinePresentationIntent,
			.stronglyEmphasized
		)

		XCTAssertEqual(string[runs[2].range].string, "!")
		XCTAssertEqual(runs[2].attributes.inlinePresentationIntent, nil)
	}

	func testBText() throws {
		let builder = HTMLAttributedStringBuilder(
			html: "Hello <b>World</b>!"
		)
		let string = builder.generatedAttributedString()

		let runs = Array(string.runs)
		try XCTRequireEqual(runs.count, 3)

		XCTAssertEqual(string[runs[0].range].string, "Hello ")
		XCTAssertEqual(runs[0].attributes.inlinePresentationIntent, nil)

		XCTAssertEqual(string[runs[1].range].string, "World")
		XCTAssertEqual(
			runs[1].attributes.inlinePresentationIntent,
			.stronglyEmphasized
		)

		XCTAssertEqual(string[runs[2].range].string, "!")
		XCTAssertEqual(runs[2].attributes.inlinePresentationIntent, nil)
	}

	func testEmText() throws {
		let builder = HTMLAttributedStringBuilder(
			html: "Hello <em>World</em>!"
		)
		let string = builder.generatedAttributedString()

		let runs = Array(string.runs)
		try XCTRequireEqual(runs.count, 3)

		XCTAssertEqual(string[runs[0].range].string, "Hello ")
		XCTAssertEqual(runs[0].attributes.inlinePresentationIntent, nil)

		XCTAssertEqual(string[runs[1].range].string, "World")
		XCTAssertEqual(
			runs[1].attributes.inlinePresentationIntent,
			.emphasized
		)

		XCTAssertEqual(string[runs[2].range].string, "!")
		XCTAssertEqual(runs[2].attributes.inlinePresentationIntent, nil)
	}

	func testIText() throws {
		let builder = HTMLAttributedStringBuilder(
			html: "Hello <i>World</i>!"
		)
		let string = builder.generatedAttributedString()

		let runs = Array(string.runs)
		try XCTRequireEqual(runs.count, 3)

		XCTAssertEqual(string[runs[0].range].string, "Hello ")
		XCTAssertEqual(runs[0].attributes.inlinePresentationIntent, nil)

		XCTAssertEqual(string[runs[1].range].string, "World")
		XCTAssertEqual(
			runs[1].attributes.inlinePresentationIntent,
			.emphasized
		)

		XCTAssertEqual(string[runs[2].range].string, "!")
		XCTAssertEqual(runs[2].attributes.inlinePresentationIntent, nil)
	}

	func testUnderlinedText() throws {
		let builder = HTMLAttributedStringBuilder(
			html: "Hello <u>World</u>!"
		)
		let string = builder.generatedAttributedString()

		let runs = Array(string.runs)
		try XCTRequireEqual(runs.count, 3)

		XCTAssertEqual(string[runs[0].range].string, "Hello ")
		XCTAssertEqual(runs[0].attributes.platformUnderlineStyle, nil)

		XCTAssertEqual(string[runs[1].range].string, "World")
		XCTAssertEqual(runs[1].attributes.platformUnderlineStyle, .single)

		XCTAssertEqual(string[runs[2].range].string, "!")
		XCTAssertEqual(runs[2].attributes.platformUnderlineStyle, nil)
	}

	func testLinks() throws {
		let builder = HTMLAttributedStringBuilder(
			html: #"Hello <a href="https://www.acstechnologies.com/realm/">World</a>!"#
		)
		let string = builder.generatedAttributedString()

		let runs = Array(string.runs)
		try XCTRequireEqual(runs.count, 3)

		XCTAssertEqual(string[runs[0].range].string, "Hello ")
		XCTAssertEqual(runs[0].attributes.link, nil)

		XCTAssertEqual(string[runs[1].range].string, "World")
		XCTAssertEqual(
			runs[1].attributes.link,
			try XCTUnwrap(URL(string: "https://www.acstechnologies.com/realm/"))
		)

		XCTAssertEqual(string[runs[2].range].string, "!")
		XCTAssertEqual(runs[2].attributes.link, nil)
	}

	func testOverlapingAttributes() throws {
		let builder = HTMLAttributedStringBuilder(
			html: "Hello <strong><em>World</em></strong>!"
		)
		let string = builder.generatedAttributedString()

		let runs = Array(string.runs)
		try XCTRequireEqual(runs.count, 3)

		XCTAssertEqual(string[runs[0].range].string, "Hello ")
		XCTAssertEqual(runs[0].attributes.inlinePresentationIntent, nil)

		XCTAssertEqual(string[runs[1].range].string, "World")
		XCTAssertEqual(
			runs[1].attributes.inlinePresentationIntent,
			[.emphasized, .stronglyEmphasized]
		)

		XCTAssertEqual(string[runs[2].range].string, "!")
		XCTAssertEqual(runs[2].attributes.inlinePresentationIntent, nil)
	}

	func testAndroidAttributes() throws {
		let builder = HTMLAttributedStringBuilder(html: """
		<p><u><b><i>BOLD UNDERLINE ITALIC</i></b></u><b>Bold</b><i>Italic</i><u>underline</u></p>
		""")
		let string = builder.generatedAttributedString()

		let runs = Array(string.runs)
		try XCTRequireEqual(runs.count, 4)

		do {
			let run = runs[0]
			XCTAssertEqual(string[run.range].string, "BOLD UNDERLINE ITALIC")
			XCTAssertEqual(run.attributes.inlinePresentationIntent, [.emphasized, .stronglyEmphasized])
			XCTAssertEqual(run.attributes.platformUnderlineStyle, .single)
		}

		do {
			let run = runs[1]
			XCTAssertEqual(string[run.range].string, "Bold")
			XCTAssertEqual(run.attributes.inlinePresentationIntent, [.stronglyEmphasized])
			XCTAssertEqual(run.attributes.platformUnderlineStyle, nil)
		}

		do {
			let run = runs[2]
			XCTAssertEqual(string[run.range].string, "Italic")
			XCTAssertEqual(run.attributes.inlinePresentationIntent, [.emphasized])
			XCTAssertEqual(run.attributes.platformUnderlineStyle, nil)
		}

		do {
			let run = runs[3]
			XCTAssertEqual(string[run.range].string, "underline")
			XCTAssertEqual(run.attributes.inlinePresentationIntent, nil)
			XCTAssertEqual(run.attributes.platformUnderlineStyle, .single)
		}
	}

	func testParagraphs() throws {
		let builder = HTMLAttributedStringBuilder(html: """
		<p>Hello</p><p>World</p>
		""")
		let string = builder.generatedAttributedString()

		let runs = Array(string.runs)
		try XCTRequireEqual(runs.count, 2)

		do {
			XCTAssertEqual(string[runs[0].range].string, "Hello")
			XCTAssertEqual(
				runs[0].attributes.presentationIntent,
				.init(
					.paragraph,
					identity: 1,
					parent: nil
				)
			)
		}

		do {
			XCTAssertEqual(string[runs[1].range].string, "World")
			XCTAssertEqual(
				runs[1].attributes.presentationIntent,
				.init(
					.paragraph,
					identity: 2,
					parent: nil
				)
			)
		}
	}

	func testUnorderedLists() throws {
		let builder = HTMLAttributedStringBuilder(html: """
		<ul>
			<li>a</li>
			<li>b</li>
			<li>c</li>
		</ul>
		""")
		let string = builder.generatedAttributedString()

		let runs = Array(string.runs)
		try XCTRequireEqual(runs.count, 3)

		do {
			XCTAssertEqual(string[runs[0].range].string, "a")

			let intent = try XCTUnwrap(runs[0].attributes.presentationIntent)
			XCTAssertEqual(intent.indentationLevel, 1)

			try XCTRequireEqual(intent.components.count, 2)
			XCTAssertEqual(intent.components[0].kind, .listItem(ordinal: 1))
			XCTAssertEqual(intent.components[1].kind, .unorderedList)
		}

		do {
			XCTAssertEqual(string[runs[1].range].string, "b")

			let intent = try XCTUnwrap(runs[1].attributes.presentationIntent)
			XCTAssertEqual(intent.indentationLevel, 1)

			try XCTRequireEqual(intent.components.count, 2)
			XCTAssertEqual(intent.components[0].kind, .listItem(ordinal: 2))
			XCTAssertEqual(intent.components[1].kind, .unorderedList)
		}

		do {
			XCTAssertEqual(string[runs[2].range].string, "c")

			let intent = try XCTUnwrap(runs[2].attributes.presentationIntent)
			XCTAssertEqual(intent.indentationLevel, 1)

			try XCTRequireEqual(intent.components.count, 2)
			XCTAssertEqual(intent.components[0].kind, .listItem(ordinal: 3))
			XCTAssertEqual(intent.components[1].kind, .unorderedList)
		}
	}

	func testOrderedLists() throws {
		let builder = HTMLAttributedStringBuilder(html: """
		<ol>
			<li>a</li>
			<li>b</li>
			<li>c</li>
		</ol>
		""")
		let string = builder.generatedAttributedString()

		let runs = Array(string.runs)
		try XCTRequireEqual(runs.count, 3)

		do {
			XCTAssertEqual(string[runs[0].range].string, "a")

			let intent = try XCTUnwrap(runs[0].attributes.presentationIntent)
			XCTAssertEqual(intent.indentationLevel, 1)

			try XCTRequireEqual(intent.components.count, 2)
			XCTAssertEqual(intent.components[0].kind, .listItem(ordinal: 1))
			XCTAssertEqual(intent.components[1].kind, .orderedList)
		}

		do {
			XCTAssertEqual(string[runs[1].range].string, "b")

			let intent = try XCTUnwrap(runs[1].attributes.presentationIntent)
			XCTAssertEqual(intent.indentationLevel, 1)

			try XCTRequireEqual(intent.components.count, 2)
			XCTAssertEqual(intent.components[0].kind, .listItem(ordinal: 2))
			XCTAssertEqual(intent.components[1].kind, .orderedList)
		}

		do {
			XCTAssertEqual(string[runs[2].range].string, "c")

			let intent = try XCTUnwrap(runs[2].attributes.presentationIntent)
			XCTAssertEqual(intent.indentationLevel, 1)

			try XCTRequireEqual(intent.components.count, 2)
			XCTAssertEqual(intent.components[0].kind, .listItem(ordinal: 3))
			XCTAssertEqual(intent.components[1].kind, .orderedList)
		}
	}

	func testImg() throws {
		let builder = HTMLAttributedStringBuilder(html: """
		<p><img src="https://realm-camo.imgix.net/dee05ecb8e00e0fedd3ff564a0d8adb5a1856faf/68747470733a2f2f63646e2e746f6c6c62726f74686572732e636f6d2f6d6f64656c732f73616c6964615f31313032365f2f656c65766174696f6e732f53414c445f53434c5f4e564e5f3346452d545f48475f53424141343231305f315f313830302e6a7067" width="1221" height="815" data-image="i9hwhc7qagxo"></p>
		""")
		let string = builder.generatedAttributedString()

		let runs = Array(string.runs)
		try XCTRequireEqual(runs.count, 1)

		do {
			let run = runs[0]

			XCTAssertEqual(string[run.range].string, String(.objectPlaceholder))
			try XCTAssertEqual(string[run.range].imageURL, XCTUnwrap(URL(string: "https://realm-camo.imgix.net/dee05ecb8e00e0fedd3ff564a0d8adb5a1856faf/68747470733a2f2f63646e2e746f6c6c62726f74686572732e636f6d2f6d6f64656c732f73616c6964615f31313032365f2f656c65766174696f6e732f53414c445f53434c5f4e564e5f3346452d545f48475f53424141343231305f315f313830302e6a7067")))
			XCTAssertEqual(string[run.range].html.element?.width, 1221)
			XCTAssertEqual(string[run.range].html.element?.height, 815)
		}
	}

	func testImgAlt() throws {
		let builder = HTMLAttributedStringBuilder(html: """
		<p><img src="https://s.gravatar.com/avatar/6b787e1e1ce6ec3d32d119c20cd7ef19?s=200" alt="David's Avatar"></p>
		""")
		let string = builder.generatedAttributedString()

		let runs = Array(string.runs)
		try XCTRequireEqual(runs.count, 1)

		do {
			let run = runs[0]

			XCTAssertEqual(string[run.range].string, "David's Avatar")
		}
	}

	func testYoutubeEmbed() throws {
		let builder = HTMLAttributedStringBuilder(html: """
		<p>Here's a Youtube video:</p><figure><iframe width="1920" height="1080" src="https://www.youtube.com/embed/RYlCVwxoL_g" frameborder="0" allowfullscreen=""></iframe></figure>
		""")
		let string = builder.generatedAttributedString()

		let runs = Array(string.runs)
		try XCTRequireEqual(runs.count, 2)

		do {
			let run = runs[1]

			XCTAssertEqual(string[run.range].string, String(.objectPlaceholder))
			try XCTAssertEqual(string[run.range].html.element?.src, XCTUnwrap(URL(string: "https://www.youtube.com/embed/RYlCVwxoL_g")))
			XCTAssertEqual(string[run.range].html.element?.width, 1920)
			XCTAssertEqual(string[run.range].html.element?.height, 1080)
		}
	}

	func testIgnoresWhitespace() throws {
		let builder = HTMLAttributedStringBuilder(html: """
		<p>Hello</p>


		<p>World</p>


		<p>!</p>
		""")
		let string = builder.generatedAttributedString()

		XCTAssertEqual(String(string.characters), """
		HelloWorld!
		""")
	}

	func testCondensesWhitespace() throws {
		let builder = HTMLAttributedStringBuilder(html: """
		<p>\t  Hello   \n\t  World \t \n\n  </p>
		""")
		let string = builder.generatedAttributedString()

		XCTAssertEqual(String(string.characters), """
		Hello World
		""")
	}

	func testTracksErrors() throws {
		let builder = HTMLAttributedStringBuilder(html: """
		<p>Hello <strong><em>World</strong></em>!</p>
		""")
		let string = builder.generatedAttributedString()

		XCTAssertEqual(String(string.characters), """
		Hello World!
		""")

		XCTAssertFalse(builder.parseErrors.isEmpty)
	}

	func testLineBreaks() throws {
		let builder = HTMLAttributedStringBuilder(html: """
		<p>How do I create a br?<br />is it like this?</p><p>Or maybe this is a p?</p>
		""")
		let string = builder.generatedAttributedString()

		XCTAssertEqual(String(string.characters), """
		How do I create a br?
		is it like this?Or maybe this is a p?
		""")
	}

	func testPreserveWhitespace() throws {
		let builder = HTMLAttributedStringBuilder(html: """
		<p>enum Delimiter {<br />  case curlyBrace<br />}</p>
		""", preserveWhitespace: true)
		let string = builder.generatedAttributedString()

		XCTAssertEqual(String(string.characters), """
		enum Delimiter {
		  case curlyBrace
		}
		""")
	}

	func testParsesElements() throws {
		let builder = HTMLAttributedStringBuilder(html: """
		<p>Links like <a href="https://daringfireball.net/linked/2022/12/12/foundation-swift" target="_blank" rel="nofollow noopener noreferrer"><span class="invisible">https://</span><span class="ellipsis">daringfireball.net/linked/2022</span><span class="invisible">/12/12/foundation-swift</span></a> should show a preview.</p>
		""", preserveWhitespace: true)
		let string = builder.generatedAttributedString()

		let runs = Array(string.runs)
		try XCTRequireEqual(runs.count, 5)

		do {
			let run = runs[0]
			XCTAssertEqual(string[run.range].string, "Links like ")
			XCTAssertEqual(run.attributes.html.element?.name, "p")
			XCTAssertEqual(run.attributes.html.element?.attributes, [:])
		}

		do {
			let run = runs[1]
			XCTAssertEqual(string[run.range].string, "https://")
			XCTAssertEqual(run.attributes.html.element?.name, "span")
			XCTAssertEqual(run.attributes.html.element?.attributes, ["class": "invisible"])
		}

		do {
			let run = runs[2]
			XCTAssertEqual(string[run.range].string, "daringfireball.net/linked/2022")
			XCTAssertEqual(run.attributes.html.element?.name, "span")
			XCTAssertEqual(run.attributes.html.element?.attributes, ["class": "ellipsis"])
		}

		do {
			let run = runs[3]
			XCTAssertEqual(string[run.range].string, "/12/12/foundation-swift")
			XCTAssertEqual(run.attributes.html.element?.name, "span")
			XCTAssertEqual(run.attributes.html.element?.attributes, ["class": "invisible"])
		}

		do {
			let run = runs[4]
			XCTAssertEqual(string[run.range].string, " should show a preview.")
			XCTAssertEqual(run.attributes.html.element?.name, "p")
			XCTAssertEqual(run.attributes.html.element?.attributes, [:])
			XCTAssertEqual(run.attributes.html.element, runs[0].attributes.html.element)
		}
	}
}
