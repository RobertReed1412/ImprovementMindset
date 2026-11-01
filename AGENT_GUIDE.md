# AGENT_GUIDE.md — read this before any UI or graphics work

You are editing **The Improvement Mindset**, a SwiftUI + SwiftData iOS app with
a dark-fantasy / crusader theme. This file is the source of truth for how the app
looks and how to add to it on-style. Read it fully before changing visuals or
adding graphics.

## Golden rules
1. **Never hardcode colors, fonts, or hex values in a view.** Everything comes
   from `Theme.swift`. If a color you need doesn't exist there, ADD it to
   `Theme.Palette` first, then use the token.
2. **Titles use the display font**, never `.font(.title)` etc. Use
   `Theme.display(size, weight:)` — it resolves to the bundled Dragon Knight font.
3. **Backgrounds:** screens use `.nightBackground()`. Reading-heavy surfaces
   (text the user studies — circle cards) use `.parchmentSurface()`.
4. **Preview your change** before declaring done: every screen has a `#Preview`.
   Open the canvas, confirm it renders, iterate there (see DESIGN_WORKFLOW.md).
5. Keep changes minimal and localized. Don't refactor unrelated code.

## The theme system (Theme.swift)

**Color tokens** (`Theme.Palette.<name>`):
- Backgrounds: `nightDeep 0x070A17`, `night 0x0A0E1F`, `nightRaised 0x141A33`, `nightGlow 0x1B2540`
- Gold: `gold 0xC9A24B`, `goldBright 0xE3C56B`, `goldDim 0x8A6E32`
- Malachite (accents/progress): `malachite 0x1E6B52`, `malachiteLite 0x2E9B73`
- Parchment (reading surfaces): `parchment 0xE8DCC0`, `parchmentWorn 0xD8C8A4`, `parchmentInk 0x2A2418`
- Oxblood (danger/strikes/red seal): `oxblood 0x7B1418`, `oxbloodBright 0x9E2024`
- Text on dark: `bone 0xE8DCC0`, `boneDim 0xB5A982`

**Gradients:** `Theme.nightBackground`, `Theme.malachiteGold` (XP bar / hero fills),
`Theme.goldStroke` (frame borders).

**Fonts:** `Theme.display(_ size:weight:)` for all titles/headers. Body text can
stay system font. The display font PostScript name is `DragonKnight`
(`Theme.displayFontName`).

**View modifiers (extensions on View):**
- `.nightBackground()` — midnight gradient + central malachite glow. Use on screen roots.
- `.goldFrame(cornerRadius:)` — thin gold border + L-shaped corner accents. For hero cards.
- `.parchmentSurface(cornerRadius:)` — parchment gradient card. For reading content.

**Reusable components:** `GoldButtonStyle` (button style), `WaxSeal` (see below),
`CornerAccents` (Shape for corner marks), `Tag` (small labeled icon in TasksView).

## Wax seals — the signature graphic

`WaxSeal(tone:size:symbol:)` in WaxSeal.swift. Glossy hand-pressed wax look:
irregular rim (`WaxBlob` shape), radial sheen, embossed SF Symbol crest.
- `.red` = creation made · `.black` = book read · `.white` = book listened · `.gold` = goal accomplished
- `symbol:` is any SF Symbol name for the embossed crest.
This is the reference example of how bespoke graphics are done here: **procedural
SwiftUI drawing**, not image assets.

## HOW TO MATCH A REFERENCE IMAGE (primary graphics workflow)

The user provides a reference image; you reproduce its look in **SwiftUI drawing
code** (Shapes, gradients, `Canvas`, `Path`), styled with theme tokens. Process:

1. **Analyze the reference** in words first: dominant shapes, color families (map
   them to the nearest `Theme.Palette` tokens — introduce a new token only if
   nothing is close), linework weight, gloss/shadow, symmetry.
2. **Pick the drawing primitive:**
   - Geometric emblems, frames, crests → `Shape`/`Path` (see `CornerAccents`, `WaxBlob`).
   - Rich shading/gloss → layered gradients (`RadialGradient` for domed sheen, as in `WaxSeal`).
   - Many elements / procedural → `Canvas`.
3. **Build it as a small reusable `View` or `Shape`**, parameterized (size, tone,
   symbol) like `WaxSeal`. One component per file, named clearly.
4. **Use theme tokens for every color.** Match the reference's hue by choosing the
   closest token; if you must add one, add it to `Theme.Palette` with a descriptive
   name and a comment noting what reference it came from.
5. **Add a `#Preview`** rendering the new component at a few sizes on
   `Theme.Palette.night`, so it can be judged in the canvas immediately.
6. Only wire it into a screen after it looks right in isolation.

**When the reference needs actual raster art** (a painted illustration you can't
reasonably reproduce with shapes): don't fake it. Tell the user it needs an image
asset, state what to generate, and once they drop a PNG into `Assets.xcassets`,
wire it up with `Image("AssetName")`. Generating new raster artwork is out of
scope for code; integrating it is in scope.

## Adding an image asset (raster)
1. User adds the PNG to `Assets.xcassets` (or you create the `.imageset` folder +
   `Contents.json` if working from files). Provide @1x/@2x/@3x when possible.
2. Reference with `Image("AssetName").resizable().scaledToFit()`.
3. Existing image sets: `AppIcon` (icon), `SealCrest` (transparent crest used on LaunchView).

## SwiftData note for previews
Views use `@Query`, so a bare `SomeView()` preview crashes. Always end a preview
with `.previewEnv()` (from PreviewHelpers.swift) — it injects an in-memory
container seeded with sample data. New models must be added to BOTH the real
container (KingTasksApp.swift) and the preview container (PreviewHelpers.swift).

## File map
- Theme/graphics: `Theme.swift`, `WaxSeal.swift`, `Assets.xcassets`
- Screens: `HomeView`, `TasksView`, `CalendarView`, `FitnessView`, `ShelfView`,
  `CirclesView`, `RulesView`, `AccomplishmentsView`, `SettingsView`, `LaunchView`
- Add sheets: `AddTaskView`, `AddEventView`
- Data: `Models.swift`, `DailyMaintenance.swift`, `LocalXPService.swift`
- App shell: `KingTasksApp.swift` (tab bar, appearance, launch overlay)
- Previews: `PreviewHelpers.swift`

## Don't
- Don't hardcode hex/`Color(red:…)` in views.
- Don't use system fonts for titles.
- Don't add a screen without `.nightBackground()` + a `#Preview`.
- Don't touch `LocalXPService` model-loading logic for a UI task.
- Don't break the theme to match a reference exactly — adapt the reference into
  the app's palette; introduce new tokens deliberately, not ad hoc.

---

# StyleKit: textures, modular tabs, and animations

The `StyleKit_*.swift` files are **working reference components**. When asked for
texture, custom tabs, or animation, EXTEND these patterns — don't invent parallel
ones or hardcode effects inline. Each has a `#Preview` so you can verify in canvas.

## Textures (StyleKit_Textures.swift)
SwiftUI has no "texture" primitive; texture is built two ways:
1. **Procedural (preferred, no assets):** layered gradients + noise + blend modes.
   Available now:
   - `.grain(_:)` — film/paper speckle overlay (deterministic; kills flat digital look).
   - `BrushedGold` — metallic gold with directional streaks + sheen; use as a fill/stroke.
   - `.waxGloss()` — domed top highlight (the wax-seal sheen), reusable on any shape.
   To add a new procedural texture (leather, hammered metal, stone): build a small
   overlay `View` using `Canvas` + `SplitMix64` (deterministic RNG already here),
   tint from `Theme.Palette`, expose it as a `View` extension like `.grain()`.
2. **Image-based (when procedural can't get there):** a tileable PNG (paper, fabric)
   in `Assets.xcassets`, drawn with `Image(...).resizable(resizingMode: .tile)` as a
   background layer at low opacity. You wire these up; you don't paint them — if a
   texture needs real raster art, tell the user what PNG to generate.
Rule: textures are overlays/backgrounds at low opacity. Never let a texture reduce
text contrast — keep `bone`/`parchmentInk` legible.

## Modular tab system (StyleKit_CustomTabBar.swift)
`CustomTabBar(items:selection:)` is a **data-driven, reusable** bar: pass an array
of `TabBarItem`, bind a selection Int. It renders any list — that's the "modular"
part. It demonstrates the app's tab motion: a gold `matchedGeometryEffect` circle
that springs between tabs, icon scale/pulse, and a title in the display font.
- To restyle tabs: edit the `tab(_:)` builder (the active-circle fill, size, shadow).
- To change which items show: change the array passed in — never fork the component.
- The app still ships the native `TabView` (KingTasksApp.swift). Only swap to
  `CustomTabBar` when the user explicitly wants the custom look; the adoption note
  is at the bottom of that file. Keep 4 primary items; extra sections live on Home.

## Animations (StyleKit_Animations.swift)
Use the shared **motion tokens** in `enum Motion` so timing is consistent:
- `Motion.tap` — press feedback · `Motion.select` — tab/selection springs
- `Motion.appear` — entrance · `Motion.breathe` — looping glow/scale
- `Motion.slowSpin` — continuous rotation
Helpers: `.pressScale()` (tactile button shrink), `AnimatedCircleEmblem` (a
stylized circle-themed emblem: rotating dashed ring, counter-rotating inner ring,
orbiting dots, breathing glow — the reference for "stylized animation like circles").
When building new animations:
- Pull a token from `Motion`; add a new token there if you need a new timing,
  rather than scattering literal `.animation(...)` values.
- Prefer `withAnimation(Motion.x) { state = … }` for state-driven motion and
  `matchedGeometryEffect` for elements that move between positions (like the tab circle).
- Respect the theme: animated fills use `Theme.malachiteGold` / gold tokens.
- Keep motion purposeful and short (150–400ms) except ambient loops (breathe/spin).

## Workflow reminder
For any of the above: build/extend the component in its StyleKit file (or a new
`StyleKit_*.swift`), add/verify a `#Preview`, judge it in the canvas, THEN wire it
into a screen. Textures and animations are cheap to over-apply — use them where
they add hierarchy or delight, not everywhere.
