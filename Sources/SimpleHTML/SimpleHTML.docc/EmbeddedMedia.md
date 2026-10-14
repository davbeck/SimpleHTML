# Displaying images and YouTube embeds

Split parsed HTML into text and media sections, then render each section with SwiftUI or WebKit.

## Overview

``HTMLView`` and ``BlockTextView`` render text, paragraphs, and lists. To display `img` tags and YouTube `iframe` embeds, supply a custom renderer through ``HTMLView``'s content closure. SimpleHTML preserves the information needed to build it:

| Tag | Generated content | Media metadata |
| --- | --- | --- |
| `img` | The `alt` value, or U+FFFC when it is empty | `run.imageURL` and `run.html.element` |
| `iframe` | A U+FFFC placeholder | `run.html.element`, including its `src` and `title` attributes |

Both elements expose numeric dimensions through ``HTMLElement/width`` and ``HTMLElement/height``. An iframe's URL is available through ``HTMLElement/src``; there is no separate `embedURL` attribute in SimpleHTML. The package parses this metadata synchronously; your app handles downloading images and loading the player.

The examples below form a renderer for iOS 15 and macOS 12 or newer. They treat media as separate blocks, including an image placed inside a paragraph. For small inline images such as custom emoji, see <doc:CustomizingHTML> instead.

## Split text from media

Accumulate ordinary text until a media element appears. Passing each accumulated section to ``BlockTextView`` preserves its inline formatting and paragraph or list intents. Group by ``HTMLElementAttribute`` rather than by URL, so two adjacent images with the same source remain separate elements.

```swift
import Foundation
import SimpleHTML
import SwiftUI

enum HTMLMediaPart {
    case text(AttributedString)
    case image(url: URL, element: HTMLElement)
    case youtube(url: URL, element: HTMLElement)
}

func sourceURL(for element: HTMLElement, baseURL: URL) -> URL? {
    guard let source = element.attributes["src"],
          let url = URL(string: source, relativeTo: baseURL)?.absoluteURL,
          url.scheme?.lowercased() == "https" else { return nil }
    return url
}

func isYouTubeEmbed(_ url: URL) -> Bool {
    let hosts = [
        "youtube.com", "www.youtube.com",
        "youtube-nocookie.com", "www.youtube-nocookie.com"
    ]
    return hosts.contains(url.host?.lowercased() ?? "")
        && url.pathComponents.count == 3
        && url.pathComponents[1] == "embed"
}

func mediaParts(from original: AttributedString, baseURL: URL) -> [HTMLMediaPart] {
    var parts: [HTMLMediaPart] = []
    var pendingText = AttributedString()

    func flushText() {
        if !pendingText.characters.isEmpty {
            parts.append(.text(pendingText))
            pendingText = AttributedString()
        }
    }

    for (element, range) in original.runs[HTMLElementAttribute.self] {
        guard let element else {
            pendingText.append(original[range])
            continue
        }

        switch element.name {
        case "img":
            flushText()
            if let url = sourceURL(for: element, baseURL: baseURL) {
                parts.append(.image(url: url, element: element))
            } else {
                let alt = element.attributes["alt"] ?? ""
                parts.append(.text(AttributedString(alt.isEmpty ? "Image unavailable" : alt)))
            }
        case "iframe":
            flushText()
            let url = sourceURL(for: element, baseURL: baseURL)
            if let url, isYouTubeEmbed(url) {
                parts.append(.youtube(url: url, element: element))
            } else {
                var fallback = AttributedString(element.attributes["title"] ?? "Embedded content")
                fallback.link = url
                parts.append(.text(fallback))
            }
        default:
            pendingText.append(original[range])
        }
    }
    flushText()
    return parts
}
```

Use the document's HTTPS URL as `baseURL`. This resolves sources such as `/images/photo.jpg` and `//www.youtube.com/embed/VIDEO_ID`, which ``HTMLElement/src`` and `imageURL` do not resolve on their own. This example accepts HTTPS media and plays only YouTube URLs with an `/embed/VIDEO_ID` path. Unsupported iframes become a link when they have an accepted source URL; missing sources become text. These are explicit app policies you can adapt to your content.

The text buffer spans formatting runs and consecutive paragraphs. Rendering every ordinary run as its own view would put bold words and links into separate blocks. Splitting at media can still divide a paragraph or list item: a renderer that keeps media inside list indentation needs to group by the enclosing presentation intents and lay out those children itself. This example is intended for documents with media between text sections.

## Load and size images

Use the HTML dimensions as an aspect ratio rather than fixed points, so large images fit the available width. A percentage such as `width="100%"` is not numeric; when dimensions are missing, let the loaded image supply its natural ratio.

```swift
extension HTMLElement {
    var mediaAspectRatio: CGFloat? {
        guard let width, let height,
              width.isFinite, height.isFinite,
              width > 0, height > 0 else { return nil }
        return CGFloat(width / height)
    }
}

struct HTMLRemoteImage: View {
    let url: URL
    let element: HTMLElement

    private var alt: String { element.attributes["alt"] ?? "" }

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 80)
            case .success(let image):
                image.resizable()
                    .aspectRatio(element.mediaAspectRatio, contentMode: .fit)
            case .failure:
                Text(alt.isEmpty ? "Image unavailable" : alt)
            @unknown default:
                Text(alt.isEmpty ? "Image unavailable" : alt)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(Text(alt))
        .accessibilityHidden(alt.isEmpty)
    }
}
```

The image's `alt` text supplies its accessibility label and a fallback if loading fails. Empty alt text treats the image as decorative. This example uses [SwiftUI's AsyncImage](https://sosumi.ai/documentation/swiftui/asyncimage); replace it with your app's image loader when you need authenticated requests, animated images, or control over caching. You can also reserve an aspect-ratio placeholder to reduce layout changes while downloading.

![A photo of a mountain trail displayed below a paragraph with bold text.](documentation.embedded-image.png)

## Load a YouTube player with WebKit

Load the accepted iframe's source URL in a `WKWebView`. Add `playsinline=1` to the URL and enable [allowsInlineMediaPlayback](https://sosumi.ai/documentation/webkit/wkwebviewconfiguration/allowsinlinemediaplayback) on iOS. Together these allow inline playback, as described in [YouTube's player parameters](https://developers.google.com/youtube/player_parameters#playsinline).

YouTube also requires app identification through the HTTP `Referer` header. For a native app, use an HTTPS URL whose host is the app's registered bundle identifier, lowercased. The request below follows [YouTube's WebView integration guidance](https://developers.google.com/youtube/terms/required-minimum-functionality#embedded-player-api-client-identity). Pass your app's actual bundle identifier; a website URL used to resolve images is a different value. Missing identification can produce [player error 153](https://developers.google.com/youtube/iframe_api_reference#onError).

```swift
import WebKit

func youtubeRequest(url: URL, appBundleID: String) -> URLRequest {
    var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
    var items = components.queryItems ?? []
    items.removeAll { $0.name == "playsinline" }
    items.append(URLQueryItem(name: "playsinline", value: "1"))
    components.queryItems = items

    var request = URLRequest(url: components.url!)
    request.setValue("https://\(appBundleID.lowercased())", forHTTPHeaderField: "Referer")
    return request
}

@MainActor
final class YouTubeLoadCoordinator {
    private var currentRequest: URLRequest?

    func load(_ request: URLRequest, in webView: WKWebView) {
        guard request != currentRequest else { return }
        currentRequest = request
        webView.load(request)
    }
}

#if os(iOS)
struct YouTubeWebView: UIViewRepresentable {
    let request: URLRequest

    func makeCoordinator() -> YouTubeLoadCoordinator { YouTubeLoadCoordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        return WKWebView(frame: .zero, configuration: configuration)
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.load(request, in: webView)
    }
}
#elseif os(macOS)
struct YouTubeWebView: NSViewRepresentable {
    let request: URLRequest

    func makeCoordinator() -> YouTubeLoadCoordinator { YouTubeLoadCoordinator() }

    func makeNSView(context: Context) -> WKWebView {
        WKWebView(frame: .zero)
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.load(request, in: webView)
    }
}
#endif
```

The coordinator remembers the last requested URL and headers. Comparing with `webView.url` would compare against the player's current navigation URL, which may have redirected. Loading on every SwiftUI update would restart playback. The force unwraps in `youtubeRequest` rely on the splitter supplying a resolved HTTPS YouTube URL; validate separately if calling it with arbitrary input.

The wrapper loads the player directly, so HTML attributes such as `allowfullscreen`, `frameborder`, and `allow` are not copied into another iframe. WebKit supplies the web content and playback controls. For custom playback events, use the [YouTube IFrame Player API](https://developers.google.com/youtube/iframe_api_reference) in a wrapper HTML document and bridge the events into your app.

![The WWDC 2014 keynote in a loaded YouTube player below Watch the video.](documentation.youtube-embed.png)

## Assemble the document view

Display the parts in source order, using ``BlockTextView`` for text and dedicated views for media. Use positions as view identities so repeated images and identical text sections both render. These positions assume the same document remains on screen; for editable content, give parts persistent identifiers in your model.

```swift
struct HTMLMediaView: View {
    let parts: [HTMLMediaPart]
    let appBundleID: String
    @ScaledMetric(relativeTo: .body) private var spacing = 12

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                switch part {
                case .text(let text):
                    BlockTextView(attributedString: text)
                case .image(let url, let element):
                    HTMLRemoteImage(url: url, element: element)
                case .youtube(let url, let element):
                    YouTubeWebView(request: youtubeRequest(url: url, appBundleID: appBundleID))
                        .aspectRatio(element.mediaAspectRatio ?? 16.0 / 9.0, contentMode: .fit)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ArticleView: View {
    let html = """
        <p>A <strong>photo</strong> from our trip:</p>
        <p><img src="/images/trip.jpg" width="2560" height="1920" alt="A trail through the mountains"></p>
        <p>Watch the video:</p>
        <figure><iframe src="//www.youtube.com/embed/w87fOAG8fjk" width="640" height="360" title="WWDC 2014 keynote" allowfullscreen></iframe></figure>
        <p>Read <a href="https://example.com/articles/trip">the full story</a>.</p>
        """

    var body: some View {
        ScrollView {
            HTMLView(html: html) { text in
                HTMLMediaView(
                    parts: mediaParts(from: text, baseURL: URL(string: "https://example.com/articles/trip")!),
                    appBundleID: Bundle.main.bundleIdentifier!
                )
            }
            .font(.body)
            .tint(.blue)
            .padding()
        }
    }
}
```

Replace the example image URL with an image served by your app's content source. The `Bundle.main.bundleIdentifier` unwrap assumes this view runs in an app with a registered bundle identifier; previews and other hosts can pass that identifier explicitly.

The iframe uses the embed URL for the [WWDC 2014 keynote](https://www.youtube.com/watch?v=w87fOAG8fjk).

![An HTML article with formatted text, a mountain photo, the WWDC 2014 keynote player, and a link.](documentation.embedded-media.png)

These screenshots use the National Park Service's public-domain [Mount Rainier from Alta Vista photograph](https://npgallery.nps.gov/AssetDetail/947e513e-cc4c-8d60-7840-e3c4f75ba176) in place of `/images/trip.jpg`. They were captured manually after the photo and player loaded, using the same canvas styling as the other documentation images.

The iframe dimensions establish the preferred ratio, with 16:9 as the fallback for missing or percentage dimensions. Ensure the actual player viewport is at least 200 by 200 CSS pixels; use a link in layouts too small to display the player. See [YouTube's player sizing guidance](https://developers.google.com/youtube/player_parameters#Overview).

``HTMLView`` reparses when its body is evaluated. For repeated content, create the attributed string and parts once in your model, then pass them to `HTMLMediaView`. Text sections keep their existing attributes; the separate media views use the original elements for URLs, dimensions, and accessibility text.
