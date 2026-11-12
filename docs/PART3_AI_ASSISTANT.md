# Part 3: The AI Assistant (design only, not built)

A Jarvis-style coach that can read anything in the app, understands casual
prompts, plans your day from how you actually perform, and measurably gets
better over time. It's a paid feature.

> Prices below were checked on 2026-11-11 (Anthropic's model table; other
> providers from third-party aggregators). Re-check before launch.

---

## TL;DR: the recommendation

**Hybrid. Claude in the cloud does the thinking, the phone holds the data, and a
deterministic scheduler does the math.**

- **Chat / quick asks:** Claude **Haiku 5.5** (cheap, fast).
- **Daily plan, weekly review, coaching:** Claude **Sonnet 5.5** (much better
  judgment, still affordable with caching and batch).
- **Offline / free-tier helpers** (parse "gym tmrw 6am" into a task, no network):
  Apple's built-in **Foundation Models** on-device model.
- **Calls go through a Supabase Edge Function** (the API key never ships in the app;
  per-user rate limits and subscription checks live there).
- **Tools run on the phone first** (Phase 1–2): the model asks for "tasks this
  week" and the app answers from SwiftData. Only what the agent asks for leaves
  the phone. Full Supabase sync comes later, only for features that need the
  server (nightly reflection, groups).
- **"Learning" = memory + personal statistics + evals**, not fine-tuning.

---

## 1. Which model setup

| Option | Quality | Cost / active user / month* | Speed | Privacy | Verdict |
|---|---|---|---|---|---|
| **On-device only** (Apple Foundation Models, ~4–8K context; or the bundled Qwen 1.5B via MLX) | Weak at multi-step planning and coaching; context too small to hold a week of history | $0 | Fast, offline | Best: nothing leaves phone | Good for small helpers, **not** for a paid coach |
| **Cloud only, top model** (Opus 5.5, $4/$20 per M tokens) | Best | ~$5–15 | Slower | Data goes to API | Overkill for daily chat; margin killer |
| **Cloud, mid + small tier** (Sonnet 5.5 $2/$10, Haiku 5.5 $0.10/$0.50) | Very good / good | **~$1.50–4** | Fast | Data goes to API, scoped by tools | **Chosen** for the core |
| Other clouds (GPT-5 mini ~$0.25/$2, Gemini Flash ~$0.30–1.50 in) | Comparable small tiers | Similar | Similar | Similar | Fine alternatives; no reason to split providers |
| **Hybrid** (cloud brain + on-device helpers + local data) | Best per $ | ~$1.50–4 | Fast | Good: minimal data leaves | **Chosen** |

\*Rough math, assuming a heavy user with 20 chat turns a day (~8K input tokens each,
mostly cached, ~500 out) on Haiku is ~$0.60/mo. One Sonnet daily plan (~20K
in, 2K out) is ~$1.80/mo, or ~$0.90 run as an overnight batch. One weekly Sonnet review
is ~$0.20/mo. That totals **~$1.50–4/user/month** in the worst case, so a $5–8/mo subscription
leaves margin.

**About the existing Qwen model:** `LocalXPService` is a formula stub today
(MLX is linked but not used). Recommendation: retire the 0.9 GB Qwen download and
use Apple Foundation Models for on-device bits. It's built into iOS, free, has
tool calling, and has no download. It needs Apple-Intelligence-capable devices
(iPhone 15 Pro and newer), so the fallback stays the existing XP formula.

## 2. How the agent reads from anywhere in the app

**Tool calling over a small set of typed tools**, not dumping everything into the
prompt and not vector search over everything.

Read tools (all take a date range and filters, and return compact JSON):

| Tool | Answers |
|---|---|
| `get_tasks(status, kind, range)` | What's on my plate? |
| `get_calendar(range)` | When am I free? |
| `get_activity(types, areas, range)` | Reads the **ActivityEvent log** built in Part 1 (completions, misses, slider moves). |
| `get_stats(metric, range)` | Precomputed numbers: completion rate by hour or weekday, estimate accuracy, streaks. Exact numbers come from code, not the model. |
| `get_goals()`, `get_workouts(range)` | Goals, sliders, training. |
| `search_notes(query)` | Circle cards. The only place semantic or vector search earns its keep (free text). |
| `recall(topic)` | Long-term memories (below). |

Write tools need **an in-app confirm tap** before anything changes:
`create_task`, `schedule_block`, `add_note`, `remember`, `forget`.

Why the Part 1 activity log matters: one table, one schema, timestamps and
categories on everything. That makes `get_activity` and `get_stats` a few lines of
code each instead of one bespoke query per screen.

## 3. Memory architecture

Four layers, cheapest and most reliable first:

1. **Facts (source of truth):** the app's own data and the ActivityEvent log.
   The model never memorizes these; it looks them up.
2. **Performance profile (computed, not generated):** a nightly job turns the log
   into numbers, e.g. "finishes hard tasks 68% of the time before noon, 31% after 6 PM",
   "underestimates writing tasks by 1.6×", "skips workouts on Mondays". It's
   deterministic and testable, and it drives the scheduler.
3. **Semantic memories:** short statements with a type, source, confidence, and
   `last_used_at`:
   - `preference`: "likes training in the morning"
   - `glossary`: "'the grind' = job applications", "'lock in' = 2-hour deep-work block"
   - `context`: "graduating May 2026, job hunting for AI SWE roles"
   - `coaching_note`: "responds better to blunt nudges than pep talks"
   Written by the agent's `remember` tool during chat (user sees "Saved: …") and
   by a weekly reflection pass.
4. **Episodes:** a two- or three-line summary of each conversation, so it can say
   "last week you said Mondays are rough".

**Where:** on-device SwiftData first (Phase 1–2). It mirrors to a Supabase
`memories` table only once the user opts into sync (needed for overnight jobs
and multi-device).

**Updated:** a new memory that contradicts an old one replaces it (keeping a
history row). Confidence rises each time a memory proves useful (it's recalled
and the reply gets a 👍 or isn't corrected).

**Forgotten:** low-confidence memories unused for 60 days expire. Episodes older
than 90 days get folded into a monthly summary. **The user can see, edit, and
delete every memory** on a "What Jarvis knows" screen, and "forget that" works
in chat. Deleting is a hard delete.

## 4. Understanding casual prompts, and getting better at it

- A strong model handles most slang already. The gaps are *personal* shorthand.
- **Personal glossary:** the agent first tries to interpret. If unsure, it asks
  one short clarifying question and then saves the answer as a `glossary` memory.
  Next time it doesn't ask.
- **Few-shot from your own history:** the system prompt includes the user's top
  glossary entries plus 3–5 of their past requests that went well (accepted
  without edits).
- **Measure it:** the *clarifying-question rate* and the *correction rate* ("no, I
  meant…") per 100 messages should trend down month over month. If they don't,
  the glossary isn't working.

## 5. Life coach + day scheduling

**The model doesn't do the scheduling math; code does.** LLMs are unreliable at
fitting durations into time slots. Split the work:

1. **Model → constraints.** It turns "light day, gym after work, need to grind
   apps" plus memories into structured constraints (JSON via structured outputs):
   must-dos, preferred windows, energy level, things to avoid.
2. **Scheduler (Swift, deterministic) → plan.** It places fixed calendar events first,
   then tasks by importance and deadline. Each task's duration is
   `estimate × personal multiplier` from the performance profile, and hard tasks go
   into the user's historically best hours. It's greedy with simple rules and
   unit-testable.
3. **Model → explanation and coaching.** It presents the plan in the user's tone and
   explains the trade-offs ("I put applications at 9 because that's when you
   actually finish hard stuff").
4. **User accepts, edits, or rejects blocks.** That outcome is logged
   (`plan_block_accepted/edited/rejected`) and later compared to what actually got
   done (`task_completed` timestamps).

Coaching uses the same data: weekly review = stats deltas + goal slider movement
+ misses, framed by `coaching_note` memories.

## 6. The "learns and gets better" loop

**Signals (all free, from the activity log):**
- Plan adherence: did scheduled blocks get done near their slot?
- Estimate error: actual vs scheduled duration.
- Plan edits: how much the user changes a proposed plan.
- Clarifying-question rate and correction rate.
- Explicit 👍/👎 on replies.

**What actually improves, ranked by value for a solo dev:**

| Mechanism | Realistic? | What it improves |
|---|---|---|
| **Personal stats → scheduler** (multipliers, best hours) | ✅ Yes, cheap, provable | Plans fit real life better every week |
| **Memory writes** (glossary, preferences, coaching notes) | ✅ Yes | Understanding casual prompts; tone |
| **Few-shot from accepted plans and requests** | ✅ Yes | Style and format fit |
| **Offline evals before changing prompts or models** (50–100 saved, consented example conversations, graded by script and a judge model) | ✅ Yes, essential | Stops "improvements" that break things |
| **A/B prompt versions, picked by adherence and 👍 rate** | 🟡 Later (needs users) | Global prompt quality |
| **Simple bandit over plan styles** (e.g. "front-load hard tasks" vs "warm-up first"), per user | 🟡 Later | Per-user plan strategy |
| **Fine-tuning a shared model on consented data** | 🔴 Overkill now | Only at thousands of users |
| **Per-user fine-tuning or RL** | 🔴 Overkill | Not worth the cost or complexity |

**How we know it's improving:** a monthly dashboard per cohort tracking plan
adherence ↑, estimate error ↓, plan-edit rate ↓, clarifying-question rate ↓,
👍 rate ↑, and paid retention ↑. Any prompt or model change must not lose
on the offline eval set.

## 7. Phased build order

| Phase | Ships | Needs |
|---|---|---|
| **0: done (Part 1)** | ActivityEvent log, consistent timestamps and categories | — |
| **1: Ask Jarvis (MVP)** | Chat screen. Haiku 5.5 via Edge Function. Read-only tools executed on-device. No memory yet. | Edge Function + API key (💰 usage-based), Supabase Auth |
| **2: Memory + glossary** | `remember` / `recall`, "What Jarvis knows" screen, clarifying-question then save | Local SwiftData `Memory` model |
| **3: Daily plan** | Constraints → Swift scheduler → Sonnet explanation. Accept/edit UI. Plan events logged. | Performance-profile stats (on-device) |
| **4: Coach** | Weekly review, nudges via local notifications, write tools with confirm | — |
| **5: Sync + overnight** | Opt-in sync of activity log and memories to Supabase. Overnight batch planning and reflection. Multi-device. | Supabase tables + RLS, consent flow |
| **6: Improve** | Offline eval set, prompt A/B, plan-style bandit | Real users |

Replace the n8n workout RAG with Phase 1's `get_workouts` + `get_stats` tools.
Counting questions ("how many hours did I fight this month") are exact in SQL or
Swift and unreliable with vector search. Keep n8n only if you want it as a
portfolio piece.

## 8. Privacy, consent, deletion

- **Consent screen before first use** (Phase 1), in plain words: *"Jarvis sends
  the parts of your app data it needs to answer you to Anthropic's API through our
  server. It isn't used to train models."* (Verify Anthropic's current commercial
  data-use and retention terms at launch and quote them exactly.)
- **What leaves the phone:**
  - Phases 1–4: only the tool results for the current request, plus the message.
  - Phase 5, after opt-in: the activity log, tasks, goals, and memories, stored in
    your Supabase project with per-user RLS.
  - Never: photos (shelf images), and never anything not requested by a tool.
- **Per-area switches:** "Jarvis can read: Tasks ✅ Calendar ✅ Circles ⛔ Fitness ✅",
  enforced in the tool layer.
- **User can delete:** any single memory, all memories, chat history, all synced
  data (one button runs a server function that deletes every row for
  `auth.uid()`), or the whole account. Logs on the Edge Function keep no message
  bodies.
- **Minimize:** tools return summaries (titles, times, counts), not full note
  bodies unless the question is about notes.
