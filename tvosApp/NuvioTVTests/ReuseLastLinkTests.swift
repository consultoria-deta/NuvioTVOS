import XCTest
@testable import NuvioTV

/// Reuse Last Link (Android TV parity): the stored link honours the configured
/// cache window, the settings parse/clamp synced values, and both keys sync.
final class ReuseLastLinkTests: XCTestCase {
    private var suiteName: String!
    private var store: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "ReuseLastLinkTests-\(UUID().uuidString)"
        store = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        store.removePersistentDomain(forName: suiteName)
        store = nil
        suiteName = nil
        super.tearDown()
    }

    func testStoredRemoteLinkHonoursMaxAge() {
        let metaId = "tt-reuse-\(UUID().uuidString)"
        let savedAt = Date(timeIntervalSince1970: 1_000_000)
        LastPlaybackStreamStore.save(
            metaId: metaId,
            url: "https://cdn.example/movie.mkv",
            season: nil,
            episode: nil,
            savedAt: savedAt
        )
        defer { LastPlaybackStreamStore.remove(metaId: metaId, season: nil, episode: nil) }

        // 10 h later: past the legacy 2 h TTL but inside a 24 h window.
        let tenHoursLater = savedAt.addingTimeInterval(10 * 3600)
        XCTAssertEqual(
            LastPlaybackStreamStore.load(
                metaId: metaId,
                season: nil,
                episode: nil,
                now: tenHoursLater,
                maxAge: 24 * 3600
            )?.url,
            "https://cdn.example/movie.mkv"
        )

        // Outside the window the link expires (and is evicted).
        let twoDaysLater = savedAt.addingTimeInterval(48 * 3600)
        XCTAssertNil(
            LastPlaybackStreamStore.load(
                metaId: metaId,
                season: nil,
                episode: nil,
                now: twoDaysLater,
                maxAge: 24 * 3600
            )
        )
        XCTAssertNil(LastPlaybackStreamStore.load(metaId: metaId, season: nil, episode: nil, now: tenHoursLater))
    }

    func testDefaultMaxAgeKeepsLegacyTwoHourTTL() {
        let metaId = "tt-reuse-\(UUID().uuidString)"
        let savedAt = Date(timeIntervalSince1970: 2_000_000)
        LastPlaybackStreamStore.save(
            metaId: metaId,
            url: "https://cdn.example/episode.mkv",
            season: 1,
            episode: 2,
            savedAt: savedAt
        )
        defer { LastPlaybackStreamStore.remove(metaId: metaId, season: 1, episode: 2) }

        XCTAssertNil(
            LastPlaybackStreamStore.load(
                metaId: metaId,
                season: 1,
                episode: 2,
                now: savedAt.addingTimeInterval(3 * 3600)
            )
        )
    }

    func testSettingsDefaultsWhenUnset() {
        XCTAssertFalse(ReuseLastLinkSettings.isEnabled(store))
        XCTAssertEqual(ReuseLastLinkSettings.cacheHours(store), 24)
        XCTAssertEqual(ReuseLastLinkSettings.maxAge(store), 24 * 3600)
    }

    func testCacheHoursAcceptsSyncedShapesAndClamps() {
        store.set(48, forKey: SettingsKey.streamReuseLastLinkCacheHours)
        XCTAssertEqual(ReuseLastLinkSettings.cacheHours(store), 48)

        store.set(12.0, forKey: SettingsKey.streamReuseLastLinkCacheHours)
        XCTAssertEqual(ReuseLastLinkSettings.cacheHours(store), 12)

        store.set(" 6 ", forKey: SettingsKey.streamReuseLastLinkCacheHours)
        XCTAssertEqual(ReuseLastLinkSettings.cacheHours(store), 6)

        store.set(0, forKey: SettingsKey.streamReuseLastLinkCacheHours)
        XCTAssertEqual(ReuseLastLinkSettings.cacheHours(store), 1)

        store.set(1000, forKey: SettingsKey.streamReuseLastLinkCacheHours)
        XCTAssertEqual(ReuseLastLinkSettings.cacheHours(store), 168)

        store.set("abc", forKey: SettingsKey.streamReuseLastLinkCacheHours)
        XCTAssertEqual(ReuseLastLinkSettings.cacheHours(store), 24)
    }

    func testEnabledFlagReadsStoredBool() {
        store.set(true, forKey: SettingsKey.streamReuseLastLinkEnabled)
        XCTAssertTrue(ReuseLastLinkSettings.isEnabled(store))
    }

    func testBothKeysSyncWithAndroidWireNames() {
        let remoteToLocal = Dictionary(
            PlayerSettingsSyncMapper.remoteToLocalKeyMappings.map { ($0.remote, $0.local) },
            uniquingKeysWith: { first, _ in first }
        )
        XCTAssertEqual(remoteToLocal["stream_reuse_last_link_enabled"], SettingsKey.streamReuseLastLinkEnabled)
        XCTAssertEqual(remoteToLocal["stream_reuse_last_link_cache_hours"], SettingsKey.streamReuseLastLinkCacheHours)

        let localToRemote = Dictionary(
            PlayerSettingsSyncMapper.localToRemoteKeyMappings.map { ($0.local, $0.remote) },
            uniquingKeysWith: { first, _ in first }
        )
        XCTAssertEqual(localToRemote[SettingsKey.streamReuseLastLinkEnabled], "stream_reuse_last_link_enabled")
        XCTAssertEqual(localToRemote[SettingsKey.streamReuseLastLinkCacheHours], "stream_reuse_last_link_cache_hours")
    }
}
