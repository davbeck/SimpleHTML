public extension Character {
	// unicode characters

	static let objectPlaceholder: Character = "\u{fffc}"
	static let lineFeed: Character = "\u{2028}"

	// unicode spaces (see http://www.cs.tut.fi/~jkorpela/chars/spaces.html)

	static let space: Character = "\u{0020}"
	static let nonBreakingSpace: Character = "\u{00a0}"
	static let oghamSpaceMark: Character = "\u{1680}"
	static let mongolianVowelSeparator: Character = "\u{180e}"
	static let enQuad: Character = "\u{2000}"
	static let emQuad: Character = "\u{2001}"
	static let enSpace: Character = "\u{2002}"
	static let emSpace: Character = "\u{2003}"
	static let threePerEmSpace: Character = "\u{2004}"
	static let fourPerEmSpace: Character = "\u{2005}"
	static let sixPerEmSpace: Character = "\u{2006}"
	static let figureSpace: Character = "\u{2007}"
	static let punctuationSpace: Character = "\u{2008}"
	static let thinSpace: Character = "\u{2009}"
	static let hairSpace: Character = "\u{200a}"
	static let zeroWidthSpace: Character = "\u{200b}"
	static let narrowNoBreakSpace: Character = "\u{202f}"
	static let mediumMathematicalSpace: Character = "\u{205f}"
	static let ideographicSpace: Character = "\u{3000}"
	static let zeroWidthNoBreakSpace: Character = "\u{feff}"

	var isIgnorableWhitespace: Bool {
		switch self {
		case .nonBreakingSpace,
		     .oghamSpaceMark,
		     .mongolianVowelSeparator,
		     .enQuad,
		     .emQuad,
		     .enSpace,
		     .emSpace,
		     .threePerEmSpace,
		     .fourPerEmSpace,
		     .sixPerEmSpace,
		     .figureSpace,
		     .punctuationSpace,
		     .thinSpace,
		     .hairSpace,
		     .zeroWidthSpace,
		     .narrowNoBreakSpace,
		     .mediumMathematicalSpace,
		     .ideographicSpace,
		     .zeroWidthNoBreakSpace:
			return false
		default:
			return isWhitespace
		}
	}
}

public extension Collection where Element == Character {
	var isIgnorableWhitespace: Bool {
		allSatisfy(\.isIgnorableWhitespace)
	}
}
