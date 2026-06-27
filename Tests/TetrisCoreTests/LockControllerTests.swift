import XCTest
@testable import TetrisCore

final class LockControllerTests: XCTestCase {
    func testGroundingStartsLockDelayWithoutImmediateLock() {
        var controller = LockController(settings: LockSettings(lockDelayMilliseconds: 500, maxResets: 15))

        let decision = controller.update(canMoveDown: false, deltaMilliseconds: 100)

        XCTAssertEqual(decision, .wait)
        XCTAssertTrue(controller.isGrounded)
        XCTAssertEqual(controller.elapsedMilliseconds, 100)
    }

    func testLockDelayExpiresWhenGroundedLongEnough() {
        var controller = LockController(settings: LockSettings(lockDelayMilliseconds: 500, maxResets: 15))

        _ = controller.update(canMoveDown: false, deltaMilliseconds: 250)
        let decision = controller.update(canMoveDown: false, deltaMilliseconds: 250)

        XCTAssertEqual(decision, .lock)
    }

    func testSuccessfulGroundedAdjustmentResetsDelayUpToLimit() {
        var controller = LockController(settings: LockSettings(lockDelayMilliseconds: 500, maxResets: 2))
        _ = controller.update(canMoveDown: false, deltaMilliseconds: 400)

        XCTAssertTrue(controller.recordSuccessfulAdjustment())

        XCTAssertEqual(controller.elapsedMilliseconds, 0)
        XCTAssertEqual(controller.resetCount, 1)
        XCTAssertEqual(controller.update(canMoveDown: false, deltaMilliseconds: 400), .wait)
    }

    func testResetLimitForcesLockWhenStillGrounded() {
        var controller = LockController(settings: LockSettings(lockDelayMilliseconds: 500, maxResets: 1))
        _ = controller.update(canMoveDown: false, deltaMilliseconds: 100)
        XCTAssertTrue(controller.recordSuccessfulAdjustment())

        XCTAssertFalse(controller.recordSuccessfulAdjustment())

        XCTAssertEqual(controller.update(canMoveDown: false, deltaMilliseconds: 0), .lock)
    }

    func testLeavingGroundClearsLockDelayState() {
        var controller = LockController(settings: LockSettings(lockDelayMilliseconds: 500, maxResets: 15))
        _ = controller.update(canMoveDown: false, deltaMilliseconds: 300)

        let decision = controller.update(canMoveDown: true, deltaMilliseconds: 16)

        XCTAssertEqual(decision, .wait)
        XCTAssertFalse(controller.isGrounded)
        XCTAssertEqual(controller.elapsedMilliseconds, 0)
        XCTAssertEqual(controller.resetCount, 0)
    }
}
