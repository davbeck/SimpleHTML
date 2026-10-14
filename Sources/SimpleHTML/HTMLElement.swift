public import Foundation

/// An HTML element's name, source attributes, and parent chain.
///
/// Equality and hashing use element identity, so separate elements with identical
/// names and attributes remain distinct. This is metadata, not a DOM node with children.
public struct HTMLElement: Sendable {
	private final class Storage: Sendable {
		let parent: HTMLElement?
		let name: String
		let attributes: [String: String]

		init(
			parent: HTMLElement? = nil,
			name: String,
			attributes: [String: String] = [:],
		) {
			self.parent = parent
			self.name = name
			self.attributes = attributes
		}
	}

	private let storage: Storage

	/// The enclosing element, if any.
	public var parent: HTMLElement? {
		storage.parent
	}

	/// The element name reported by libxml2.
	public var name: String {
		storage.name
	}

	/// Source HTML attributes, such as `class`, `style`, `href`, and `alt`.
	public var attributes: [String: String] {
		storage.attributes
	}

	/// Creates a distinct element identity with the supplied metadata.
	/// - Parameters:
	///   - parent: The enclosing element.
	///   - name: The HTML tag name.
	///   - attributes: Source attribute names and values.
	public init(
		parent: HTMLElement?,
		name: String,
		attributes: [String: String],
	) {
		storage = Storage(
			parent: parent,
			name: name,
			attributes: attributes,
		)
	}

	/// The current element's class attribute.
	///
	/// Tokens are separated by ASCII whitespace and kept in first-occurrence order.
	/// Empty entries and exact Unicode duplicates are omitted. Ancestor classes are not included.
	public var classes: [String] {
		let tokens = (attributes["class"] ?? "").unicodeScalars.split {
			switch $0.value {
			case 0x09, 0x0A, 0x0C, 0x0D, 0x20: true
			default: false
			}
		}
		// Byte keys keep canonically equivalent but differently encoded names distinct.
		var seen: Set<[UInt8]> = []
		return tokens.map(String.init).filter { seen.insert(Array($0.utf8)).inserted }
	}

	/// Checks this element and its ancestors for a class name.
	///
	/// Matching is case-sensitive and compares exact Unicode sequences without normalization.
	/// - Parameter class: The class name to find.
	/// - Returns: Whether any element in the parent chain has that class.
	public func has(class: String) -> Bool {
		classes.contains { $0.utf8.elementsEqual(`class`.utf8) } || (parent?.has(class: `class`) == true)
	}

	/// The numeric `width` attribute, without CSS unit interpretation.
	public var width: Double? {
		attributes["width"].flatMap { Double($0) }
	}

	/// The numeric `height` attribute, without CSS unit interpretation.
	public var height: Double? {
		attributes["height"].flatMap { Double($0) }
	}

	/// The `src` attribute parsed as a URL, without resolving a base URL.
	public var src: URL? {
		attributes["src"].flatMap { URL(string: $0) }
	}
}

extension HTMLElement: Equatable {
	public static func == (lhs: HTMLElement, rhs: HTMLElement) -> Bool {
		lhs.storage === rhs.storage
	}
}

extension HTMLElement: Hashable {
	public func hash(into hasher: inout Hasher) {
		hasher.combine(ObjectIdentifier(storage))
	}
}

extension HTMLElement: Codable {
	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		try self.init(
			parent: container.decodeIfPresent(HTMLElement.self, forKey: .parent),
			name: container.decode(String.self, forKey: .name),
			attributes: container.decode([String: String].self, forKey: .attributes),
		)
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		try container.encode(storage.parent, forKey: .parent)
		try container.encode(storage.name, forKey: .name)
		try container.encode(storage.attributes, forKey: .attributes)
	}

	private enum CodingKeys: String, CodingKey {
		case parent
		case name
		case attributes
	}
}

extension HTMLElement: CustomStringConvertible {
	private var pointerDescription: String {
		String(describing: Unmanaged.passUnretained(storage).toOpaque())
	}

	public var description: String {
		"HTMLElement(id: \(pointerDescription), parent: \(parent?.pointerDescription ?? "nil"), name: \(name), attributes: \(attributes))"
	}
}
