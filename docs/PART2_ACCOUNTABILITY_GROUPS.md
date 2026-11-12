# Part 2 — Accountability Groups (design only, not built)

**Goal:** friends form a group, pick a check-in rhythm and which app sections
to track, each set personal goals with sliders, and at check-in time everyone's
sliders are revealed to the group at once. BeReal for real progress.

---

## 1. How it works for the user

1. Crash creates a group "Iron Circle". He picks **weekly, Sunday 8 PM** and
   tracks **Fitness + Goals**. He shares an invite link.
2. Each member adds their own goals inside the group ("Lift 4x/week", "Ship
   portfolio site") and moves their slider whenever they make progress.
3. Before the check-in, nobody can see anyone else's sliders, only their own.
4. Sunday at 8 PM a push notification goes to everyone: *"Check-in! See how Iron
   Circle did this week."* The app shows each person's sliders **as they were at
   8:00 PM**, plus the change since last check-in.
5. One hour before, there's a reminder: *"Check-in in 1 hour. Update your sliders."*

---

## 2. Data model

All ids are UUIDs. All times are `timestamptz` (UTC); the group's own time zone
is stored so "Sunday 8 PM" means the group's local time.

| Table | Key columns | Notes |
|---|---|---|
| `profiles` | `id` (= `auth.uid()`), `display_name`, `avatar_url` | One per user. Created at sign-up. |
| `groups` | `id`, `name`, `owner_id`, `cadence` (`daily`/`weekly`/`monthly`), `checkin_time` (time), `checkin_weekday` (0–6, weekly only), `checkin_monthday` (1–28, monthly only), `timezone` (e.g. `America/New_York`), `tracked_areas text[]`, `created_at` | `tracked_areas` uses the same values as the app's `ActivityArea` enum (`fitness`, `goals`, `tasks`…). |
| `group_members` | `group_id`, `user_id`, `role` (`owner`/`member`), `joined_at` | PK = (`group_id`, `user_id`). |
| `group_invites` | `code` (short random), `group_id`, `created_by`, `expires_at`, `max_uses`, `uses` | Joining goes through an RPC function, never a direct insert. |
| `group_goals` | `id`, `group_id`, `user_id`, `area`, `title`, `created_at`, `archived_at` | A goal belongs to one person in one group. `area` must be in the group's `tracked_areas`. |
| `goal_updates` | `id`, `goal_id`, `user_id`, `value` (0–1), `note`, `created_at` | The slider history. Append-only. **Private to its owner.** |
| `checkins` | `id`, `group_id`, `period_start`, `reveal_at`, `revealed_at` (null until fired) | One row per period, created ahead of time. |
| `checkin_snapshots` | `checkin_id`, `goal_id`, `user_id`, `value`, `previous_value`, `note` | Frozen copy of each slider at `reveal_at`. **This is what friends see.** |
| `push_tokens` | `user_id`, `apns_token`, `updated_at` | For check-in notifications. |

**Why snapshots instead of letting friends read `goal_updates` after the
reveal:** friends should see the value *at check-in time*, not live updates
made five minutes later. It also keeps the security rule dead simple: friends
can never read `goal_updates`, period.

---

## 3. Row-level security (who can see what)

RLS is on for every table, so nothing is readable until a policy allows it.

A helper function avoids the classic "policy queries a table whose policy
queries back" recursion:

```sql
create function public.my_group_ids() returns setof uuid
language sql stable security definer set search_path = public as $$
  select group_id from group_members where user_id = auth.uid()
$$;
```

| Table | Read | Write |
|---|---|---|
| `groups` | members: `id in (select my_group_ids())` | insert: any signed-in user (becomes owner by trigger). update: owner only. |
| `group_members` | members of the same group | only via `join_group(code)` / `leave_group(id)` RPCs |
| `group_goals` | members of the group (titles are visible; values are not) | owner of the goal only: `user_id = auth.uid()` and they're a member |
| `goal_updates` | **owner only:** `user_id = auth.uid()` | owner only, insert only |
| `checkins` | members of the group | nobody (cron function only) |
| `checkin_snapshots` | members of the group **and** the check-in has fired: `exists (select 1 from checkins c where c.id = checkin_id and c.revealed_at is not null and c.group_id in (select my_group_ids()))` | nobody (cron function only) |

So before the check-in fires, a friend's sliders are not readable even by a
hand-written API call, because the rows they could read don't exist yet.

---

## 4. Scheduling "check-in time goes off"

**Server-driven, not phone-driven.** The reveal has to happen for everyone at
the same moment even if phones are off, so the server owns it.

- **`pg_cron` job every minute** calls `fire_due_checkins()` (a `security definer`
  SQL function). For every `checkins` row where `reveal_at <= now()` and
  `revealed_at is null`, it:
  1. copies each member's latest `goal_updates.value` at or before `reveal_at`
     into `checkin_snapshots` (and the previous snapshot's value for "change since
     last time");
  2. sets `revealed_at = now()`;
  3. inserts the next period's `checkins` row (computed in the group's time zone,
     so DST is handled by Postgres);
  4. queues a push via `pg_net` → a Supabase **Edge Function** that sends APNs
     notifications to members.
- **Reminder push** 1 hour before `reveal_at`, same mechanism.
- **In-app:** when a check-in is revealed, the app also picks it up on next open
  (it simply queries snapshots), so a missed push doesn't hide anything.
- Local notifications can additionally schedule the 1-hour reminder on each
  phone (cheap backup if push setup lags), since the schedule is known ahead.

Requirements that cost something or need you: an Apple Developer account for
APNs (you likely already have it for TestFlight), an APNs auth key uploaded to
Supabase secrets, and the `pg_cron` + `pg_net` extensions enabled (free on
Supabase).

---

## 5. What Part 1 already does to make this slot in

| Part 1 choice | Why it matters for groups |
|---|---|
| `ActivityArea` enum with stable raw values | Same values become `groups.tracked_areas`. |
| Goal progress slider (`Goal.progress`) + `goal_slider_changed` events with old/new value | Slider UI and history exist; group goals reuse both. |
| Every model has a UUID `id`, timestamps; new tables have `syncedAt` | Rows can be upserted to Supabase without id remapping. |
| Activity log is append-only | Maps 1:1 onto append-only `goal_updates`. |

## 6. Things to do *when* building Part 2 (not before)

- **Add accounts first:** Supabase Auth with **Sign in with Apple** (required by
  App Store rules once any other social login exists; it's also the least friction).
  This is the first time user data would be tied to a person, so the consent
  screen from Part 3 should ship with it.
- Add `area` and an optional `groupGoalID` to the local `Goal` model so a
  personal goal can be "shared into" a group. Personal goals stay private unless
  explicitly shared. Both are additive, optional fields (no data loss).
- The existing `workouts` table policy (RLS on, no policies, n8n uses
  service role) stays as is. New group tables follow the per-user policies above.
