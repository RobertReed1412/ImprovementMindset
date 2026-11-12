import XCTest

/// Drives Part 1 features end-to-end in the simulator.
/// Launches with `-uiTesting` (fresh in-memory store) unless noted.
final class FunctionalityPassUITests: XCTestCase {

    var app: XCUIApplication!
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
    }

    private func snap(_ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    /// Edit Home shows red minus buttons; tap it, then confirm Delete.
    private func removeHomeSection(_ id: String) {
        let row = app.staticTexts["home.shown.\(id)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.07, dy: 0.5)).tap()
        let delete = app.buttons["Delete"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()
    }

    private func addDailyTask(_ title: String) {
        app.tabBars.buttons["Daily"].tap()
        app.navigationBars["Daily"].buttons["Add"].tap()
        let field = app.textFields["What needs doing?"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText(title)
        app.navigationBars["New Daily Task"].buttons["Add"].tap()
    }

    // MARK: 3. Tasks: two columns, tap toggles, seal on completed

    func testTaskTogglesBetweenColumns() {
        app.launch()
        addDailyTask("Stretch")
        let todo = app.otherElements["column.todo"]
        let done = app.otherElements["column.completed"]
        XCTAssertTrue(todo.buttons["task.Stretch"].waitForExistence(timeout: 5))
        XCTAssertFalse(done.buttons["task.Stretch"].exists)
        snap("tasks-todo")

        todo.buttons["task.Stretch"].tap()
        XCTAssertTrue(done.buttons["task.Stretch"].waitForExistence(timeout: 5))
        XCTAssertFalse(todo.buttons["task.Stretch"].exists)
        XCTAssertTrue(done.images["completedSeal"].exists, "completed task shows the logo seal")
        snap("tasks-completed")

        done.buttons["task.Stretch"].tap()
        XCTAssertTrue(todo.buttons["task.Stretch"].waitForExistence(timeout: 5))
        XCTAssertFalse(done.buttons["task.Stretch"].exists)
    }

    // MARK: 4. Calendar items on top of To Do + notification permission flow

    func testCalendarItemOnTopAndPermissionFlow() {
        app.launch()
        addDailyTask("Regular task")

        app.tabBars.buttons["Calendar"].tap()
        app.navigationBars["Calendar"].buttons["Add"].tap()
        let title = app.textFields["Title (e.g. Therapy, Work)"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap(); title.typeText("Standup")
        app.navigationBars["New Event"].buttons["Add"].tap()

        // First event saved -> system permission prompt.
        let allow = springboard.alerts.buttons["Allow"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }

        app.tabBars.buttons["Daily"].tap()
        let todo = app.otherElements["column.todo"]
        let cal = todo.descendants(matching: .any)["calendarItem"].firstMatch
        XCTAssertTrue(cal.waitForExistence(timeout: 5))
        XCTAssertTrue(cal.label.contains("Standup"))
        XCTAssertTrue(cal.label.contains("AM") || cal.label.contains("PM"), "shows event time")
        let task = todo.buttons["task.Regular task"]
        XCTAssertLessThan(cal.frame.minY, task.frame.minY, "calendar item sits above tasks")
        snap("tasks-calendar-item")

        app.tabBars.buttons["Settings"].tap()
        XCTAssertEqual(app.staticTexts["reminders.status"].label, "Allowed")
        snap("settings-reminders")

        // A real notification is delivered.
        app.buttons["reminders.test"].tap()
        let banner = springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS 'Test reminder'")).firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 20), "test notification banner appears")
        snap("notification-banner")
    }

    // MARK: 1. Customizable home

    func testRemoveAndReAddHomeSection() {
        app.launch()
        XCTAssertTrue(app.textFields["quickTask.field"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Settings"].tap()
        app.buttons["settings.editHome"].tap()
        removeHomeSection("widget.tasks")
        XCTAssertTrue(app.buttons["home.add.widget.tasks"].waitForExistence(timeout: 5))
        snap("edit-home")

        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.textFields["quickNote.field"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["quickTask.field"].exists, "removed section is hidden")

        app.tabBars.buttons["Settings"].tap()
        app.buttons["home.add.widget.tasks"].tap()
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.textFields["quickTask.field"].waitForExistence(timeout: 5))
    }

    /// Uses the real on-disk store (no -uiTesting) to prove the layout survives a relaunch.
    func testHomeLayoutPersistsAcrossLaunches() {
        app.launchArguments = []
        app.launch()
        sleep(3)   // splash
        app.tabBars.buttons["Settings"].tap()
        app.buttons["settings.editHome"].tap()
        app.buttons["Reset to default"].tap()
        removeHomeSection("widget.notes")
        XCTAssertTrue(app.buttons["home.add.widget.notes"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        sleep(3)   // splash
        XCTAssertTrue(app.textFields["quickTask.field"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["quickNote.field"].exists, "layout persisted")

        // Restore default for the next run.
        app.tabBars.buttons["Settings"].tap()
        app.buttons["settings.editHome"].tap()
        app.buttons["Reset to default"].tap()
    }

    // MARK: 2. Widgets

    func testQuickTaskWidgetAddsTask() {
        app.launch()
        let field = app.textFields["quickTask.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("Buy chalk")
        app.buttons["quickTask.add"].tap()
        XCTAssertTrue(app.staticTexts["Added to Tasks"].waitForExistence(timeout: 3))

        app.swipeUp()
        app.staticTexts["Tasks"].firstMatch.tap()
        XCTAssertTrue(app.otherElements["column.todo"].buttons["task.Buy chalk"].waitForExistence(timeout: 5))
    }

    func testQuickNoteWidgetCreatesCircleAndAddsNote() {
        app.launch()
        XCTAssertTrue(app.buttons["quickNote.newCircle"].waitForExistence(timeout: 5))
        app.buttons["quickNote.newCircle"].tap()
        let alert = app.alerts["New circle"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.textFields.element(boundBy: 0).typeText("Stoicism")
        alert.textFields.element(boundBy: 1).tap()
        alert.textFields.element(boundBy: 1).typeText("Memento mori")
        alert.buttons["Create"].tap()
        XCTAssertTrue(app.staticTexts["Created Stoicism"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["quickNote.circlePicker"].label.contains("Stoicism"))

        let note = app.textFields["quickNote.field"]
        note.tap(); note.typeText("Second note")
        app.buttons["quickNote.add"].tap()
        XCTAssertTrue(app.staticTexts["Added to Stoicism"].waitForExistence(timeout: 3))
        snap("home-widgets")

        app.swipeUp()
        app.staticTexts["Circles"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["2 cards"].waitForExistence(timeout: 5))
    }

    // MARK: 5. Goal slider

    func testGoalSlider() {
        app.launch()
        app.swipeUp()
        app.staticTexts["Goals"].firstMatch.tap()
        app.navigationBars["Goals"].buttons.element(boundBy: 1).tap()
        let f = app.alerts.textFields.firstMatch
        XCTAssertTrue(f.waitForExistence(timeout: 5)); f.typeText("Run a 5k")
        app.alerts.buttons["Add"].tap()
        app.staticTexts["Run a 5k"].tap()
        let slider = app.sliders["goal.progressSlider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        slider.adjust(toNormalizedSliderPosition: 0.6)
        XCTAssertNotEqual(app.staticTexts["goal.progressLabel"].label, "0%")
        snap("goal-slider")
    }
}
