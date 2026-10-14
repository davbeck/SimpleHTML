public import Foundation
import libxml2
public import SAXErrorHandler

// based on DTHTMLParser https://github.com/Cocoanetics/DTFoundation/blob/develop/Core/Source/DTHTMLParser/DTHTMLParser.m

/// A diagnostic reported by libxml2 while interpreting HTML.
///
/// Its debug description contains the parser's message. Recovery may still
/// produce usable output after a diagnostic.
public struct ParseError: Error {
	var message: String
}

extension ParseError: CustomDebugStringConvertible {
	public var debugDescription: String {
		message
	}
}

/// Receives synchronous events from ``HTMLParser`` on the calling thread.
///
/// The parser holds its delegate weakly. Retain the delegate until parsing ends.
public protocol HTMLParserDelegate: AnyObject {
	/// Called before document events begin.
	func parserDidStartDocument(_ parser: HTMLParser)

	/// Reports an opening element and its source attributes.
	func parser(
		_ parser: HTMLParser,
		didStartElement elementName: String,
		attributes attributeDict: [AnyHashable: Any],
	)

	/// Reports a closing element after libxml2 recovery.
	func parser(
		_ parser: HTMLParser,
		didEndElement elementName: String,
	)

	/// Reports decoded character data, including expanded entities.
	func parser(
		_ parser: HTMLParser,
		foundCharacters string: String,
	)

	/// Reports a comment without its markup delimiters.
	func parser(
		_ parser: HTMLParser,
		foundComment comment: String,
	)

	/// Reports a CDATA block.
	func parser(
		_ parser: HTMLParser,
		foundCDATA cdata: Data,
	)

	/// Reports a processing instruction and its optional data.
	func parserFoundProcessingInstruction(
		_ parser: HTMLParser,
		target: String,
		data: String?,
	)

	/// Called when the document ends.
	func parserDidEndDocument(_ parser: HTMLParser)

	/// Reports a parser diagnostic; recovery may continue.
	func parser(
		_ parser: HTMLParser,
		parseErrorOccurred parseError: ParseError,
	)
}

public extension HTMLParserDelegate {
	func parserDidStartDocument(_ parser: HTMLParser) {}

	func parserDidEndDocument(_ parser: HTMLParser) {}

	func parser(
		_ parser: HTMLParser,
		foundComment comment: String,
	) {}

	func parser(
		_ parser: HTMLParser,
		foundCDATA cdata: Data,
	) {}
}

private func _startDocument() {}

/// Parses HTML with libxml2 and delivers events to a weak delegate.
///
/// ## Overview
///
/// `HTMLParser` wraps libxml2's event-driven HTML parser. It does not create a DOM, attributed string, or view. Assign an ``HTMLParserDelegate`` and call ``parse()`` to receive synchronous events on the calling thread.
///
/// ```swift
/// let parser = HTMLParser(data: Data(html.utf8), encoding: .utf8)
/// parser.delegate = delegate
/// let succeeded = parser.parse()
/// ```
///
/// The delegate is weak: retain it for the entire parse. Use a fresh parser for each document, and do not call `parse()` concurrently on the same instance. ``abortParsing()`` stops parsing and disables subsequent callbacks; create another parser to process another document after cancellation.
///
/// ### Events and recovery
///
/// The parser reports document start/end, start/end elements, character data, comments, CDATA, processing instructions, and diagnostics. Document start/end, comment, and CDATA callbacks have default no-op implementations in the delegate protocol. Implement the remaining requirements even if your app ignores them.
///
/// Character callbacks contain decoded text, including expanded entities. The parser accumulates libxml2's character chunks and flushes them around element boundaries; do not assume one callback per source text node. HTML recovery may insert elements such as `html` and `body` and correct malformed nesting. Events describe libxml2's interpretation rather than an exact replay of the source.
///
/// Parsing uses recovery, compact storage, blank-node suppression, and the no-network option. It does not fetch stylesheets or media, evaluate CSS, or execute JavaScript.
///
/// ### Errors and positions
///
/// ``parse()`` returns `true` when libxml2 reports success and parsing was not aborted. Diagnostics are delivered through ``HTMLParserDelegate/parser(_:parseErrorOccurred:)``; recovery can produce useful output even when the result is `false`.
///
/// The ``parseError`` property currently remains `nil`: the implementation forwards errors to the delegate without storing them there. Collect errors in your delegate, or use ``HTMLAttributedStringBuilder/parseErrors``. ``lineNumber`` and ``columnNumber`` expose libxml2's current source position, and are most useful inside callbacks.
///
/// See <doc:CustomParsing> for delegates that extract plain text or build Core Text attributes directly.
public class HTMLParser: SAXErrorHandler {
	/// The event receiver, which the caller must retain while parsing.
	public weak var delegate: (any HTMLParserDelegate)?

	private var data: Data
	private var encoding: String.Encoding

	private var _accumulateBuffer: String = ""

	private var _handler: htmlSAXHandler

	private var _parserContext: htmlParserCtxtPtr?

	private var isAborting: Bool = false

	/// Creates a parser for the supplied HTML bytes.
	/// - Parameters:
	///   - data: HTML source data.
	///   - encoding: The encoding of the input bytes.
	public init(data: Data, encoding: String.Encoding) {
		self.data = data
		self.encoding = encoding

		_handler = .init()
		xmlSAX2InitHtmlDefaultSAXHandler(&_handler)

		_handler.startDocument = { context in
			guard let context else { return }
			let parser: HTMLParser = Unmanaged.fromOpaque(context).takeUnretainedValue()

			parser.delegate?.parserDidStartDocument(parser)
		}
		_handler.endDocument = { context in
			guard let context else { return }
			let parser: HTMLParser = Unmanaged.fromOpaque(context).takeUnretainedValue()

			parser.delegate?.parserDidEndDocument(parser)
		}
		// libxml reports characters in batches of at most 1000 at a time
		// in addition, entities are reported separately
		_handler.characters = { context, characters, length in
			guard let context else { return }
			let parser: HTMLParser = Unmanaged.fromOpaque(context).takeUnretainedValue()

			guard
				let characters,
				let string = String(bytes: UnsafeBufferPointer(start: characters, count: .init(length)), encoding: .utf8)
			else { return }

			parser._accumulateCharacters(string)
		}
		_handler.startElement = { context, name, atts in
			guard let context else { return }
			let parser: HTMLParser = Unmanaged.fromOpaque(context).takeUnretainedValue()

			parser.resetAccumulateBufferAndReportCharacters()

			guard let name else { return }

			if let delegate = parser.delegate {
				let nameStr = String(cString: name)

				var attributes: [String: String] = [:]

				if let atts {
					var key: String?
					var value: String?

					var i = 0
					while true {
						let att = atts[i]
						i += 1

						if let valueKey = key {
							if let att {
								value = String(cString: att)
							} else {
								// solo attribute
								value = valueKey
							}

							attributes[valueKey] = value
							value = nil
							key = nil
						} else {
							guard let att else {
								// we're done
								break
							}

							key = String(cString: att)
						}
					}
				}

				delegate.parser(parser, didStartElement: nameStr, attributes: attributes)
			}
		}
		_handler.endElement = { context, name in
			guard let context else { return }
			let parser: HTMLParser = Unmanaged.fromOpaque(context).takeUnretainedValue()

			parser.resetAccumulateBufferAndReportCharacters()

			guard let name else { return }
			parser.delegate?.parser(parser, didEndElement: String(cString: name))
		}
		_handler.comment = { context, value in
			guard let context else { return }
			let parser: HTMLParser = Unmanaged.fromOpaque(context).takeUnretainedValue()

			guard let value else { return }

			parser.delegate?.parser(parser, foundComment: String(cString: value))
		}

		// Swift does not support C variadic function pointers so we have to use a C function to call back to us using a protocol
		useErrorHandlerProtocol(&_handler)

		_handler.cdataBlock = { context, value, length in
			guard let context else { return }
			let parser: HTMLParser = Unmanaged.fromOpaque(context).takeUnretainedValue()

			guard let value else { return }

			parser.delegate?.parser(parser, foundCDATA: Data(bytes: value, count: .init(length)))
		}
		_handler.processingInstruction = { context, target, data in
			guard let context else { return }
			let parser: HTMLParser = Unmanaged.fromOpaque(context).takeUnretainedValue()

			guard let target else { return }
			let targetStr = String(cString: target)
			let dataStr = data.map { String(cString: $0) }

			parser.delegate?.parserFoundProcessingInstruction(parser, target: targetStr, data: dataStr)
		}
	}

	deinit {
		if let _parserContext {
			htmlFreeParserCtxt(_parserContext)
		}
	}

	/// Forwards a libxml2 error message to the delegate.
	/// - Parameter message: The diagnostic text supplied by the SAX error bridge.
	public func parseErrorOccurred(_ message: String) {
		let error = ParseError(message: message)
		delegate?.parser(self, parseErrorOccurred: error)
	}

	/// Parses the document synchronously, recovering from malformed HTML where possible.
	/// - Returns: `true` if libxml2 reports success and parsing was not aborted.
	///
	/// Collect diagnostics through the delegate. Use a fresh parser for each document.
	public func parse() -> Bool {
		// detect encoding if necessary
		var charEnc: xmlCharEncoding = XML_CHAR_ENCODING_NONE

		let cfenc = CFStringConvertNSStringEncodingToEncoding(encoding.rawValue)
		if cfenc != kCFStringEncodingInvalidId {
			let cfencstr = CFStringConvertEncodingToIANACharSetName(cfenc)

			if let cfencstr {
				let encstr = String(cfencstr)
				charEnc = encstr.withCString { enc in
					xmlParseCharEncoding(enc)
				}
			}
		}

		// create a parse context
		_parserContext = data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
			htmlCreatePushParserCtxt(
				&_handler,
				Unmanaged.passUnretained(self).toOpaque(),
				buffer.bindMemory(to: CChar.self).baseAddress,
				Int32(data.count),
				nil,
				charEnc,
			)
		}

		// set some options
		let options = htmlParserOption(
			HTML_PARSE_RECOVER.rawValue |
				HTML_PARSE_NONET.rawValue |
				HTML_PARSE_COMPACT.rawValue |
				HTML_PARSE_NOBLANKS.rawValue,
		)
		htmlCtxtUseOptions(_parserContext, Int32(bitPattern: options.rawValue))

		// parse!
		let result = htmlParseDocument(_parserContext)

		return result == 0 && !isAborting
	}

	/// Stops the current parse and disables subsequent parser callbacks.
	///
	/// Create a new parser to parse another document after cancellation.
	public func abortParsing() {
		if let _parserContext {
			// apparently this frees it too
			xmlStopParser(_parserContext)
			self._parserContext = nil
		}

		isAborting = true

		// prevent future callbacks
		_handler.startDocument = nil
		_handler.endDocument = nil
		_handler.startElement = nil
		_handler.endElement = nil
		_handler.characters = nil
		_handler.comment = nil
		_handler.error = nil
		_handler.processingInstruction = nil
	}

	/// The current source column reported by libxml2. Read it inside a callback.
	public var columnNumber: Int {
		.init(xmlSAX2GetColumnNumber(_parserContext))
	}

	/// The current source line reported by libxml2. Read it inside a callback.
	public var lineNumber: Int {
		.init(xmlSAX2GetLineNumber(_parserContext))
	}

	/// A reserved error property that currently remains `nil`.
	///
	/// Diagnostics are forwarded to the delegate instead of stored here.
	public private(set) var parseError: (any Error)?

	/// The current external entity's public identifier, or an empty string.
	public var publicID: String {
		guard let publicID = xmlSAX2GetPublicId(_parserContext) else { return "" }

		return String(cString: publicID)
	}

	/// The current external entity's system identifier, or an empty string.
	public var systemID: String {
		guard let systemID = xmlSAX2GetSystemId(_parserContext) else { return "" }

		return String(cString: systemID)
	}

	private func resetAccumulateBufferAndReportCharacters() {
		// nothing in the buffer
		guard !_accumulateBuffer.isEmpty else { return }

		delegate?.parser(self, foundCharacters: _accumulateBuffer)

		// reset buffer
		_accumulateBuffer = ""
	}

	private func _accumulateCharacters(_ characters: String) {
		_accumulateBuffer += characters
	}
}
