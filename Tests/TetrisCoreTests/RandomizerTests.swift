import XCTest
@testable import TetrisCore

final class RandomizerTests: XCTestCase {
    func testSevenBagContainsEveryPieceOnceBeforeRepeating() {
        var randomizer = SevenBagRandomizer(seed: 42)

        let firstBag = (0..<7).map { _ in randomizer.next() }
        let secondBag = (0..<7).map { _ in randomizer.next() }

        XCTAssertEqual(Set(firstBag), Set(PieceType.allCases))
        XCTAssertEqual(Set(secondBag), Set(PieceType.allCases))
        XCTAssertEqual(firstBag.count, 7)
        XCTAssertEqual(secondBag.count, 7)
    }

    func testNextQueueMaintainsRequestedPreviewCountPlusActivePiece() {
        var randomizer = SevenBagRandomizer(seed: 7)
        var queue = NextQueue(randomizer: randomizer, visibleCount: 5)

        XCTAssertEqual(queue.preview.count, 5)

        _ = queue.popNext()

        XCTAssertEqual(queue.preview.count, 5)
        randomizer = queue.randomizer
        XCTAssertNotNil(randomizer.next() as PieceType?)
    }
}
