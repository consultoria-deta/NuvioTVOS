import XCTest
@testable import NuvioTV

/// Native Player external-player handoff: deep-link building, x-callback progress
/// form, and best-complete-subtitle-first ordering. Lives in its own file because
/// StreamQualityTagsTests.swift is excluded from the test target's Sources.
final class NativePlayerExternalTests: XCTestCase {
    func testNativePlayerLaunchURLCarriesPercentEncodedName() {
        let stream = URL(string: "https://cdn.example/movie.mkv?token=a&b=c")!
        let sub = URL(string: "https://subs.example/en.srt")!
        let launch = ExternalPlayer.nativePlayer.launchURL(
            for: stream,
            subtitleURLs: [sub],
            title: "Lawrence of Arabia"
        )!

        XCTAssertTrue(launch.absoluteString.starts(with: "nativeplayer://play?url="))
        XCTAssertTrue(launch.absoluteString.contains("name=Lawrence%20of%20Arabia"))
        XCTAssertTrue(launch.absoluteString.contains("sub=https%3A%2F%2Fsubs.example%2Fen.srt"))
        XCTAssertFalse(launch.absoluteString.contains("movie.mkv?token"))
    }

    func testNativePlayerLaunchURLCarriesResumePosition() {
        // Native Player resumes an externally-launched URL only if the caller sends
        // the start time (dev u/lexqqq), the same `position=<seconds>` Infuse takes.
        let stream = URL(string: "https://cdn.example/movie.mkv")!
        let launch = ExternalPlayer.nativePlayer.launchURL(
            for: stream,
            position: 754.0,
            title: "Movie"
        )!
        XCTAssertTrue(launch.absoluteString.contains("position=754"))
    }

    func testNativePlayerLaunchURLOmitsZeroPosition() {
        let stream = URL(string: "https://cdn.example/movie.mkv")!
        let launch = ExternalPlayer.nativePlayer.launchURL(
            for: stream,
            position: 0,
            title: "Movie"
        )!
        XCTAssertFalse(launch.absoluteString.contains("position="))
    }

    func testNativePlayerUsesXCallbackFormWhenCallbacksPresent() {
        let stream = URL(string: "https://cdn.example/movie.mkv")!
        let success = URL(string: "nuvio-tv://external-playback/ABC-123")!
        let error = URL(string: "nuvio-tv://external-playback/error/ABC-123")!

        let plain = ExternalPlayer.nativePlayer.launchURL(for: stream, title: "Movie")!
        XCTAssertTrue(plain.absoluteString.starts(with: "nativeplayer://play?url="))
        XCTAssertFalse(plain.absoluteString.contains("x-success"))

        let cb = ExternalPlayer.nativePlayer.launchURL(
            for: stream,
            title: "Movie",
            successURL: success,
            errorURL: error
        )!
        XCTAssertTrue(cb.absoluteString.starts(with: "nativeplayer://x-callback-url/play?url="))
        XCTAssertTrue(cb.absoluteString.contains("x-success=nuvio-tv%3A%2F%2Fexternal-playback%2FABC-123"))
        XCTAssertTrue(cb.absoluteString.contains("x-error=nuvio-tv%3A%2F%2Fexternal-playback%2Ferror%2FABC-123"))
        XCTAssertFalse(cb.absoluteString.contains("x-success=nuvio-tv://"))
    }

    func testBestCompleteSubtitleFirstSinksForcedAndPrefersLanguage() {
        let subs = [
            NuvioSubtitle(url: "u1", language: "English", label: "English (Forced)"),
            NuvioSubtitle(url: "u2", language: "Spanish", label: "Español"),
            NuvioSubtitle(url: "u3", language: "en", label: "English"),
            NuvioSubtitle(url: "u4", language: "English", label: "Foreign Parts Only"),
        ]
        let ordered = SubtitleLanguagePreferences.bestCompleteFirst(subs, preferredLanguages: ["English"])

        XCTAssertEqual(ordered.count, 4, "nothing dropped — forced sinks, not removed")
        XCTAssertEqual(ordered.first?.url, "u3", "first = complete English (preferred language)")
        XCTAssertTrue(["u1", "u4"].contains(ordered.last?.url ?? ""), "a forced track is last")
        let completeSpanish = ordered.firstIndex { $0.url == "u2" }!
        let forcedEnglish = ordered.firstIndex { $0.url == "u1" }!
        XCTAssertLessThan(completeSpanish, forcedEnglish, "complete (any lang) beats forced")
    }

    func testBestCompleteSubtitleFirstDedupsAndKeepsSingletons() {
        let dup = [
            NuvioSubtitle(url: "same", language: "en", label: "English"),
            NuvioSubtitle(url: "same", language: "en", label: "English"),
        ]
        XCTAssertEqual(SubtitleLanguagePreferences.bestCompleteFirst(dup, preferredLanguages: ["English"]).count, 1)
        let one = [NuvioSubtitle(url: "only", language: "en", label: "English")]
        XCTAssertEqual(SubtitleLanguagePreferences.bestCompleteFirst(one, preferredLanguages: []).map(\.url), ["only"])
    }
}
