#if os(macOS)
	import AppKit
	import SimpleHTML
	import SnapshotTesting
	import SwiftUI
	import Testing

	/// Presentation assets for README and DocC examples, rather than behavioral coverage.
	/// Keep the example bodies in sync with their corresponding documentation snippets.
	@Suite(.snapshots(record: .never))
	@MainActor
	struct DocumentationSnapshotTests {
		@Test func readmeIntroduction() {
			snapshot(
				HTMLView(html: """
				<p>Hello <strong>world</strong>. Here's what we support:</p>
				<ul><li>Inline formatting and links</li><li>Paragraphs and nested lists</li></ul>
				""")
				.font(.body)
				.tint(.purple),
				name: "readme-introduction",
			)
		}

		@Test func readmeAlignment() {
			snapshot(
				HTMLView(html: "<p>A little <em>emphasis</em>.</p><p>A longer paragraph makes the centered alignment clear.</p>")
					.font(.title3)
					.multilineTextAlignment(.center),
				name: "readme-alignment",
			)
		}

		@Test func readmeMarkdown() throws {
			let text = try AttributedString(markdown: """
			A paragraph with **bold** text.

			1. A first item
			2. A second item
			   - A nested bullet
			""")
			snapshot(BlockTextView(attributedString: text), name: "readme-markdown")
		}

		@Test func overview() {
			snapshot(
				HTMLView(html: "<p>Hello <strong>world</strong>.</p><ul><li>A list item</li></ul>"),
				name: "overview",
			)
		}

		@Test func htmlView() {
			snapshot(
				HTMLView(html: """
				<p>A <strong>bold</strong> idea with a <a href="https://example.com">link</a>.</p>
				<ol><li>Start here</li><li>Keep going</li></ol>
				""")
				.font(.body)
				.tint(.orange)
				.lineSpacing(4),
				name: "html-view",
			)
		}

		@Test func blockTextView() throws {
			let text = try AttributedString(markdown: """
			A paragraph with **bold** and *italic* text.

			1. First item

			   A continuation paragraph.

			   - A nested bullet
			2. Second item
			""")
			snapshot(
				BlockTextView(attributedString: text)
					.font(.body)
					.multilineTextAlignment(.leading),
				name: "block-text-view",
			)
		}

		@Test func visibleLink() {
			func visibleText(html: String) -> AttributedString {
				let original = AttributedString(html: html, preserveWhitespace: true)
				var result = AttributedString()
				for run in original.runs {
					let element = run.html.element
					if element?.has(class: "invisible") == true {
						continue
					}
					result.append(original[run.range])
					if element?.has(class: "ellipsis") == true {
						result.append(AttributedString("…", attributes: run.attributes))
					}
				}
				return result
			}

			let text = visibleText(html: """
			<p>Visit <a href="https://example.com/articles/long-title"><span class="invisible">https://</span><span class="ellipsis">example.com/articles</span><span class="invisible">/long-title</span></a>.</p>
			""")
			snapshot(BlockTextView(attributedString: text), name: "visible-link")
		}

		@Test func customEmoji() throws {
			func emojiText(html: String, images: [URL: Image]) -> Text {
				let original = AttributedString(html: html)
				var result = Text("")
				for run in original.runs {
					if let element = run.html.element,
					   element.name == "img",
					   element.has(class: "emoji"),
					   let url = run.imageURL,
					   let image = images[url]
					{
						result = Text("\(result)\(Text(image).baselineOffset(-3))")
					} else {
						result = Text("\(result)\(Text(AttributedString(original[run.range])))")
					}
				}
				return result
			}

			// Local copy of the documented URL keeps rendering deterministic and offline.
			let imageURL = URL(string: "https://cdn.masto.host/tnkuco/custom_emojis/images/000/000/604/original/9a2294c91c6c88ed.png")!
			let assetURL = try #require(Bundle.module.url(forResource: "custom-emoji", withExtension: "png"))
			let asset = try #require(NSImage(contentsOf: assetURL))
			asset.size = CGSize(width: 20, height: 20)
			let text = emojiText(
				html: """
				<p>Nice work <img class="emoji" src="https://cdn.masto.host/tnkuco/custom_emojis/images/000/000/604/original/9a2294c91c6c88ed.png" alt=":swift:" width="20" height="20"></p>
				""",
				images: [imageURL: Image(nsImage: asset)],
			)
			snapshot(text, name: "custom-emoji")
		}

		private func snapshot(
			_ content: some View,
			name: String,
			file: StaticString = #filePath,
			line: UInt = #line,
		) {
			// Fit each example to its content, with a modest margin like Apple’s documentation illustrations.
			let view = content
				.font(.body)
				.foregroundColor(.black)
				.fixedSize(horizontal: true, vertical: true)
				.padding(16)
				.background(Color.white)
				.overlay(Rectangle().strokeBorder(Color(white: 0.8), lineWidth: 1))
				.environment(\.colorScheme, .light)
				.environment(\.dynamicTypeSize, .large)
				.environment(\.locale, Locale(identifier: "en_US"))
			// Render SwiftUI directly at 4× so text is rasterized at the output density.
			let renderer = ImageRenderer(content: view)
			renderer.scale = 4
			// Preserve the full bitmap when SnapshotTesting asks AppKit for a CGImage.
			let bitmap = renderer.cgImage!
			let image = NSImage(
				cgImage: bitmap,
				size: CGSize(width: bitmap.width, height: bitmap.height),
			)

			// DocC resources are also the references: no copied images to drift out of sync.
			let directory = URL(fileURLWithPath: "\(file)")
				.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
				.appendingPathComponent("Sources/SimpleHTML/SimpleHTML.docc/Resources")
			// ImageRenderer's color conversion can round a channel by one byte across
			// graphics backends. Require every pixel to match within a small color delta.
			if let failure = verifySnapshot(
				of: image, as: .image(perceptualPrecision: 0.99), named: name,
				snapshotDirectory: directory.path,
				file: file, testName: "documentation", line: line,
			) {
				Issue.record("\(failure)")
			}
		}
	}
#endif
