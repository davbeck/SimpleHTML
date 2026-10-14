import Foundation

// https://gist.github.com/kumo/a8e1cb1f4b7cff1548c7

private let values: [(arabic: Int, roman: String)] = [
	(1000, "M"),
	(900, "CM"),
	(500, "D"),
	(400, "CD"),
	(100, "C"),
	(90, "XC"),
	(50, "L"),
	(40, "XL"),
	(10, "X"),
	(9, "IX"),
	(5, "V"),
	(4, "IV"),
	(1, "I"),
]

extension String {
	init(romanNumerals number: Int) {
		self.init()

		var startingValue = number
		for (arabic, roman) in values {
			let div = startingValue / arabic
			if div > 0 {
				for _ in 0 ..< div {
					self += roman
				}
				startingValue -= arabic * div
			}
		}
	}
}
