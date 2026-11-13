# How The Improvement Mindset works

A plain-language map of the app. **Why** things are this way: `DECISIONS.md`.
**How it looks** (theme, fonts, seals): `AGENT_GUIDE.md`.

## The big picture

- An iPhone app built with **SwiftUI** (the screens) and **SwiftData** (Apple's on-device
  database).
- Everything is stored on the phone. The only network piece is the workout coach (Fitness →
  n8n → Supabase).

```
 Screens (SwiftUI views)  ──read/write──►  SwiftData models (the database)
        │                                        ▲
        └─► TaskActions / ActivityLog ───────────┘   one place for task changes + history
                                                 ▲
 DailyMaintenance (app open + every midnight) ───┘   resets, escalation, clean-up
```

## Main parts (all in `ImprovementMindset/`)

| Area | Files | What it does |
|---|---|---|
| App shell | `ImprovementMindsetApp.swift` | Starts the database, the 4 tabs (Home, Daily, Calendar, Settings), the splash, the reminder refresh, and the midnight loop. |
| Data models | `Models.swift` | The database tables: `TaskItem`, `PlayerProfile` (XP/level), `CalendarEvent`, `Goal`/`GoalMove`, `Circle`/`CircleCard`, `WorkoutEntry`, `CalorieDay`, `ShelfItem`, `Strike`, `RulesConfig`. |
| History log | `ActivityLog.swift` | `ActivityEvent`: one append-only row per thing that happened (task finished, note added…). Raw material for the future AI coach. |
| Task rules | `TaskActions.swift` | The only place a task's state changes: Finished, Done for now, Reopen, Delete. Also `TaskDraft`, the editable form fields shared by the form and the widget. |
| Daily clean-up | `DailyMaintenance.swift` | Runs on app open and at midnight. Brings back "done for now" tasks, resets daily tasks, logs missed days, raises importance, and clears finished one-time tasks. |
| Tasks screen | `TasksView.swift`, `AddTaskView.swift` | To Do / Completed columns, today's calendar items on top, subtasks inside their root card, the full task form. |
| Home | `HomeView.swift`, `HomeLayout.swift`, `EditHomeView.swift`, `HomeWidgets.swift` | Home sections you can add, remove, and reorder (saved as a list of IDs), plus the Quick Task and Quick Note widgets. |
| Reminders | `EventReminders.swift` | Local notifications for calendar events, rescheduled 14 days ahead, max 60. iOS caps pending notifications at 64. |
| XP | `LocalXPService.swift` | XP = a formula from difficulty, minutes, and importance. The on-device AI (Qwen/MLX) isn't wired in yet. |
| Workout coach | `RAGClient.swift`, `WorkoutSync.swift`, `WorkoutExport.swift`, `AskCoachView.swift` | Sends workouts to Supabase via n8n and asks the AI coach questions. |
| Other screens | `CalendarView`, `FitnessView`, `CirclesView`, `ShelfView` (library), `RulesView`, `AccomplishmentsView` (goals), `SettingsView` | One screen each. |
| Look | `Theme.swift`, `StyleKit_*.swift`, `WaxSeal.swift` | Colors, fonts, textures, animations. See `AGENT_GUIDE.md`. |

## How a task moves

```
 To Do ──tap──► "Finished"     → Completed (seal, +XP) → deleted at midnight (one-time tasks)
                                                          or back to To Do (daily tasks)
       ──tap──► "Done for now" → Completed (hourglass, no XP) → back in To Do tomorrow, same importance
 Completed ──tap──► back to To Do (XP taken back if it was Finished)
 Long-press ──► Edit / Add subtask (up to 3 levels) / Delete (subtasks go too)
```

Subtasks are tasks with a `parent`. They never switch columns; they sit inside their root's card.

## Running and testing

- **Run:** open `ImprovementMindset.xcodeproj` in Xcode, pick **iPhone 17 Pro**, and press ⌘R.
- **Test (agents and you):** `~/agent-hq/plugins/dev/scripts/ios-test.sh sweep` builds once,
  runs every test, and lists every failure. Then run `ios-test.sh failed` to rerun just the
  failures. Settings are in `.agent-test.conf`.
- **Unit tests** (`ImprovementMindsetTests/`) check rules like midnight clearing and XP, in
  milliseconds.
- **UI tests** (`ImprovementMindsetUITests/`) tap through the real app in the simulator.
  - The `-uiTesting` launch flag gives them a throwaway in-memory database, skips the splash,
    and turns animations off. Real data is never touched.
  - One test (`testHomeLayoutPersistsAcrossLaunches`) uses the simulator's real store, on
    purpose, to prove saving works.

## Glossary

- **SwiftData model / `@Model`:** a Swift class that is saved to the database automatically.
- **Migration:** updating an existing database to a new app version. Adding optional fields
  is "lightweight" and keeps existing data.
- **Cascade delete:** deleting a parent also deletes its children (a task's subtasks).
- **Root task:** a task with no parent.
- **Escalation:** a task's importance goes up by 1 for each day it's left unfinished. A
  "done for now" day doesn't count.
- **Local notification:** a reminder scheduled on the phone itself, with no server.
- **n8n:** a workflow tool that runs the coach's AI pipeline.
- **Supabase:** a hosted Postgres database.
