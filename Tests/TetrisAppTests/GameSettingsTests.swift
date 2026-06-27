import XCTest
@testable import TetrisApp

final class GameSettingsTests: XCTestCase {
    func testDefaultBindingsMapCoreGameplayKeys() {
        let settings = GameSettings()

        XCTAssertEqual(settings.action(for: "return"), .start)
        XCTAssertEqual(settings.action(for: "left"), .moveLeft)
        XCTAssertEqual(settings.action(for: "right"), .moveRight)
        XCTAssertEqual(settings.action(for: "up"), .rotateClockwise)
        XCTAssertEqual(settings.action(for: "x"), .rotateClockwise)
        XCTAssertEqual(settings.action(for: "z"), .rotateCounterClockwise)
        XCTAssertEqual(settings.action(for: "space"), .hardDrop)
        XCTAssertEqual(settings.action(for: "escape"), .pause)
    }

    func testRebindingAKeyRemovesItFromPreviousAction() {
        var settings = GameSettings()

        settings.bind("return", to: .pause)

        XCTAssertNil(settings.action(for: "escape"))
        XCTAssertEqual(settings.action(for: "return"), .pause)
    }

    func testLocalizedDisplayBindingTracksLanguageAfterSettingsChange() throws {
        var settings = GameSettings()
        settings.bind("space", to: .start)
        let japanese = try AppLocalizer.load(language: .japanese)

        XCTAssertEqual(settings.displayBinding(for: .start, localizer: japanese), "スペース")
    }

    func testUserDefaultsStorePersistsTuningAndKeyBindings() throws {
        let suiteName = "GameSettingsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = UserDefaultsGameSettingsStore(defaults: defaults, key: "settings")
        var settings = GameSettings()
        settings.gravityMultiplier = 1.8
        settings.horizontalAutoShiftDelayMilliseconds = 420
        settings.bind("space", to: .start)

        store.save(settings)
        let restored = try XCTUnwrap(store.load())

        XCTAssertEqual(restored.gravityMultiplier, 1.8)
        XCTAssertEqual(restored.horizontalAutoShiftDelayMilliseconds, 420)
        XCTAssertEqual(restored.action(for: "space"), .start)
    }
}
