# DECISIONS

One entry per meaningful choice: **what I chose, the alternatives, and why.**
Newest work is at the top of each section.

---

## Setup

**Installed Apple's Metal Toolchain (Xcode component).**
Alternatives: unlink the MLX packages from the project.
Why: the project wouldn't build on this Mac before any change because MLX needs
Metal. Installing the official, free Xcode component changes nothing in the
project. Unlinking would be a dependency change you'd want to approve.

**Work on branch `feature/functionality-pass`, one commit per feature, nothing pushed.**
Your uncommitted `RAG_SETUP.md` edits were left alone and not committed.

---

## Part 1: Built

### Data foundation (feature 5, built first because everything logs into it)

**One append-only `ActivityEvent` table for all history.**
Alternatives: a history table per feature; computing history from current rows.
Why: the AI coach and group check-ins need "what happened, when, in which area"
from one place. Current rows lose history (a daily task resets every day). One
table means one query shape for every future tool.

**Event fields: type, area, entity id, title snapshot, one number, small JSON metadata, `syncedAt`.**
Alternatives: a fully typed column per fact; free-form JSON only.
Why: typed columns cover the 90% case (filter by type, area, and date). Metadata
holds the rest without schema changes. The title snapshot keeps history readable
after an item is renamed or deleted. `syncedAt` lets a future uploader send only
new rows.

**Events logged:** task created / completed / uncompleted / missed / deleted, note
added, circle created, goal created / slider changed / move added /
accomplished, event created / deleted, workout logged. Completions record
`minutes_vs_due`. Missed tasks record the day missed. This is what the scheduler
will learn from.

**"Missed" means:** a daily task not done by the end of its day (one row per missed
day, max 30), or a one-time task *with a deadline* that rolls over to a new day.
Alternatives: count any unfinished one-time task as missed.
Why: a no-deadline to-do sitting for a few days isn't a failure. Counting it
would teach the coach the wrong lesson.

**Added a goal progress slider (`Goal.progress`, 0–100%).**
Alternatives: wait for Part 2.
Why: the spec lists "goal slider changed" as an event to log, and groups are built
on sliders. It's one small control on the goal screen. It logs once when you
let go, not on every tick.

**Schema changes are additive only** (new tables; new fields with defaults:
`TaskItem.completedAt`, `Goal.progress`).
Alternatives: a versioned migration plan.
Why: SwiftData migrates additive changes automatically. **Verified:** I installed
the current `main` build, created a task and a goal, installed this branch over
it, and both survived (checked in the UI and in the SQLite file).

**Bug fix: completed daily tasks were still getting their importance raised each day.**
The reset ran before the "was it done?" check. Fixed so only unfinished tasks
escalate. This also matters because importance feeds the AI's data.

**`-uiTesting` launch flag uses a throwaway in-memory database.**
Why: tests never touch real data. It has no effect on normal launches.

### Customizable home page (feature 1)

**Each home block is a "section":** Level & XP header, Quick Task widget, Quick
Note widget, and one shortcut per screen. Consecutive shortcuts render as the same
2-column tile grid as before.
Alternatives: only toggle whole groups ("all shortcuts on/off").
Why: per-section control is what "add or delete sections" implies, and it costs
the same to build.

**Defaults = the old home page (all 8 tiles, same order) + header + both widgets.**
Why: existing users see nothing disappear. New users see the widgets right away.

**Stored as one SwiftData row with an ordered list of section ids + `updatedAt` + `syncedAt`.**
Alternatives: UserDefaults/AppStorage; one row per section.
Why: it's in the same store as everything else, so it's backed up with it.
Supabase sync becomes a single `home_layouts` row per user with last-write-wins
on `updatedAt`. Unknown ids (from a newer app version) are kept, not dropped.

**Edit screen: Settings → Edit home page. Remove (red minus), drag to reorder, tap + to add, Reset to default.**
Reorder wasn't asked for, but the list supports it for free.
**Removing only hides the section.** The data isn't touched; the layout is a separate list.

### Home widgets (feature 2)

**Quick Task adds a one-time task** (15 min, medium, importance 1, formula XP),
the same defaults as the full form.
Alternatives: a daily task, or a picker for type.
Why: "quick add task" usually means a to-do. Adding a picker would make it not quick.

**Quick Note: dropdown of circles, a + button on the right to create a new circle with its
first note (pre-filled with whatever you'd typed), and an arrow to add the note.**
The note goes into the card **body**, with the title left empty to fill in later.
The last chosen circle is remembered.
Alternative: put the note in the title. Rejected because titles are short labels,
and notes are often a sentence or more.

### Tasks screen (feature 3)

**Two side-by-side columns, To Do and Completed, on both the Daily tab and the Tasks screen.**
Alternatives: one list with two sections; a segmented toggle.
Why: you asked for columns. Cards are compact (title, time · XP, deadline,
importance) so they fit at half width.

**Completed cards show the `SealCrest` logo image** (the same file as the launch screen).

**Tap a To Do task → "Finished" or "Done for now"** (update 2, replaces plain tap-to-toggle).
- **Finished:** earns XP and moves to Completed. At midnight finished one-time tasks
  are **deleted** (you asked for a daily clear). Their history stays in the
  activity log, so the AI loses nothing. Daily tasks aren't deleted; they reset
  to To Do as before.
- **Done for now** (multi-day work): moves to Completed today and comes back to
  To Do tomorrow at the **same importance**. That day isn't logged as missed. It
  **earns no XP**; XP comes when it's Finished, so pausing can't be farmed for XP.
  It's logged as `task_done_for_now`, which tells the coach you worked on it.
- **Tapping something in Completed undoes it** (finished XP is taken back).
- **Midnight timing:** cleanup runs at the actual midnight if the app is open (a
  timer), otherwise on the next open. The Completed column only shows today's items
  either way, so it always looks right.
Alternative considered: keep finished tasks visible for 7 days (my first version).
Replaced because you asked for a daily clear.

**Edit any task: long-press → Edit / Add subtask / Delete.**
Alternatives: an edit button on every card; tap to edit.
Why: tap now opens the Finished / Done-for-now choice, and the columns are too
narrow for extra buttons. Editing uses the same full form, pre-filled.
Editing a **finished** task keeps its XP as already awarded. Editing an unfinished
task re-scores XP if time, difficulty or importance changed. The importance
range in the form went from 1–10 to 1–99, since escalated tasks can pass 10.

**Subtasks: up to 3 levels under a root task, the same fields as any task.**
- They show inside the root's card, indented by level, and **never change column**.
  Finishing a subtask puts the seal on it in place.
- When the **root** moves columns, its subtasks move with it (they're part of its card).
- Subtasks always share the root's type (daily or one-time). Changing the root's
  type changes theirs.
- A finished subtask is **not** cleared at midnight on its own, because that would
  detach it from its root. It goes when the root is deleted or cleared.
- Deleting a root deletes its subtasks.
- Data model: an optional `parent` link on `TaskItem`. That's additive, and
  **verified** by installing over a `main`-built database: the old task survived
  and accepted a subtask.

**Quick Task widget dropdown** (chevron next to +): type, time, difficulty, due
time, importance, and a live XP preview, all inside the widget. Without opening
it, + still adds with the defaults (one-time, 15 min, medium, importance 1).
The task goes to Daily or Tasks depending on the type picked.
Alternative: the chevron opens the full form as a sheet. I picked inline because
"drop down" suggested it.

### Calendar items in tasks (feature 4)

**Today's calendar events show at the top of the To Do column** with the start time
over the name and the event's color bar. They can't be checked off (they're
events, not tasks).

**"Auto-delete" = disappears from the task list once the event *ends*. The
calendar event itself is NOT deleted.**
Alternatives: delete the CalendarEvent record; hide at start time.
Why: deleting would wipe recurring events (your weekly therapy would vanish after
one week) and lose history. Ending time is when it's truly over (a 9–10 AM
meeting is still relevant at 9:30). The list refreshes every 30 seconds.

**Local notifications at each event's start time.**
Approach: whenever events change or the app opens, rebuild reminders for the next
14 days (max 60, since iOS keeps 64).
Alternatives: one repeating notification per event.
Why: iOS can't natively repeat "every 2 weeks". Rebuilding handles every recurrence
type, edits, and deletes with one code path.
**Permission is asked when you save your first event**, not at launch (higher
acceptance). Settings shows status, scheduled count, a "Turn on" button (or
"Open iPhone Settings" if you said no), and **Send a test reminder**.
Reminders show as banners even while the app is open.
**Verified in the simulator:** the system prompt appeared, Allow was tapped, Settings
read "Allowed", and a real test notification banner was delivered.

**Notify at start time** (not 10 minutes before).
Simplest reading of the spec. A lead-time setting is an easy follow-up.

### Verification

- 13 unit tests: calendar items, reminders, missed-task logging, the escalation
  fix, midnight clearing (subtasks of unfinished roots kept), done-for-now
  returning at the same importance, XP on finish/undo, the subtask depth limit
  and cascade delete, root type changes, layout.
- 10 UI tests driving the real app in the iPhone 17 Pro simulator: Finished and
  Done for now, editing, 3-level subtasks staying with their root, the widget
  dropdown, the calendar item + permission + a real notification, home layout,
  both widgets, the goal slider.

---

## Part 2: Accountability groups (plan) → `docs/PART2_ACCOUNTABILITY_GROUPS.md`

**Server decides the reveal (pg_cron every minute), not phones.**
Alternative: each phone reveals at local time.
Why: everyone must see it at the same moment, even if their phone is off, and the
data must be unreadable until then.

**Friends see frozen snapshots taken at check-in time; raw slider history is owner-only forever.**
Alternative: let friends read slider history after `reveal_at`.
Why: you see their progress *as of* check-in (the BeReal moment), and the
security rule is simple and hard to get wrong.

**RLS via a `security definer` "my group ids" helper.**
Why: avoids the common infinite-recursion bug when policies check a membership
table.

**Push via APNs from a Supabase Edge Function, plus a local 1-hour reminder as backup.**

**Sign in with Apple for accounts.**
Why: least friction on iOS, and App Store rules require it alongside other social logins.

---

## Part 3: AI assistant (plan) → `docs/PART3_AI_ASSISTANT.md`

**Hybrid: Claude in the cloud (Haiku 5.5 for chat, Sonnet 5.5 for plans and coaching) + Apple on-device model for small offline helpers.**
Alternatives: on-device only (too weak and too little context for a coach);
top model for everything (5–10× the cost for chat that doesn't need it); OpenAI or
Gemini small models (comparable; no reason to run two providers).
Why: the best quality per dollar. Estimated ~$1.50–4 per heavy user per month,
which fits under a $5–8 subscription.

**Retire the Qwen/MLX path for Apple Foundation Models.**
Why: today Qwen isn't actually running (the XP service is a formula stub). Apple's
model is built in, free, has tool calling, and needs no 0.9 GB download.

**The API key lives in a Supabase Edge Function proxy, never in the app.**

**Tools run on the phone first; full sync later and opt-in.**
Alternative: sync everything to Supabase on day one.
Why: much less data leaves the phone, there's nothing to sync to ship the MVP,
and it's faster to build. Sync comes when overnight jobs and groups need it.

**Typed tools over the activity log (+ vector search only for notes), not RAG over everything.**
Why: "how many / how often" questions need exact counting. Vector search is bad at
that. This also replaces the n8n workout RAG.

**The scheduler is deterministic Swift code; the model writes constraints and explanations.**
Why: LLMs are unreliable at fitting time slots. Code is testable, and its
inputs (personal multipliers, best hours) are where the real learning shows.

**"Gets better" = personal stats + memory (glossary, preferences) + few-shot +
offline evals. No fine-tuning.**
Why: these are measurable and cheap for a solo dev. Fine-tuning needs data and
users you don't have yet.

**The user sees, edits, and deletes every memory; low-confidence, unused memories expire.**

---

## Noticed but not changed (outside this task)

- **Large nav titles don't render** on Daily, Calendar and other screens (the top bar
  is blank except for the + button). This happens on `main` too. It's a visual fix,
  so I left it.
- **Settings says the XP model is "Qwen2.5-1.5B … Ready"**, but XP actually uses the
  formula. The label is misleading.
- **The "Daily" tab and Home "Tasks" screen are separate lists** (daily vs
  one-time). Both got the new columns.
