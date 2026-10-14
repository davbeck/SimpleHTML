import SwiftUI

extension PresentationIntent {
	var list: IntentType? {
		components.first(where: {
			$0.kind == .unorderedList || $0.kind == .orderedList
		})
	}

	var ordinal: Int? {
		for component in components {
			switch component.kind {
			case let .listItem(ordinal: ordinal):
				return ordinal
			default:
				break
			}
		}

		return nil
	}

	var listItem: IntentType? {
		components.first {
			if case .listItem = $0.kind { return true }
			return false
		}
	}
}

struct BlockTextLine: View {
	/// How far we indent each level (similar to tab indent levels).
	@ScaledMetric(relativeTo: .body) private var indentation: CGFloat = 24

	var string: AttributedSubstring
	var showsListMarker = true

	@ViewBuilder
	func listMarker(for presentationIntent: PresentationIntent) -> some View {
		switch presentationIntent.list?.kind {
		case .orderedList:
			if let ordinal = presentationIntent.ordinal {
				switch presentationIntent.indentationLevel {
				case 1:
					Text("\(ordinal).")
				case 2:
					// ex: a, b, c
					Text("\(String(alphaNumerals: ordinal).lowercased()).")
				default:
					// ex: i, ii, iii, iv
					Text("\(String(romanNumerals: ordinal).lowercased()).")
				}
			}
		case .unorderedList:
			// using shapes because bullet characters aren't aligned quit right
			// using a solid character (█)
			Text("\u{2588}")
				.opacity(0)
				.overlay {
					GeometryReader { proxy in
						SwiftUI.Group {
							switch presentationIntent.indentationLevel {
							case 1:
								Circle().fill(Color.primary)
							case 2:
								Circle().stroke(Color.primary)
							default:
								Rectangle().fill(Color.primary)
							}
						}
						// size based on font from underlying text
						.frame(
							width: proxy.size.height / 3,
							height: proxy.size.height / 3
						)
						// center in geometry reader
						.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
					}
				}
		default:
			Spacer()
		}
	}

	var body: some View {
		HStack(alignment: .firstTextBaseline) {
			if let presentationIntent = string.presentationIntent,
			   presentationIntent.indentationLevel > 0
			{
				listMarker(for: presentationIntent)
					.opacity(showsListMarker ? 1 : 0)
					.monospacedDigit()
					.frame(minWidth: CGFloat(presentationIntent.indentationLevel) * indentation, alignment: .trailing)
			}
			Text(AttributedString(string))
		}
	}
}
