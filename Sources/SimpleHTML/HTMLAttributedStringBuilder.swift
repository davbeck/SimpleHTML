public import Foundation
#if canImport(AppKit)
	import AppKit
#elseif canImport(UIKit)
	import UIKit
#endif

public extension AttributedString {
	/// Parses HTML using the default tag mapping.
	///
	/// Block boundaries are stored as presentation intents, not newline characters. Use
	/// ``HTMLAttributedStringBuilder`` directly to inspect parsing diagnostics.
	/// - Parameters:
	///   - html: The HTML source to parse.
	///   - preserveWhitespace: Whether to skip the builder's final whitespace normalization.
	init(html: String, preserveWhitespace: Bool = false) {
		let builder = HTMLAttributedStringBuilder(
			html: html,
			preserveWhitespace: preserveWhitespace,
		)
		self = builder.generatedAttributedString()
	}
}

/// Marks generated text that the builder must exclude from whitespace normalization.
///
/// The builder sets this attribute on newlines generated for `br` elements.
public enum HTMLRawTextAttribute: AttributedStringKey, CodableAttributedStringKey {
	public typealias Value = Bool
	public static let name = "rawText"
}

/// Associates an attributed-string run with its innermost HTML element and ancestry.
public enum HTMLElementAttribute: AttributedStringKey, CodableAttributedStringKey {
	public typealias Value = HTMLElement
	public static let name = "element"
}

public extension AttributeScopes {
	/// HTML metadata together with Foundation's standard attributed-string attributes.
	struct HTMLAttributes: AttributeScope {
		/// Whether this text bypasses the builder's whitespace normalization.
		public let rawText: HTMLRawTextAttribute
		/// The HTML element associated with the run.
		public let element: HTMLElementAttribute

		/// Standard Foundation attributes, including links and presentation intents.
		public let foundation: FoundationAttributes
	}

	/// The scope for reading and writing HTML metadata on attributed text.
	var html: HTMLAttributes.Type {
		HTMLAttributes.self
	}
}

/// Converts HTML parser events into semantic attributed text and element metadata.
///
/// ## Overview
///
/// The builder is an ``HTMLParserDelegate`` that translates parser events into a Swift `AttributedString`. Use it when you want parsed text without a view, need diagnostics, or want to post-process HTML metadata.
///
/// ```swift
/// import Foundation
/// import SimpleHTML
///
/// let builder = HTMLAttributedStringBuilder(html: "<p>Hello <strong>world</strong>.</p>")
/// let text = builder.generatedAttributedString()
/// let diagnostics = builder.parseErrors.map { String(reflecting: $0) }
/// ```
///
/// For the common case, `AttributedString(html: "<p>Hello</p>")` is a convenience initializer using the same builder. It returns the text without exposing diagnostics.
///
/// ### Supported tags
///
/// | HTML | Attributed-string representation |
/// | --- | --- |
/// | `strong`, `b` | Strong inline presentation intent |
/// | `em`, `i` | Emphasized inline presentation intent |
/// | `u` | Platform underline attribute |
/// | `a` | Link URL from `href` |
/// | `p` | Paragraph presentation intent |
/// | `ul`, `ol`, `li` | Nested list and list-item presentation intents |
/// | `br` | A literal newline marked as raw text |
/// | `img` | `imageURL` from `src`, with `alt` text or U+FFFC as its content |
/// | `iframe` | U+FFFC placeholder with element metadata |
///
/// Other elements retain metadata and pass through their text, but do not receive special formatting. For example, heading tags do not create heading intents, `pre` does not enable whitespace preservation, and `ol` attributes such as `start` do not change numbering. Script and style text are not explicitly filtered by the builder. Treat this as a converter for known HTML, not a sanitizer.
///
/// Every generated text run carries an ``HTMLElementAttribute`` describing its innermost element and ancestors. Inline attributes inherit through nesting. Elements without text generally have no corresponding run, except the media and line-break tags described above.
///
/// ### Whitespace and block boundaries
///
/// By default, the builder collapses ordinary inline whitespace and trims it within its normalization ranges. Newlines inserted for `br` are preserved using ``HTMLRawTextAttribute``. Set `preserveWhitespace: true` to retain whitespace delivered by the parser; this does not bypass libxml2's parsing and recovery behavior.
///
/// ```swift
/// let text = AttributedString(
///     html: "<p>enum Example {<br />  case value<br />}</p>",
///     preserveWhitespace: true
/// )
/// ```
///
/// Paragraph and list boundaries are represented by presentation intents, not inserted newline characters. For `<p>Hello</p><p>world</p>`, `String(text.characters)` is `Helloworld`. A block-aware renderer such as ``BlockTextView`` lays the paragraphs out separately. Plain-text export needs to insert separators explicitly.
///
/// ### Seed an existing string
///
/// The inout overload appends generated content to a supplied string. Existing content and attributes remain in the result, though the final whitespace normalization also visits that content unless whitespace preservation is enabled.
///
/// ```swift
/// var text = AttributedString("Prefix: ")
/// let builder = HTMLAttributedStringBuilder(html: "<strong>hello</strong>", preserveWhitespace: true)
/// builder.generatedAttributedString(string: &text)
/// ```
///
/// ### Diagnostics and customization
///
/// Parsing is synchronous and best effort. The builder returns recovered content even when libxml2 reports errors; ``parseErrors`` contains diagnostics from the generation call. A diagnostic does not necessarily mean the result is unusable. Create a fresh builder for each document and do not share one instance between concurrent operations.
///
/// Post-process the result to implement known CSS classes, plain-text conversion, or custom media rendering. See <doc:CustomizingHTML>. The builder is public but not open for subclassing outside the module; for different behavior during parsing, implement ``HTMLParserDelegate`` with ``HTMLParser`` as shown in <doc:CustomParsing>.
public class HTMLAttributedStringBuilder {
	private let data: Data
	private let parser: HTMLParser
	let preserveWhitespace: Bool

	/// Creates a builder for a UTF-8 encoded Swift string.
	/// - Parameters:
	///   - html: The HTML source.
	///   - preserveWhitespace: Whether to skip final whitespace normalization.
	public convenience init(html: String, preserveWhitespace: Bool = false) {
		let data = Data(html.utf8)
		self.init(
			html: data,
			encoding: .utf8,
			preserveWhitespace: preserveWhitespace,
		)
	}

	/// Creates a builder for HTML data with an explicit character encoding.
	/// - Parameters:
	///   - html: The HTML bytes.
	///   - encoding: The encoding of the input data.
	///   - preserveWhitespace: Whether to skip final whitespace normalization.
	public init(
		html: Data,
		encoding: String.Encoding = .utf8,
		preserveWhitespace: Bool = false,
	) {
		self.data = html

		self.parser = HTMLParser(data: data, encoding: encoding)

		self.preserveWhitespace = preserveWhitespace

		parser.delegate = self
	}

	private var string = AttributedString()
	/// Diagnostics collected during the most recent generation call.
	///
	/// Recovery may still produce useful text when this array is nonempty.
	public var parseErrors: [any Error] = []

	/// Parses the HTML and appends its content to the supplied attributed string.
	///
	/// Final whitespace normalization also visits the supplied content unless disabled.
	/// - Parameter string: Existing content to include before the generated HTML text.
	public func generatedAttributedString(string: inout AttributedString) {
		self.string = string
		parseErrors = []

		_ = parser.parse()

		string = self.string
	}

	/// Parses the HTML synchronously and returns its attributed text.
	/// - Returns: Best-effort output, including recovered content if parsing reports errors.
	public func generatedAttributedString() -> AttributedString {
		self.string = AttributedString()
		parseErrors = []

		_ = parser.parse()

		return self.string
	}

	private var attributesStack: [AttributeContainer] = []
	private var ordinalStack: [PresentationIntent: Int] = [:]
	private var currentAttributes: AttributeContainer {
		attributesStack.last ?? AttributeContainer()
	}

	/// this is incremented every time a new block level element is detected
	private var intentID = 1

	private func nextIntentID() -> Int {
		let id = intentID
		intentID += 1
		return id
	}

	private func nextOrdinal(for parent: PresentationIntent?) -> Int {
		let ordinal: Int
		if let parent {
			ordinal = ordinalStack[parent, default: 1]
			ordinalStack[parent] = ordinal + 1
		} else {
			ordinal = 1
		}

		return ordinal
	}
}

extension HTMLAttributedStringBuilder: HTMLParserDelegate {
	public func parser(
		_ parser: HTMLParser,
		didStartElement elementName: String,
		attributes attributeDict: [AnyHashable: Any],
	) {
		var attributes = currentAttributes
		let parent = attributes.presentationIntent

		let element = HTMLElement(
			parent: attributes.html.element,
			name: elementName,
			attributes: attributeDict as? [String: String] ?? [:],
		)
		attributes.html.element = element

		switch elementName {
		case "strong", "b":
			var intent = attributes.inlinePresentationIntent ?? []
			intent.insert(.stronglyEmphasized)
			attributes.inlinePresentationIntent = intent
		case "em", "i":
			var intent = attributes.inlinePresentationIntent ?? []
			intent.insert(.emphasized)
			attributes.inlinePresentationIntent = intent
		case "u":
			attributes.underlineStyle = .single
		case "a":
			let href = attributeDict["href"] as? String
			attributes.link = href.flatMap { URL(string: $0) }
		case "p":
			attributes.presentationIntent = .init(
				.paragraph,
				identity: nextIntentID(),
				parent: parent,
			)
		case "ul":
			attributes.presentationIntent = .init(
				.unorderedList,
				identity: nextIntentID(),
				parent: parent,
			)
		case "ol":
			attributes.presentationIntent = .init(
				.orderedList,
				identity: nextIntentID(),
				parent: parent,
			)
		case "li":
			attributes.presentationIntent = .init(
				.listItem(ordinal: nextOrdinal(for: parent)),
				identity: nextIntentID(),
				parent: parent,
			)
		case "img":
			let urlString = attributeDict["src"] as? String ?? ""
			attributes.imageURL = URL(string: urlString)

			let alt = attributeDict["alt"] as? String ?? ""
			let content = alt.isEmpty ? String(.objectPlaceholder) : alt
			self.string += AttributedString(content, attributes: attributes)
		case "iframe":
			self.string += AttributedString(String(.objectPlaceholder), attributes: attributes)
		case "br":
			attributes.html.rawText = true
			self.string += AttributedString("\n", attributes: attributes)
		default: break
		}

		attributesStack.append(attributes)
	}

	public func parser(
		_ parser: HTMLParser,
		didEndElement elementName: String,
	) {
		attributesStack.removeLast()
	}

	public func parser(
		_ parser: HTMLParser,
		foundCharacters string: String,
	) {
		let container = currentAttributes
		let new = AttributedString(string, attributes: container)

		self.string += new
	}

	public func parserFoundProcessingInstruction(
		_ parser: HTMLParser,
		target: String,
		data: String?,
	) {}

	public func parserDidEndDocument(_ parser: HTMLParser) {
		if !preserveWhitespace {
			// normalize whitespace
			// https://developer.mozilla.org/en-US/docs/Web/API/Document_Object_Model/Whitespace
			// we first iterate runs by "presentationIntent" which is basically
			// the same as block level html elements

			// updating in reverse order to avoid invalidating the ranges
			for (_, range) in string.runs[\.presentationIntent].reversed() {
				for (isRawText, range) in string[range].runs[HTMLRawTextAttribute.self].reversed() {
					guard isRawText != true else { continue }

					var substring = AttributedString(string[range])

					// this may remove all characters in which case it will be removed
					substring.characters.normalizeInlineSpaces()

					string.replaceSubrange(range, with: substring)
				}
			}
		}
	}

	public func parser(
		_ parser: HTMLParser,
		parseErrorOccurred parseError: ParseError,
	) {
		// errors can be pretty mundane and not actually cause issues
		self.parseErrors.append(parseError)
	}
}

extension Collection {
	func validIndex(after: Index) -> Index? {
		let index = self.index(after: after)
		guard self.indices.contains(index) else { return nil }
		return index
	}
}

extension BidirectionalCollection {
	func validIndex(before: Index) -> Index? {
		guard before != startIndex else { return nil }
		return self.index(before: before)
	}
}

extension AttributedString.CharacterView {
	mutating func normalizeInlineSpaces() {
		for index in self.indices.reversed() {
			if self[index].isIgnorableWhitespace {
				if
					let next = self.validIndex(before: index),
					self[next].isIgnorableWhitespace
				{
					self.remove(at: index)
				} else if self[index] != " " {
					self[index] = " "
				}
			}
		}

		while self.first?.isIgnorableWhitespace == true {
			self.removeFirst()
		}

		while self.last?.isIgnorableWhitespace == true {
			self.removeLast()
		}
	}
}
