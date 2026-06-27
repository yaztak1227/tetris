import XCTest
@testable import TetrisCore

final class GarbageCalculatorTests: XCTestCase {
    func testCalculatesAttackFromClearEvent() {
        let event = ClearEvent(
            clearedLines: 2,
            spin: .tSpin,
            clearName: .tSpinDouble,
            scoreDelta: 1_200,
            attack: 0,
            combo: 0,
            backToBack: true,
            backToBackBonusApplied: false
        )

        let result = GarbageCalculator.standard.calculate(event: event, incomingGarbage: [])

        XCTAssertEqual(result.outgoingAttack, 4)
        XCTAssertEqual(result.canceledIncoming, 0)
        XCTAssertEqual(result.remainingIncoming, [])
    }

    func testBackToBackAndComboAddAttackThenCancelIncomingGarbage() {
        let event = ClearEvent(
            clearedLines: 4,
            spin: .none,
            clearName: .tetris,
            scoreDelta: 1_200,
            attack: 0,
            combo: 3,
            backToBack: true,
            backToBackBonusApplied: true
        )

        let result = GarbageCalculator.standard.calculate(
            event: event,
            incomingGarbage: [GarbageLine(holeColumn: 4), GarbageLine(holeColumn: 5)]
        )

        XCTAssertEqual(result.outgoingAttack, 5)
        XCTAssertEqual(result.canceledIncoming, 2)
        XCTAssertEqual(result.remainingIncoming, [])
    }
}
