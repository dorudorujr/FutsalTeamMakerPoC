import XCTest

/// 結果の画面で、ドラッグして選手を入れ替えたり移したりできるかを確かめる。
/// 起動時に入れた「テスト大会」（12人）を2チームに分けるので、チームA・Bは6人ずつになる。
@MainActor
final class TeamResultDragTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// アプリを「テスト大会」を入れた状態で起動し、2チームに分けた結果の画面を開く
    private func openSplitResult() {
        app = XCUIApplication()
        app.launchArguments = ["-UITestInMemory", "-UITestSeedEvent"]
        app.launch()

        app.staticTexts["テスト大会"].tap()
        app.buttons["実力が均等になるように分ける"].tap()
        XCTAssertTrue(app.staticTexts["teamHeader.チームA"].waitForExistence(timeout: 5))
    }

    /// そのチームにいる選手の行（識別子は "member.名前"、値はチーム名）
    private func memberRows(in teamName: String) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'member.' AND value == %@", teamName)
        )
    }

    private func row(of identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    func testDragOntoPlayerOfOtherTeamSwaps() throws {
        openSplitResult()
        let dragged = memberRows(in: "チームA").firstMatch
        let target = memberRows(in: "チームB").firstMatch
        let draggedID = dragged.identifier
        let targetID = target.identifier

        dragged.press(forDuration: 1.0, thenDragTo: target)

        XCTAssertTrue(app.staticTexts["手で直した結果です。「分け直す」を押すと、自動で分け直します。"].waitForExistence(timeout: 3))
        XCTAssertEqual(row(of: draggedID).value as? String, "チームB")
        XCTAssertEqual(row(of: targetID).value as? String, "チームA")
        XCTAssertEqual(memberRows(in: "チームA").count, 6)
        XCTAssertEqual(memberRows(in: "チームB").count, 6)
    }

    func testDragOntoTeamNameMoves() throws {
        openSplitResult()
        let dragged = memberRows(in: "チームA").firstMatch
        let draggedID = dragged.identifier

        dragged.press(forDuration: 1.0, thenDragTo: app.staticTexts["teamHeader.チームB"])

        XCTAssertTrue(app.staticTexts["手で直した結果です。「分け直す」を押すと、自動で分け直します。"].waitForExistence(timeout: 3))
        XCTAssertEqual(row(of: draggedID).value as? String, "チームB")
        XCTAssertEqual(memberRows(in: "チームA").count, 5)
        XCTAssertEqual(memberRows(in: "チームB").count, 7)
    }

    /// 画面の下の端で止めると自動でスクロールし、画面の外のチームへも運べる
    func testAutoScrollsWhileDraggingNearBottomEdge() throws {
        openSplitResult()
        // 一度戻ってチーム数を4にし、画面の外にチームができるようにする
        app.navigationBars.buttons.firstMatch.tap()
        let stepper = app.steppers.firstMatch
        stepper.buttons.element(boundBy: 1).tap()
        stepper.buttons.element(boundBy: 1).tap()
        app.buttons["実力が均等になるように分ける"].tap()
        XCTAssertTrue(app.staticTexts["teamHeader.チームD"].waitForExistence(timeout: 5))

        let teamD = app.staticTexts["teamHeader.チームD"]
        let before = teamD.frame.minY
        let dragged = memberRows(in: "チームA").firstMatch
        // 下に「分け直す」「確定」の欄があるので、その少し上（スクロールする範囲の下の端）で止める
        let bottomEdge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.82))
        dragged.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
            .press(forDuration: 1.0, thenDragTo: bottomEdge, withVelocity: .slow, thenHoldForDuration: 3.0)
        // ドロップでチームの人数が変わっても、チームDより上の高さの合計は変わらない。
        // チームDが上へ動いていれば、ドラッグ中にスクロールしている
        XCTAssertLessThan(teamD.frame.minY, before - 40)
    }

    /// 手で直して確定した結果が大会に残り、「前回の結果」から同じ結果を開ける
    func testConfirmedResultIsSavedAndReopened() throws {
        openSplitResult()
        let dragged = memberRows(in: "チームA").firstMatch
        let target = memberRows(in: "チームB").firstMatch
        let draggedID = dragged.identifier
        let targetID = target.identifier
        dragged.press(forDuration: 1.0, thenDragTo: target)
        XCTAssertEqual(row(of: draggedID).value as? String, "チームB")

        // 確定すると大会の画面へ自動で戻る。前回の結果を開く
        app.buttons["確定"].tap()
        let lastResult = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '前回の結果'")).firstMatch
        XCTAssertTrue(lastResult.waitForExistence(timeout: 3))
        lastResult.tap()

        XCTAssertTrue(app.staticTexts["teamHeader.チームA"].waitForExistence(timeout: 5))
        XCTAssertEqual(row(of: draggedID).value as? String, "チームB")
        XCTAssertEqual(row(of: targetID).value as? String, "チームA")
        XCTAssertTrue(app.staticTexts["手で直した結果です。「分け直す」を押すと、自動で分け直します。"].exists)
        // 開いた結果は確定済み。手で直すと、また確定できるようになる
        XCTAssertTrue(app.buttons["確定済み"].exists)
        memberRows(in: "チームA").firstMatch.press(forDuration: 1.0, thenDragTo: memberRows(in: "チームB").firstMatch)
        XCTAssertTrue(app.buttons["確定"].waitForExistence(timeout: 3))
    }

    /// 確定しないで戻ると、「前回の結果」は残らない
    func testUnconfirmedResultIsNotSaved() throws {
        openSplitResult()
        XCTAssertTrue(app.buttons["確定"].exists)

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["実力が均等になるように分ける"].waitForExistence(timeout: 3))
        let lastResult = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '前回の結果'")).firstMatch
        XCTAssertFalse(lastResult.exists)
    }

    func testDropOnSameTeamDoesNothing() throws {
        openSplitResult()
        let rows = memberRows(in: "チームA")
        let dragged = rows.element(boundBy: 0)
        let target = rows.element(boundBy: 1)

        dragged.press(forDuration: 1.0, thenDragTo: target)

        XCTAssertFalse(app.staticTexts["手で直した結果です。「分け直す」を押すと、自動で分け直します。"].waitForExistence(timeout: 2))
        XCTAssertEqual(memberRows(in: "チームA").count, 6)
    }
}
