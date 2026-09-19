public import Foundation
import libxml2
public import SAXErrorHandler

// based on DTHTMLParser https://github.com/Cocoanetics/DTFoundation/blob/develop/Core/Source/DTHTMLParser/DTHTMLParser.m

public struct ParseError: Error {
	var message: String
}

extension ParseError: LocalizedError {
	public var errorDescription: String? {
		message
	}
}

public protocol HTMLParserDelegate: AnyObject {
	func parserDidStartDocument(_ parser: HTMLParser)

	func parser(
		_ parser: HTMLParser,
		didStartElement elementName: String,
		attributes attributeDict: [AnyHashable: Any]
	)

	func parser(
		_ parser: HTMLParser,
		didEndElement elementName: String
	)

	func parser(
		_ parser: HTMLParser,
		foundCharacters string: String
	)

	func parser(
		_ parser: HTMLParser,
		foundComment comment: String
	)

	func parser(
		_ parser: HTMLParser,
		foundCDATA cdata: Data
	)

	func parserFoundProcessingInstruction(
		_ parser: HTMLParser,
		target: String,
		data: String?
	)

	func parserDidEndDocument(_ parser: HTMLParser)

	func parser(
		_ parser: HTMLParser,
		parseErrorOccurred parseError: ParseError
	)
}

public extension HTMLParserDelegate {
	func parserDidStartDocument(_ parser: HTMLParser) {}

	func parserDidEndDocument(_ parser: HTMLParser) {}

	func parser(
		_ parser: HTMLParser,
		foundComment comment: String
	) {}

	func parser(
		_ parser: HTMLParser,
		foundCDATA cdata: Data
	) {}
}

private func _startDocument() {}

public class HTMLParser: SAXErrorHandler {
	public weak var delegate: (any HTMLParserDelegate)?

	private var data: Data
	private var encoding: String.Encoding

	private var _accumulateBuffer: String = ""

	private var _handler: htmlSAXHandler

	private var _parserContext: htmlParserCtxtPtr?

	private var isAborting: Bool = false

	/**
	 Initializes the receiver with the HTML contents encapsulated in a given data object.

	 @param data An `NSData` object containing XML markup.
	 @param encoding The encoding used for encoding the HTML data
	 @returns An initialized `DTHTMLParser` object or nil if an error occurs.
	 */
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

	public func parseErrorOccurred(_ message: String) {
		let error = ParseError(message: message)
		delegate?.parser(self, parseErrorOccurred: error)
	}

	/**
	 Starts the event-driven parsing operation.

	 If you invoke this method, the delegate, if it implements parser:parseErrorOccurred:, is informed of the cancelled parsing operation.

	 @returns `YES` if parsing is successful and `NO` in there is an error or if the parsing operation is aborted.
	 */
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
				charEnc
			)
		}

		// set some options
		let options = htmlParserOption(
			HTML_PARSE_RECOVER.rawValue |
				HTML_PARSE_NONET.rawValue |
				HTML_PARSE_COMPACT.rawValue |
				HTML_PARSE_NOBLANKS.rawValue
		)
		htmlCtxtUseOptions(_parserContext, Int32(bitPattern: options.rawValue))

		// parse!
		let result = htmlParseDocument(_parserContext)

		return result == 0 && !isAborting
	}

	/**
	 Stops the parser object.

	 @see parse
	 @see parserError
	 */
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

	/**
	 Returns the column number of the XML document being processed by the receiver.

	 The column refers to the nesting level of the HTML elements in the document. You may invoke this method once a parsing operation has begun or after an error occurs.
	 */
	public var columnNumber: Int {
		.init(xmlSAX2GetColumnNumber(_parserContext))
	}

	/**
	 Returns the line number of the HTML document being processed by the receiver.

	 You may invoke this method once a parsing operation has begun or after an error occurs.
	 */
	public var lineNumber: Int {
		.init(xmlSAX2GetLineNumber(_parserContext))
	}

	/**
	 Returns an `NSError` object from which you can obtain information about a parsing error.

	 You may invoke this method after a parsing operation abnormally terminates to determine the cause of error.
	 */
	public private(set) var parseError: (any Error)?

	/**
	 Returns the public identifier of the external entity referenced in the HTML document.

	 You may invoke this method once a parsing operation has begun or after an error occurs.
	 */
	public var publicID: String {
		guard let publicID = xmlSAX2GetPublicId(_parserContext) else { return "" }

		return String(cString: publicID)
	}

	/**
	 Returns the system identifier of the external entity referenced in the HTML document.

	 You may invoke this method once a parsing operation has begun or after an error occurs.
	 */
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
