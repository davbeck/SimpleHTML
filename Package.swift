// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "SimpleHTML",
	platforms: [
		.macOS(.v12),
		.iOS(.v15),
	],
	products: [
		// Products define the executables and libraries a package produces, and make them visible to other packages.
		.library(
			name: "SimpleHTML",
			targets: ["SimpleHTML"]
		),
	],
	dependencies: [
	],
	targets: [
		// Targets are the basic building blocks of a package. A target can define a module or a test suite.
		// Targets can depend on other targets in this package, and on products in packages this package depends on.
		.target(
			name: "SAXErrorHandler"
		),
		.target(
			name: "SimpleHTML",
			dependencies: [
				"SAXErrorHandler",
			],
			swiftSettings: [
				.enableUpcomingFeature("ConciseMagicFile"),
				.enableUpcomingFeature("BareSlashRegexLiterals"),
				.enableUpcomingFeature("ExistentialAny"),
				.enableUpcomingFeature("ForwardTrailingClosures"),
				.enableUpcomingFeature("StrictConcurrency"),
			]
		),
		.testTarget(
			name: "SimpleHTMLTests",
			dependencies: ["SimpleHTML"]
		),
	]
)
