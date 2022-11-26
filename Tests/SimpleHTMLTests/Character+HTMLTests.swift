import XCTest
@testable import SimpleHTML

class CharacterHTMLTests: XCTestCase {
	func testIsIgnorableWhitespace() throws {
		XCTAssertFalse("\u{00a0}\u{1680}\u{180e}\u{2000}\u{2001}\u{2002}\u{2003}\u{2004}\u{2005}\u{2006}\u{2007}\u{2008}\u{2009}\u{200a}\u{200b}\u{202f}\u{205f}\u{3000}\u{feff}".contains(where: \.isIgnorableWhitespace))
		
		XCTAssertTrue(" \n\r\t".allSatisfy(\.isIgnorableWhitespace))
	}
}
