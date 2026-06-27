import XCTest
@testable import TetrisApp

final class AppLocalizerTests: XCTestCase {
    func testLoadsBundledLanguageFiles() throws {
        let english = try AppLocalizer.load(language: .english)
        let japanese = try AppLocalizer.load(language: .japanese)

        XCTAssertEqual(english.text("settings/title"), "Settings")
        XCTAssertEqual(japanese.text("settings/title"), "設定")
    }

    func testFallsBackToEnglishBeforeReturningKey() throws {
        let localizer = AppLocalizer(
            language: .japanese,
            strings: ["home/buttons/start": "開始"],
            fallbackStrings: ["home/buttons/settings": "Settings"]
        )

        XCTAssertEqual(localizer.text("home/buttons/start"), "開始")
        XCTAssertEqual(localizer.text("home/buttons/settings"), "Settings")
        XCTAssertEqual(localizer.text("missing/key"), "missing/key")
    }

    func testLanguageDisplayNamesAreLocalized() throws {
        let localizer = try AppLocalizer.load(language: .japanese)

        XCTAssertEqual(localizer.languageName(.english), "English")
        XCTAssertEqual(localizer.languageName(.japanese), "日本語")
    }

    func testJapaneseSpecialKeyNamesAreLocalized() throws {
        let localizer = try AppLocalizer.load(language: .japanese)

        XCTAssertEqual(GameSettings.displayName(for: "space", localizer: localizer), "スペース")
        XCTAssertEqual(GameSettings.displayName(for: "shift", localizer: localizer), "シフト")
        XCTAssertEqual(GameSettings.displayName(for: "return", localizer: localizer), "リターン")
        XCTAssertEqual(GameSettings.displayName(for: "escape", localizer: localizer), "Esc")
    }

    func testLoadOrFallbackUsesBuiltInSelectedLanguageWhenBundleResourcesAreMissing() throws {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let localizationsURL = bundleURL.appendingPathComponent("Localizations", isDirectory: true)
        try FileManager.default.createDirectory(
            at: localizationsURL,
            withIntermediateDirectories: true
        )
        try #"{"settings/title":"Settings"}"#.write(
            to: localizationsURL.appendingPathComponent("en.json"),
            atomically: true,
            encoding: .utf8
        )
        defer {
            try? FileManager.default.removeItem(at: bundleURL)
        }
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))

        let localizer = AppLocalizer.loadOrFallback(language: .japanese, bundle: bundle)

        XCTAssertEqual(localizer.language, .japanese)
        XCTAssertEqual(localizer.text("settings/title"), "設定")
    }

    func testStoredLanguageCodeTakesPriorityOverPreferredLanguage() {
        XCTAssertEqual(AppLanguage.resolved(storedCode: "ja"), .japanese)
        XCTAssertEqual(AppLanguage.resolved(storedCode: "en"), .english)
    }

    func testInvalidStoredLanguageFallsBackToPreferredLanguage() {
        XCTAssertEqual(
            AppLanguage.resolved(storedCode: "unknown", preferred: .japanese),
            .japanese
        )
    }
}
