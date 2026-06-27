import XCTest
@testable import TetrisCore

final class ScoringTests: XCTestCase {
    func testTSpinDoubleStartsBackToBackAndScoresWithLevelMultiplier() {
        let result = ScoringSystem.standard.score(
            ScoreInput(
                spin: .tSpin,
                clearedLines: 2,
                hardDropCells: 0,
                softDropCells: 0,
                previousCombo: -1,
                previousBackToBack: false,
                level: 2
            )
        )

        XCTAssertEqual(result.clearName, .tSpinDouble)
        XCTAssertEqual(result.scoreDelta, 2_400)
        XCTAssertEqual(result.nextCombo, 0)
        XCTAssertTrue(result.nextBackToBack)
        XCTAssertFalse(result.backToBackBonusApplied)
    }

    func testBackToBackTetrisAppliesBonusAndComboIncrements() {
        let result = ScoringSystem.standard.score(
            ScoreInput(
                spin: .none,
                clearedLines: 4,
                hardDropCells: 3,
                softDropCells: 2,
                previousCombo: 0,
                previousBackToBack: true,
                level: 1
            )
        )

        XCTAssertEqual(result.clearName, .tetris)
        XCTAssertEqual(result.scoreDelta, 1_208)
        XCTAssertEqual(result.nextCombo, 1)
        XCTAssertTrue(result.nextBackToBack)
        XCTAssertTrue(result.backToBackBonusApplied)
    }

    func testNonClearResetsComboButKeepsBackToBack() {
        let result = ScoringSystem.standard.score(
            ScoreInput(
                spin: .none,
                clearedLines: 0,
                hardDropCells: 0,
                softDropCells: 0,
                previousCombo: 3,
                previousBackToBack: true,
                level: 1
            )
        )

        XCTAssertEqual(result.clearName, .none)
        XCTAssertEqual(result.nextCombo, -1)
        XCTAssertTrue(result.nextBackToBack)
    }
}
