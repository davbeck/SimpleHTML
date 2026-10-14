import Foundation

private let characters = Array("zabcdefghijklmnopqrstuvwxy")

extension String {
	/// Produces a number represented as alpha characters similar to the "lower-alpha" CSS value
	init(alphaNumerals input: Int) {
		// if you want to sound smart, you'll tell people that this
		// is a bijective base-26 system
		// https://en.wikipedia.org/wiki/Bijective_numeration#The_bijective_base-26_system

		self.init()

		var number = abs(input)
		while number > 0 {
			self.insert(
				characters[number % characters.count],
				at: self.startIndex
			)
			number = (number - 1) / characters.count
		}

		if input < 0 {
			self.insert("−", at: self.startIndex)
		}
	}
}
