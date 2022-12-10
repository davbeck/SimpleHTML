import Foundation
import DTFoundation

public extension AttributedString {
	init(html: String, preserveWhitespace: Bool = false) {
		let builder = HTMLAttributedStringBuilder(
			html: html,
			preserveWhitespace: preserveWhitespace
		)
		self = builder.generatedAttributedString()
	}
}

public enum HTMLWidthAttribute: AttributedStringKey, CodableAttributedStringKey {
	public typealias Value = CGFloat
	public static let name = "width"
}

public enum HTMLHeightAttribute: AttributedStringKey, CodableAttributedStringKey {
	public typealias Value = CGFloat
	public static let name = "height"
}

public enum HTMLEmbedURLAttribute: AttributedStringKey, CodableAttributedStringKey {
	public typealias Value = URL
	public static let name = "src"
}

public enum HTMLRawTextAttribute: AttributedStringKey, CodableAttributedStringKey {
	public typealias Value = Bool
	public static let name = "rawText"
}

public extension AttributeScopes {
	struct HTMLAttributes: AttributeScope {
		public let width: HTMLWidthAttribute
		public let height: HTMLHeightAttribute
		public let embedURL: HTMLEmbedURLAttribute
		public let rawText: HTMLRawTextAttribute

		public let foundation: FoundationAttributes
	}

	var html: HTMLAttributes.Type { HTMLAttributes.self }
}

public class HTMLAttributedStringBuilder: NSObject {
	private let data: Data
	private let parser: DTHTMLParser
	let preserveWhitespace: Bool

	public convenience init(html: String, preserveWhitespace: Bool = false) {
		let data = Data(html.utf8)
		self.init(
			html: data,
			encoding: .utf8,
			preserveWhitespace: preserveWhitespace
		)
	}

	public init(
		html: Data,
		encoding: String.Encoding = .utf8,
		preserveWhitespace: Bool = false
	) {
		self.data = html

		self.parser = DTHTMLParser(data: data, encoding: encoding.rawValue)

		self.preserveWhitespace = preserveWhitespace

		super.init()

		parser.delegate = self
	}

	private var string = AttributedString()
	public var parseErrors: [Error] = []

	public func generatedAttributedString(string: inout AttributedString) {
		self.string = string
		parseErrors = []

		_ = parser.parse()

		string = self.string
	}

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

	// this is incremented every time a new block level element is detected
	private var intentID = 1

	private func nextIntentID() -> Int {
		let id = intentID
		intentID += 1
		return id
	}

	private func nextOrdinal(for parent: PresentationIntent?) -> Int {
		let ordinal: Int
		if let parent = parent {
			ordinal = ordinalStack[parent, default: 1]
			ordinalStack[parent] = ordinal + 1
		} else {
			ordinal = 1
		}

		return ordinal
	}
}

extension HTMLAttributedStringBuilder: DTHTMLParserDelegate {
	public func parser(
		_ parser: DTHTMLParser!,
		didStartElement elementName: String!,
		attributes attributeDict: [AnyHashable: Any]! = [:]
	) {
		var attributes = currentAttributes
		let parent = attributes.presentationIntent

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
			let href = attributeDict?["href"] as? String
			attributes.link = href.flatMap { URL(string: $0) }
		case "p":
			attributes.presentationIntent = .init(
				.paragraph,
				identity: nextIntentID(),
				parent: parent
			)
		case "ul":
			attributes.presentationIntent = .init(
				.unorderedList,
				identity: nextIntentID(),
				parent: parent
			)
		case "ol":
			attributes.presentationIntent = .init(
				.orderedList,
				identity: nextIntentID(),
				parent: parent
			)
		case "li":
			attributes.presentationIntent = .init(
				.listItem(ordinal: nextOrdinal(for: parent)),
				identity: nextIntentID(),
				parent: parent
			)
		case "img":
			let urlString = attributeDict["src"] as? String ?? ""
			attributes.imageURL = URL(string: urlString)

			if
				let widthString = attributeDict["width"] as? String,
				let width = Double(widthString)
			{
				attributes.html.width = CGFloat(exactly: width)
			}
			if
				let heightString = attributeDict["height"] as? String,
				let height = Double(heightString)
			{
				attributes.html.height = CGFloat(exactly: height)
			}

			let alt = attributeDict["alt"] as? String ?? ""
			let content = alt.isEmpty ? String(.objectPlaceholder) : alt
			self.string += AttributedString(content, attributes: attributes)
		case "iframe":
			let urlString = attributeDict["src"] as? String ?? ""
			attributes.html.embedURL = URL(string: urlString)

			if
				let widthString = attributeDict["width"] as? String,
				let width = Double(widthString)
			{
				attributes.html.width = CGFloat(exactly: width)
			}
			if
				let heightString = attributeDict["height"] as? String,
				let height = Double(heightString)
			{
				attributes.html.height = CGFloat(exactly: height)
			}

			self.string += AttributedString(String(.objectPlaceholder), attributes: attributes)
		case "br":
			attributes.html.rawText = true
			self.string += AttributedString("\n", attributes: attributes)
		default: break
		}

		attributesStack.append(attributes)
	}

	public func parser(
		_ parser: DTHTMLParser!,
		didEndElement elementName: String!
	) {
		attributesStack.removeLast()
	}

	public func parser(
		_ parser: DTHTMLParser!,
		foundCharacters string: String!
	) {
		let container = currentAttributes
		let new = AttributedString(string, attributes: container)

		self.string += new
	}

	public func parserDidEndDocument(_ parser: DTHTMLParser!) {
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
		_ parser: DTHTMLParser!,
		parseErrorOccurred parseError: Error!
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
