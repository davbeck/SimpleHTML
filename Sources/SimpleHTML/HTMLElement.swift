import Foundation

public struct HTMLElement {
	private class Storage {
		var parent: HTMLElement?
		var name: String
		var attributes: [String: String]

		init(
			parent: HTMLElement? = nil,
			name: String,
			attributes: [String: String] = [:]
		) {
			self.parent = parent
			self.name = name
			self.attributes = attributes
		}
	}

	private var storage: Storage

	public var parent: HTMLElement? {
		storage.parent
	}

	public var name: String {
		storage.name
	}

	public var attributes: [String: String] {
		storage.attributes
	}

	public init(
		parent: HTMLElement?,
		name: String,
		attributes: [String: String]
	) {
		storage = Storage(
			parent: parent,
			name: name,
			attributes: attributes
		)
	}

	public var classes: [String] {
		attributes["class"]?.components(separatedBy: .whitespacesAndNewlines) ?? []
	}

	public func has(class: String) -> Bool {
		classes.contains(`class`) || (parent?.has(class: `class`) == true)
	}

	public var width: Double? {
		attributes["width"].flatMap { Double($0) }
	}

	public var height: Double? {
		attributes["height"].flatMap { Double($0) }
	}

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
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		try self.init(
			parent: container.decodeIfPresent(HTMLElement.self, forKey: .parent),
			name: container.decode(String.self, forKey: .name),
			attributes: container.decode([String: String].self, forKey: .attributes)
		)
	}

	public func encode(to encoder: Encoder) throws {
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
