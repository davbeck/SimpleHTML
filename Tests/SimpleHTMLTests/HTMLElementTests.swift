import CustomDump
import SimpleHTML
import Testing

struct HTMLElementTests {
	@Test(arguments: ["primary secondary", "  primary   secondary  ", "\tprimary\n\rsecondary\t", "primary\u{000C}secondary"])
	func classesOmitEmptyEntries(value: String) {
		let element = HTMLElement(parent: nil, name: "span", attributes: ["class": value])
		expectNoDifference(element.classes, ["primary", "secondary"])
		#expect(element.has(class: "primary"))
		#expect(!element.has(class: ""))
	}

	@Test(arguments: [nil, "", " \t\n\r "] as [String?])
	func emptyClassAttributes(value: String?) {
		let element = HTMLElement(
			parent: nil, name: "span", attributes: value.map { ["class": $0] } ?? [:],
		)
		expectNoDifference(element.classes, [])
		#expect(!element.has(class: ""))
	}

	@Test(arguments: ["\u{000B}", "\u{0085}", "\u{00A0}", "\u{2003}", "\u{2028}"])
	func whitespaceOutsideHTMLSetRemainsInClassName(separator: String) {
		let name = "primary" + separator + "secondary"
		let element = HTMLElement(parent: nil, name: "span", attributes: ["class": name])
		expectNoDifference(element.classes, [name])
		#expect(element.has(class: name))
		#expect(!element.has(class: "primary"))
		#expect(!element.has(class: "secondary"))
	}

	@Test func classesAreUniqueInSourceOrder() {
		let element = HTMLElement(parent: nil, name: "span", attributes: ["class": "second first second third first"])
		expectNoDifference(element.classes, ["second", "first", "third"])
	}

	@Test func canonicallyEquivalentClassesRemainDistinct() {
		let element = HTMLElement(parent: nil, name: "span", attributes: ["class": "caf\u{00E9} cafe\u{0301} caf\u{00E9}"])
		expectNoDifference(element.classes.map { Array($0.utf8) }, [
			Array("caf\u{00E9}".utf8), Array("cafe\u{0301}".utf8),
		])
	}

	@Test func splitsWhitespaceBeforeCombiningMark() {
		let element = HTMLElement(parent: nil, name: "span", attributes: ["class": "first \u{0301}second"])
		expectNoDifference(element.classes, ["first", "\u{0301}second"])
	}

	@Test(arguments: ["caf\u{00E9}", "cafe\u{0301}"])
	func classMatchingUsesExactUnicode(name: String) {
		let other = name.utf8.elementsEqual("caf\u{00E9}".utf8) ? "cafe\u{0301}" : "caf\u{00E9}"
		let element = HTMLElement(parent: nil, name: "span", attributes: ["class": name])
		#expect(element.has(class: name))
		#expect(!element.has(class: other))
	}

	@Test func classMatchingPreservesCase() {
		let element = HTMLElement(parent: nil, name: "span", attributes: ["class": "Warning"])
		#expect(element.has(class: "Warning"))
		#expect(!element.has(class: "warning"))
	}

	@Test func classMatchingSearchesAncestorsExactly() {
		let grandparent = HTMLElement(parent: nil, name: "div", attributes: ["class": "caf\u{00E9} inherited"])
		let parent = HTMLElement(parent: grandparent, name: "p", attributes: [:])
		let element = HTMLElement(parent: parent, name: "span", attributes: ["class": "local"])
		expectNoDifference(element.classes, ["local"])
		#expect(element.has(class: "local"))
		#expect(element.has(class: "inherited"))
		#expect(element.has(class: "caf\u{00E9}"))
		#expect(!element.has(class: "cafe\u{0301}"))
		#expect(!element.has(class: "Inherited"))
	}
}
