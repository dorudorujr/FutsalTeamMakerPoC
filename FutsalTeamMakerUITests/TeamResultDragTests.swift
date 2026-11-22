import XCTest

/// 結果の画面で、ドラッグして選手を入れ替えたり移したりできるかを確かめる。
/// サンプルの大会（12人）を2チームに分けるので、チームA・Bは6人ずつになる。
@MainActor
final class TeamResultDragTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// アプリを起動し、サンプルの大会を作って2チームに分けた結果の画面を開く
    private func openSplitResult() {
        app = XCUIApplication()
        app.launchArguments = ["-UITestInMemory"]
        app.launch()

        app.buttons["サンプルの大会を作る"].tap()
        app.staticTexts["サンプル大会"].tap()
        app.buttons["実力が均等になるように分ける"].tap()
        XCTAssertTrue(app.staticTexts["チームA"].waitForExistence(timeout: 5))
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

        dragged.press(forDuration: 1.0, thenDragTo: app.staticTexts["チームB"])

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
        XCTAssertTrue(app.staticTexts["チームD"].waitForExistence(timeout: 5))

        let teamD = app.staticTexts["チームD"]
        let before = teamD.frame.minY
        let dragged = memberRows(in: "チームA").firstMatch
        let bottomEdge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.93))
        dragged.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
            .press(forDuration: 1.0, thenDragTo: bottomEdge, withVelocity: .slow, thenHoldForDuration: 3.0)
        // ドロップでチームの人数が変わっても、チームDより上の高さの合計は変わらない。
        // チームDが上へ動いていれば、ドラッグ中にスクロールしている
        XCTAssertLessThan(teamD.frame.minY, before - 40)
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
