# Contributing to SimpleHTML

Contributions are welcome, whether that means reporting an unexpected result, improving an example, or implementing a fix. For larger changes, open an issue first so we can discuss the approach. A small HTML fixture and a failing test are especially useful for parsing bugs.

By participating in this project, you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).

## Development

Use Xcode with a Swift 6.2 or newer toolchain. Open `Package.swift` in Xcode or work with Swift Package Manager from the command line. The package uses the system's libxml2 and includes a C target that forwards SAX errors to Swift.

Keep parsing, attributed-string construction, and view rendering separate. Changes to supported HTML should include tests of the generated attributes; layout changes should be checked against HTML and Markdown inputs. Use Swift Testing for new tests. Do not use `.serialized` to work around flaky tests.

Run `bin/format` and `bin/lint` before committing. Both use package plugins with pinned tool versions, so no separate formatter or linter installation is needed. SwiftFormat covers Swift sources and tests; SwiftLint checks the package manifest and production sources for forced casts, forced tries, forced unwraps, and unsafe concurrency overrides.

GitHub Actions runs the full macOS test suite on the `xcode-27` preview runner, matching the macOS 27 snapshot baseline, and the full iOS suite on an iPhone 17 simulator running iOS 26.5 with Xcode 26.6. Tests and lint run for pull requests and pushes to `main`. A separate workflow formats branch pushes and commits any Swift formatting changes using the repository's default token. All three workflows also support manual runs.

## Running tests

Run the macOS tests with:

```sh
swift test
```

Run the iOS tests with:

```sh
xcodebuild -scheme SimpleHTML \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  IPHONEOS_DEPLOYMENT_TARGET=16.0 test
```

The test suite includes parsing and whitespace tests, block-layout tests, and image snapshots. The iOS test build targets iOS 16 because the snapshot cases exercise SwiftUI's view-level bold and italic modifiers. The library continues to support iOS 15. Snapshot rendering depends on OS fonts, so use the baseline platform versions when comparing images.

## Snapshot tests

`BlockTextViewSnapshotTests` records separate macOS and iOS images for both HTML and Markdown. One light/dark pair covers appearance; the remaining cases run in light mode. Cases cover small, large, XXXL, and accessibility Dynamic Type sizes; font, bold/italic, monospaced text, foreground color, tint, line spacing, and multiline alignment; and a narrow layout. Fixtures include wrapped text, links, three levels of lists, continuation paragraphs, and repeated content.

The iOS references were recorded on an iPhone 17 simulator running iOS 26.5 at a fixed 2× display scale. The macOS references were recorded on macOS 27.0.1, also at 2×. The macOS helper creates a bitmap at that scale so tests do not depend on whether the machine has a Retina display. Dynamic Type sizes affect the iOS references; macOS currently keeps the same text size.

To intentionally update the baselines:

1. Temporarily change the suite trait to `@Suite(.snapshots(record: .all))` in `Tests/SimpleHTMLTests/BlockTextViewSnapshotTests.swift`.
2. Run the tests on both baseline platforms.
3. Inspect the generated PNGs in `Tests/SimpleHTMLTests/__Snapshots__/BlockTextViewSnapshotTests/` and confirm that the changes match the intended behavior.
4. Restore `.snapshots(record: .never)` and include the reviewed images with the change.

Do not regenerate snapshots just to make an unexplained failure pass. Investigate whether the cause is a layout change, platform rendering, or a test issue.

## Documentation snapshots

`DocumentationSnapshotTests` is a separate macOS suite focused on presentation assets for selected README, API, and customization examples. It uses public APIs and mirrors the documented snippets. Keep those bodies in sync when editing an example. Parsing-only examples do not need images.

The suite renders content-sized canvases rendered directly by SwiftUI at 4× pixel density with a 16-point margin, a white background, a thin gray border, and fixed light appearance and locale. References were recorded on macOS 27.0.1. The suite's PNGs in `Sources/SimpleHTML/SimpleHTML.docc/Resources/` are both the snapshot baselines and the published assets; README links to the same files.

To regenerate them, temporarily set this suite's trait to `.snapshots(record: .all)`, then run:

```sh
swift test --filter DocumentationSnapshotTests
```

Recording reports test failures while writing the images. Inspect every changed image for legibility, clipping, spacing, and its correspondence to the example. Restore `.snapshots(record: .never)` and rerun the command to verify the references. Include the reviewed PNGs with the documentation change.

The embedded-media article uses three manually captured images: `documentation.embedded-image.png`, `documentation.youtube-embed.png`, and `documentation.embedded-media.png`. Capture the loaded photo and YouTube player using the same light appearance, body font, 16-point margin, white canvas, gray border, and 4× resolution. These assets are not snapshot-test baselines because rendering the media requires a live network connection. Inspect refreshed captures before including them in the catalog.

## Documentation

Public API comments and `Sources/SimpleHTML/SimpleHTML.docc` build together as DocC documentation. Keep the README focused on choosing and using the package; component details and customization recipes belong in DocC. Keep Markdown paragraphs on a single line.

In Xcode, select the SimpleHTML scheme and use **Product > Build Documentation**. To validate the catalog from the command line without an additional plugin:

```sh
swift package dump-symbol-graph
mkdir -p .build/docc-symbols
cp .build/out/symbolgraph/SimpleHTML*.json .build/docc-symbols/
xcrun docc convert Sources/SimpleHTML/SimpleHTML.docc \
  --additional-symbol-graph-dir .build/docc-symbols \
  --output-path .build/SimpleHTML.doccarchive \
  --warnings-as-errors
```

Check symbol links and compile examples against the public module, without `@testable import`. Examples should illustrate the package's actual behavior and make app-specific policies explicit.
