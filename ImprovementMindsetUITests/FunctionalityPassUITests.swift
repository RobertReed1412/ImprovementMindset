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

    /// Taps until the keyboard is up, then types (avoids a simulator focus race).
    private func focusAndType(_ field: XCUIElement, _ text: String) {
        for _ in 0..<3 {
            field.tap()
            if app.keyboards.firstMatch.waitForExistence(timeout: 2) { break }
        }
        field.typeText(text)
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
        let add = app.navigationBars["Daily"].buttons["Add"]
        // A cold launch can swallow the first tab tap; retry until the screen is up.
        for _ in 0..<3 where !add.exists {
            app.tabBars.buttons["Daily"].tap()
            _ = add.waitForExistence(timeout: 5)
        }
        XCTAssertTrue(add.exists, "Daily screen opened")
        let field = app.textFields["What needs doing?"]
        // First launch after a permission reset can be slow; retry the tap.
        for _ in 0..<3 where !field.exists {
            add.tap()
            _ = field.waitForExistence(timeout: 5)
        }
        XCTAssertTrue(field.exists, "task form opened")
        focusAndType(field, title)
        app.navigationBars["New Daily Task"].buttons["Add"].tap()
    }

    // MARK: 3. Tasks: tap → Finished / Done for now, long-press → edit, subtasks

    private func choose(_ option: String) {
        let b = app.buttons[option].firstMatch
        XCTAssertTrue(b.waitForExistence(timeout: 5), "dialog shows \(option)")
        b.tap()
    }

    private func addSubtask(to parent: String, title: String) {
        app.buttons["task.\(parent)"].press(forDuration: 1.0)
        let add = app.buttons["Add subtask"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let field = app.textFields["What needs doing?"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        focusAndType(field, title)
        app.navigationBars["New Subtask"].buttons["Add"].tap()
    }

    func testFinishedAndDoneForNow() {
        app.launch()
        addDailyTask("Stretch")
        let todo = app.otherElements["column.todo"]
        let done = app.otherElements["column.completed"]
        XCTAssertTrue(todo.buttons["task.Stretch"].waitForExistence(timeout: 5))
        snap("tasks-todo")

        todo.buttons["task.Stretch"].tap()
        choose("Finished")
        XCTAssertTrue(done.buttons["task.Stretch"].waitForExistence(timeout: 5))
        XCTAssertTrue(done.images["completedSeal"].exists, "finished task shows the logo seal")
        snap("tasks-completed")

        done.buttons["task.Stretch"].tap()   // undo
        XCTAssertTrue(todo.buttons["task.Stretch"].waitForExistence(timeout: 5))

        todo.buttons["task.Stretch"].tap()
        choose("Done for now")
        XCTAssertTrue(done.buttons["task.Stretch"].waitForExistence(timeout: 5))
        XCTAssertTrue(done.images["doneForNowMark"].exists, "done-for-now marker")
        XCTAssertFalse(done.images["completedSeal"].exists)
        snap("tasks-done-for-now")
    }

    func testEditTask() {
        app.launch()
        addDailyTask("Typo tsk")
        let card = app.buttons["task.Typo tsk"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.press(forDuration: 1.0)
        app.buttons["Edit"].tap()
        let field = app.textFields["What needs doing?"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "Typo tsk", "form is pre-filled")
        focusAndType(field, String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "Fixed task")
        app.navigationBars["Edit Task"].buttons["Save"].tap()
        XCTAssertTrue(app.buttons["task.Fixed task"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["task.Typo tsk"].exists)
    }

    func testSubtasksStayWithRootUpToThreeLevels() {
        app.launch()
        addDailyTask("Group project")
        XCTAssertTrue(app.buttons["task.Group project"].waitForExistence(timeout: 5))
        addSubtask(to: "Group project", title: "Research")
        addSubtask(to: "Research", title: "Sources")
        addSubtask(to: "Sources", title: "Library")

        let todo = app.otherElements["column.todo"]
        for t in ["Group project", "Research", "Sources", "Library"] {
            XCTAssertTrue(todo.buttons["task.\(t)"].waitForExistence(timeout: 5), "\(t) is in To Do")
        }
        // Level 3 is the max: no "Add subtask" on Library.
        app.buttons["task.Library"].press(forDuration: 1.0)
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Add subtask"].exists, "max 3 levels")
        app.buttons["Edit"].tap()
        app.navigationBars["Edit Subtask"].buttons["Cancel"].tap()

        // Finishing a subtask does NOT move it; it stays under its root.
        todo.buttons["task.Research"].tap()
        choose("Finished")
        XCTAssertTrue(todo.images["completedSeal"].waitForExistence(timeout: 5))
        XCTAssertTrue(todo.buttons["task.Research"].exists)
        XCTAssertFalse(app.otherElements["column.completed"].buttons["task.Research"].exists)
        snap("subtasks")

        // Root moves, and its subtasks move with it.
        todo.buttons["task.Group project"].tap()
        choose("Done for now")
        let done = app.otherElements["column.completed"]
        XCTAssertTrue(done.buttons["task.Group project"].waitForExistence(timeout: 5))
        XCTAssertTrue(done.buttons["task.Library"].exists, "subtasks travel with the root")
    }

    // MARK: 4. Calendar items on top of To Do + notification permission flow

    func testCalendarItemOnTopAndPermissionFlow() {
        app.launch()
        addDailyTask("Regular task")

        app.tabBars.buttons["Calendar"].tap()
        app.navigationBars["Calendar"].buttons["Add"].tap()
        let title = app.textFields["Title (e.g. Therapy, Work)"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        focusAndType(title, "Standup")
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

    func testQuickTaskWidgetDropdown() {
        app.launch()
        let field = app.textFields["quickTask.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        app.buttons["quickTask.options"].tap()
        let kind = app.segmentedControls["quickTask.kind"]
        XCTAssertTrue(kind.waitForExistence(timeout: 5))
        kind.buttons["Daily"].tap()
        app.steppers["quickTask.minutes"].buttons.element(boundBy: 1).tap()   // 15 → 20 min
        focusAndType(field, "Shadowbox")
        app.buttons["quickTask.add"].tap()
        snap("widget-dropdown")

        app.tabBars.buttons["Daily"].tap()
        let card = app.otherElements["column.todo"].buttons["task.Shadowbox"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "went to the Daily list")
        XCTAssertTrue(card.label.contains("20m"), "custom time estimate applied")
    }

    func testQuickTaskWidgetAddsTask() {
        app.launch()
        let field = app.textFields["quickTask.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        focusAndType(field, "Buy chalk")
        app.buttons["quickTask.add"].tap()

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
        let picker = app.buttons["quickNote.circlePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertTrue(picker.label.contains("Stoicism"), "new circle is selected")

        let note = app.textFields["quickNote.field"]
        focusAndType(note, "Second note")
        app.buttons["quickNote.add"].tap()
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
