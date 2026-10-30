# Design system, typography, motion and mascot for Kuota+ (Flutter)

Scope: concrete, implementable recommendations for the Kuota+ redesign. Current tokens: primary #1E40AF, background #F6F7F9, success #15803D, warning #B45309, danger #B91C1C, Material 3 system font, light mode only. Principles: number first, color carries meaning, four states on every data screen, everyday Indonesian copy.

Local sources ran on 2026-10-30:
- ui-ux-pro-max CLI at `.claude/skills/ui-ux-pro-max/scripts/search.py`, run without `--persist`.
- taste-skill v2.1.5 `references/app-screens.md`, read from the plugin cache at `C:\Users\Haikal\.claude\plugins\cache\taste-skill\taste-skill\2.1.5\skills\taste-skill\references\app-screens.md`.
- Note: in the project's `.claude/skills/`, `design-taste-frontend` and `motion-design` are **broken symlinks** pointing to `D:/Kuliah/Semester 5/flutter/dayum/dayum/.agents/skills/...`, which no longer exists. The `gsap-*` skills are present but are not usable for Flutter (see Q2).

## Q1. What does the local ui-ux-pro-max skill recommend, and how well does it fit?

### Takeaway
Keep the stack-level and UX-rule output. Discard the generated "design system" (orange claymorphism, a scroll-storytelling pattern, Varela Round with Nunito Sans): it is tuned for kids, pets and landing pages and would break "color carries meaning", because orange collides with the amber warning color.

### Cited Findings
These are local tool outputs, run 2026-10-30. Each one is cited by the command that produced it.
- `--design-system "telco mobile self-care app friendly playful fintech" -p "Kuota+" --motion 5 --density 5` returned:
  - **Pattern:** "Scroll-Triggered Storytelling", described as a landing-page pattern with chapters and a climax CTA.
  - **Style:** "Claymorphism": thick 3-4px borders, double shadows, radius 16-24px. Its listed best fit is "Educational apps, children's apps… casual games".
  - **Colors:** primary #F97316 (orange), accent #2563EB, background #FFF7ED, foreground #9A3412, with the note "Playful orange + trust blue".
  - **Type:** Varela Round with Nunito Sans.
  - **Motion:** "Stagger List" at 300-450ms with `back.out(1.4)`, plus the tool's own caveat: "Don't use back.out on dense data tables; the overshoot reads as sloppy on informational UI".
  - **Pre-delivery checklist:** 4.5:1 text contrast, visible focus, reduced motion respected. It also lists web-only items such as `cursor-pointer` and hover states.
- `--domain typography "friendly mobile app"` returned three pairings:
  1. "Material You MD3 (Roboto System)", with the MD3 scale "Display Large 56px/400/64px. Headline Large 32px/500/40px. Title Large 22px/500/28px. Body Large 16px/400/24px. Label Medium 12px/500/16px".
  2. Baloo 2 with Comic Neue, aimed at kids.
  3. Varela Round with Nunito Sans.
- `--domain color "playful trustworthy"` returned a Pet Tech palette (orange #F97316 with blue) and an Educational palette (indigo #4F46E5 with orange accent).
- `--domain ux "mascot onboarding empty state"`:
  - Empty states: "Show helpful message and action", not "Blank empty screens".
  - Onboarding: "Provide Skip and Back buttons", not a "Locked overlay until finished".
- `--domain ux "micro interaction press feedback"`:
  - Active states: "Add pressed/active state visual change" (e.g. `active:scale-95`).
  - Haptics: "Use for confirmations and important actions", not "Vibrate on every tap".
- `--domain ux "reduced motion"`:
  - Respect motion preferences (severity High).
  - "Animate 1-2 key elements per view maximum", not "animate-bounce on 5+ elements" (High).
  - Parallax and scroll-jacking cause nausea, so show the final readable state.
- `--stack flutter "animation"` returned **0 results**; the tool suggested "animations".
- `--stack flutter "animations"` returned three rules:
  - Use implicit animations (`AnimatedContainer`/`AnimatedOpacity`) rather than an `AnimationController` for a simple fade.
  - Wrap animations in `RepaintBoundary`.
  - Use `Hero` for shared-element transitions.
  - All three are marked for flutter 3.44.x and verified 2026-08-13.
- `--stack flutter "theme tokens"` returned:
  - Read styles through `Theme.of(context).textTheme.bodyLarge`, not `TextStyle(fontSize: 16)`.
  - Use `ThemeData`, not `Color(0xFF123456)` everywhere.
  - "Support dark mode (`darkTheme`)".
- SKILL.md priority table: Accessibility first, then Touch, Performance, Style, Layout, Typography/Color, Animation, and so on. Animation anti-patterns: "One duration for every transition, Animating width/height, No reduced-motion".

### Inferences
- Keep:
  - The UX rules: press state, sparing haptics, at most 1-2 animated elements per view, reduced motion, skippable onboarding, empty state with an action.
  - The three Flutter rules: implicit animations, RepaintBoundary, Hero.
  - Theme-through-context. This matches the taste skill and Material practice.
- Discard:
  - The claymorphism style, scroll storytelling (a web landing-page pattern) and the orange/indigo palettes.
  - The kids' fonts.
  - `back.out` overshoot on data. The tool flags this itself.
  - Web-only checklist items (cursor-pointer, hover).
- The dark-mode rule conflicts with the project's light-only scope. Treat it as out of scope, but keep every color a named `ColorScheme`/`ThemeExtension` token so a dark theme stays cheap later.
- Orange as a "playful" primary is the main clash. Kuota+ already uses amber #B45309 to mean risk, and an orange brand color would blur that. Keep #1E40AF as the only action color, and put friendliness into shape, type, copy and the mascot.

### Gaps
- The tool has no telco or Indonesian-market profile; its closest matches were pets and education. Its Flutter stack data has no entries on haptics, Rive, Lottie or reduced motion.

## Q2. What do the taste skill and the GSAP skills say that applies to native mobile app screens?

### Takeaway
The taste skill's app-screen rules fit "number first" almost exactly. They put feedback-only motion on app screens and ask for tabular figures, one lead figure per screen, color as a good/bad signal, honest zero/empty/loading/error states, and a phone layout. GSAP is a web JavaScript library, so it does not run in Flutter. Only its principles carry over, mapped to Flutter APIs.

### Cited Findings
All from taste-skill `references/app-screens.md` (local file, v2.1.5). Notes on this source:
- The study behind it covers desktop app screens.
- §12 "The phone" says outright that it is a house rule, because "The study has no phone screens".

Motion:
- "App screens have no motion floor. Motion is feedback: press, hover, focus, a menu or a sheet opening, a row arriving. Nothing on the screen performs an entrance."

Lead figure (§5):
- "When one figure is the screen's answer (a balance…) it is 30-36px and at least 1.3 times its sibling figures"; "No other figure on the screen is larger."
- Units are "a smaller grey suffix".
- KPI labels are 12-16px; "the value is about 1.7 times the label". "Bold for money only."

Color (§5 Deltas):
- "Colour says good or bad, not up or down."
- A zero or undefined change is grey; "+4 (new)" rather than a green "up 100%".

Type (§9.1):
- One family. "App type is not display type": titles 18-32px, no figure at 48px or above.
- Clean scales cited: 12/14/16/24, 12/14/18/24, 12/14/16/30. Typically 4-9 sizes per screen, about 3 weights.
- "Figures: tabular on every number… anywhere it updates. Check that the face really has tabular figures."

States (§11):
- Loading: "the final layout with each value replaced by a flat grey bar at its real size… no shimmer gradient, and no shift of the layout when the data lands."
- Error: "inside the block that failed, never as a full-screen banner. One sentence saying what failed and when the data was last good… and a Retry text button."
- An empty chart is drawn as "the zero line… no picture".
- "Limits and usage: a bar at the true ratio with both ends labelled ('12.7k of 20.0k')."
- "Red is a signal, not a texture: one red mark per object at most."

Phone (§12):
- Margins 16-20px, touch targets at least 44px, data at 14px, sublines at least 12px.
- A bottom bar of 4-5 destinations.
- Charts full width, 160-200px tall, 3-4 x labels.
- KPIs in a 2-column grid, never four squeezed columns.

House rules (§13), banned:
- Gradients on buttons, cards and grounds; glass and blur.
- "An icon in a coloured circle or tinted square on every KPI or card".
- More than four chart hues.
- Emoji in labels or empty states.
- "An illustration and 'No data yet' in an empty chart".
- "A hero header, a greeting with an emoji, an illustrated welcome banner".

Other §13 rules:
- Shadows only on floating things.
- "A border or a shadow, never both."

GSAP:
- The project ships gsap-core, gsap-timeline, gsap-scrolltrigger and related skills. ui-ux-pro-max's motion output is written as `gsap.from(...)` JavaScript.
- GSAP is a browser JavaScript library and does not run in Flutter. This is inferred from the skill contents and GSAP's nature; Flutter has no GSAP runtime.

### Inferences
Mapping GSAP concepts to Flutter:

| GSAP concept | Flutter equivalent |
| --- | --- |
| `gsap.to/from` tween | Implicit `Animated*` widgets or `TweenAnimationBuilder` |
| `timeline` | One `AnimationController` with `Interval` curves, or `flutter_animate` chains |
| `stagger` | `Interval`-offset children, or `flutter_animate` `.animate(interval: …)` on lists |
| `ease: "power2.out"` | `Easing.emphasizedDecelerate` / `Curves.easeOutCubic` |
| `back.out` | `Curves.easeOutBack`, kept for the mascot and celebration only |
| `ScrollTrigger` | `ScrollController` listeners / `SliverAppBar`. For an app: do not scroll-scrub data. |
| `matchMedia(prefers-reduced-motion)` | `MediaQuery.of(context).disableAnimations`, plus the iOS `reduceMotion` caveat in Q5 |

Taste-skill rules that conflict with the brief:
- "No shimmer" conflicts with the brief's "skeleton shimmer". Recommendation: flat grey skeletons at real size, with an optional very subtle pulse (opacity 0.5↔1 over ~1s). No sweeping gradient, and none at all under reduced motion.
- The taste skill bans illustration in empty charts. That supports the mascot rule in Q4: mascots go on full-screen first-run, success and reward moments, never inside data blocks.

### Gaps
- The taste skill's evidence base is desktop dashboards. Its phone rules are its own house rules, not measured findings.

## Q3. Which typeface, figures and type scale should Kuota+ use?

### Takeaway
Use **Plus Jakarta Sans** as the single family. It was made for Jakarta's city identity, it is OFL, it is variable, and it ships tabular figures. Apply `FontFeature.tabularFigures()` to every quota, price, countdown and points number. Use a compact M3-derived scale where the lead number is 32-36px and nothing reaches 48px.

### Cited Findings
- Plus Jakarta Sans:
  - Designed by Gumpita Rahayu (Tokotype), commissioned by 6616 Studio for the Jakarta Provincial Government's "City of Collaboration" identity in 2020.
  - SIL Open Font License 1.1, variable `wght` axis.
  - The v2.600 changelog adds "Tabular Figures (.tf)". It also has stylistic alternates and multi-language support.
  - Source: [tokotype/PlusJakartaSans on GitHub](https://github.com/tokotype/PlusJakartaSans).
- The MD3 baseline scale is "Display Large 56px/400/64px. Headline Large 32px/500/40px. Title Large 22px/500/28px. Body Large 16px/400/24px. Label Medium 12px/500/16px" (local ui-ux-pro-max typography output, Result 1).
- From taste-skill app-screens §9.1:
  - Titles 18-32px; no figure at 48px or above.
  - Clean scales 12/14/16/24 and 12/14/16/30.
  - About 3 weights; tabular figures on every updating number.
  - Line height 20px at 14px and 24px at 16px. Negative tracking only on large type (-0.02em at 32px).

### Inferences
Font choice:
- Plus Jakarta Sans is preferred over Inter, Manrope, Nunito and Poppins for three reasons:
  - A local design story: it is an Indonesian foundry's typeface for Jakarta.
  - Confirmed tabular figures.
  - Friendlier, geometric shapes than Inter without Nunito's childishness.
- Indonesian uses only basic Latin, so rendering Indonesian is not a differentiator among these fonts.
- Inter (also OFL, with tabular figures) is the safe fallback.
- Poppins is common locally, but I did not verify its tabular-figure support. Gap: check `tnum` before choosing it.

Shipping the font:
- Bundle the font files as assets (OFL allows this) instead of using `google_fonts` runtime fetching. That means zero new dependencies, offline-safe rendering and no layout jump on Chrome web.
- Bundle only the needed weights (400, 500, 600, 700), or the single variable file.

Suggested scale, mapped onto `TextTheme`:

| Role | Size / line height / weight |
| --- | --- |
| Lead number on home (sisa kuota) | 36/40/700, tabular figures, -0.5 letter spacing. Unit ("GB") at 16/500 grey. |
| Secondary numbers (pulsa, masa aktif, price) | 24/32/600, tabular figures |
| Screen title | 22/28/600 (titleLarge) |
| Card title | 16/24/600 (titleMedium) |
| Body | 14/20/400 (bodyMedium); 16/24 for long copy |
| Labels/meta | 12/16/500 (labelMedium). Nothing under 11px. |

Implementation: one helper, for example `TextStyle numStyle = base.copyWith(fontFeatures: const [FontFeature.tabularFigures()])`, used for every number widget. This matters most for the count-up animation, where proportional digits make the value jitter.

Indonesian number formatting uses `.` for thousands and `,` for decimals ("Rp25.000", "12,5 GB"). Use `NumberFormat` from `intl` with the `id_ID` locale, if `intl` is already a dependency; I did not check the project.

### Gaps
- I did not verify that Flutter's text engine applies `.tf` alternates through the `tnum` feature for this font. Test once: render "111" and "888" with and without the feature and compare widths.
- I found no Indonesian-telco typography survey. The claim that MyTelkomsel, myIM3 and others use a given font is unverified.

## Q4. How should Kuota+ use a mascot, and how should one be produced?

### Takeaway
A mascot pays off in emotional, low-stakes moments: onboarding, empty first-run, payment success, streaks and rewards, and gentle warnings. It annoys or harms when it guilt-trips or crowds dense and critical flows. Give it 5-6 states mapped to app states, keep it out of checkout forms, error-dense flows and data blocks, and keep all meaning in text and color, never in the mascot alone.

### Cited Findings
- **Duolingo (Duo):**
  - The redesign put silhouette first: "if the overall shape is not appealing, then the details within that shape can't compliment it successfully".
  - Fixed traits: "Duo's color and his species… were not going to change".
  - Goal: "a single consistent design that makes Duolingo look the same regardless of where you use it".
  - The team iterated for months with daily reviews.
  - Source: [Duolingo blog, "Reshaping Duo"](https://blog.duolingo.com/reshaping-duo/).
- An App Store editorial notes that Duo originally "was closer to the Twitter bird, where you only see him in one version, posture, and expression" ([Apple App Store story](https://apps.apple.com/us/story/id1463847719)).
- Duolingo's character Lily is driven by Rive, with smooth transitions between emotional states and small head and face movements ([Rive blog](https://rive.app/blog/duolingo-s-ai-powered-video-call-brings-lily-to-life)).
- **Backlash.** Duo's guilt-trip notifications are widely criticized: users compare them to "toxic ex texts" ([The Sun Malaysia](https://thesun.my/going-viral/netizens-say-duolingo-notifications-feel-like-toxic-ex-texts)) and an academic opinion piece is titled "Guilt-tripped by an owl" ([Cursor TU/e](https://cursor.tue.nl/en/opinion/alain-starke/guilt-tripped-by-an-owl)). Specific claims such as children crying come from weak sources and are unverified ([jtbdux analysis](https://jtbdux-protocol.pages.dev/adoption-and-behavior/behavior-design-patterns/how-duolingo-engineered-50-million-daily-users-and-the-backlash-that-came-with-it)).
- **Tokopedia (Toped):**
  - Toped is "a hybrid of a shopping bag and an owl".
  - In 2019 the Product Design and Creative teams redefined him to raise engagement and broaden where he is used, with "a more 3d look" and "pale monochromatic" backgrounds.
  - Supporting characters were designed to stand out without "overshadowing the brand's mascot".
  - Source: [Tokopedia Design, "Making a Universe for Toped"](https://medium.com/tokopedia-design/making-a-universe-for-toped-and-tokopedia-ae799d46275d); see also [Life at Tokopedia](https://medium.com/life-at-tokopedia/building-toped-universe-fbc2ed925b2c).
  - In 2025 Toped and Duo did a viral mascot swap in Indonesia ([Marketing-Interactive](https://www.marketing-interactive.com/green-owls-take-flight-duolingo-and-tokopedia-s-mascot-swap-goes-viral-in-indonesia)).
- ui-ux-pro-max (local) says empty states need "helpful message and action" and onboarding must be skippable.
- taste-skill app-screens (local) bans illustration in empty charts and illustrated welcome banners on working screens.
- **Rive vs Lottie:**
  - Rive's own blog says Rive files are "typically 10-15x smaller" than equivalent Lottie files, with a 240KB to 16KB example. This is a vendor claim ([Rive blog](https://framer.rive.app/blog/rive-as-a-lottie-alternative)).
  - Comparisons say Rive suits interactive, state-driven animation and Lottie suits pre-rendered playback; Lottie's interactivity is limited after JSON export ([tillitsdone](https://www.tillitsdone.com/blogs/rive-vs-lottie--flutter-animations); [DEV](https://dev.to/uianimation/rive-vs-lottie-which-animation-tool-should-you-use-in-2025-p4m)).
  - I found no independent Flutter frame-time benchmark.
- **`rive` package on pub.dev:** version 0.14.11 (0.15.0-dev prerelease), verified publisher rive.app, supports Android and Web. You choose the Rive or Flutter renderer at file load, and the page notes possible Impeller differences ([pub.dev/packages/rive](https://pub.dev/packages/rive)).
- Tutorials describe the Duolingo-style pattern of a state machine inside the .riv file (Idle → Celebrating/Waving/Sleeping) driven by inputs from app code. These are third-party and partly promotional ([DEV](https://dev.to/uianimation/duolingo-style-animation-in-mobile-apps-building-interactive-mascots-with-rive-and-flutter-166d)).

### Inferences
Mapping app states to mascot states. One character, roughly six poses:

| App state | Mascot | Where |
| --- | --- | --- |
| Onboarding / first run | Waving, neutral-happy | Full screen, skippable |
| Quota safe (green) | No mascot, or a tiny idle in the header at most | The number leads |
| Quota at risk (amber, forecast says it runs out before masa aktif) | Gently concerned, plus a text tip and "Lihat paket hemat" | Forecast card. The mascot is optional; the text is required. |
| Quota exhausted (red) | Sleepy or "empty battery", calm, never scolding, plus the "Isi ulang" action | Home banner |
| Payment success | Celebrating, about 1.5s, once | Success screen after checkout |
| Payment failed | **No mascot.** Plain error, reason, retry. | Keeps a money flow serious |
| Empty states (no history, no notifications) | Small resting pose plus one sentence plus one action | Full-screen empty list only, not inside charts |
| Streak kept / reward earned | Cheering, plus confetti once | Rewards screen |
| Streak broken | Encouraging ("Mulai lagi hari ini"), never guilt | Rewards screen |

Rules:
- Never guilt copy in notifications. That is the main Duolingo lesson.
- Never put the mascot on checkout forms, payment-method lists, OTP or data charts.
- The mascot is decorative for screen readers (`ExcludeSemantics`); the adjacent text carries the meaning.
- The mascot never replaces the state color or the number.

Production for a student:
- **Default: static images.** Make 5-6 flat SVG or PNG poses and render them with `Image.asset`, which adds zero dependencies. Animate entrance and celebration with built-in `AnimatedScale`/`AnimatedSlide`. This covers about 90% of the value.
- **Optional upgrade: Rive.** Use one .riv file with a state machine whose inputs are `mood` (number) and `celebrate` (trigger). Add the `rive` dependency only if interactivity is wanted.
- **Prefer Rive over Lottie** when you animate: one file can hold all states, it is smaller per the vendor claim, and Duolingo-scale apps use it. Lottie fits a single one-off clip, such as a downloaded success check.
- **Designing the mascot:**
  - Follow Duo's lesson: a simple, recognizable silhouette, one fixed brand color, a limited pose set.
  - A telco-themed object character works well, for example a signal-bar or SIM-card character or a friendly "kuota" droplet.
  - Build it from circles and rounded rectangles in Figma or Inkscape using the brand blue. Avoid the green/amber/red state colors on the mascot body.
- **Licensing:** for free assets, use LottieFiles or the Rive community marketplace, checking each file's license (often Lottie Simple License or CC). Credit the author in the about screen. I did not verify specific license terms; check them per asset.

### Gaps
- I found no NN/g article on mascots specifically; the only NN/g anthropomorphism work found is about AI chatbots.
- I found no reliable sources on mascots at Gojek/GoPay, Shopee, Bukalapak, Kakao or LINE within budget. Shopee and LINE Friends are well known but were not researched here.
- I found no quantitative data on whether mascots lift retention in utility or telco apps.

## Q5. How should motion be implemented in Flutter?

### Takeaway
Use Material 3 tokens that ship in Flutter (`Durations.*`, `Easing.*`). Use built-in implicit animations for about 90% of cases, plus Hero and `HapticFeedback`. Add only the `animations` package (first-party) for shared-axis and container-transform transitions. Gate all non-essential motion on `MediaQuery.disableAnimations`.

### Cited Findings
- Flutter `Durations` (M3 tokens), from [api.flutter.dev Durations](https://api.flutter.dev/flutter/material/Durations-class.html):
  - short1-4 = 50/100/150/200ms
  - medium1-4 = 250/300/350/400ms
  - long1-4 = 450/500/550/600ms
  - extralong1-4 = 700/800/900/1000ms
- Flutter `Easing` values, from [flutter/material/motion.dart](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/motion.dart); see also [Easing class](https://api.flutter.dev/flutter/material/Easing-class.html):
  - emphasizedDecelerate `Cubic(0.05, 0.7, 0.1, 1.0)`
  - emphasizedAccelerate `Cubic(0.3, 0.0, 0.8, 0.15)`
  - standard `Cubic(0.2, 0.0, 0.0, 1.0)`
  - standardDecelerate `Cubic(0.0, 0.0, 0.0, 1.0)`
  - standardAccelerate `Cubic(0.3, 0.0, 1.0, 1.0)`
  - legacy `Cubic(0.4, 0.0, 0.2, 1.0)`
- `MediaQueryData.disableAnimations`, from [api.flutter.dev](https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html):
  - It is true when the platform asks for animations to be "disabled or reduced as much as possible".
  - On Android it maps to "Remove animations".
  - On iOS, reduce motion is exposed separately through `AccessibilityFeatures.reduceMotion` and does not set this flag.
  - Overriding it does not affect framework `AnimationController` animations, so custom widgets must check it themselves.
- `animations` package, from [pub.dev/packages/animations](https://pub.dev/packages/animations): publisher flutter.dev (verified), version 3.0.0, about 6.9k likes. It provides container transform, shared axis, fade through and fade.
- ui-ux-pro-max Flutter rules (local): implicit animations for simple cases, `RepaintBoundary` around animations, `Hero` for shared elements.

### Inferences
Token policy:
- Put a small `Motion` class in the theme folder that wraps `Durations`/`Easing`. Do not hardcode ms values in widgets.

| Use | Duration | Easing |
| --- | --- | --- |
| Press / state change | short3-short4 (150-200ms) | `standard` |
| Card or chip change, expand | medium2 (300ms) | `standard` |
| Enter (sheet, page) | medium4 (400ms) | `emphasizedDecelerate` |
| Exit | short4 (200ms) | `emphasizedAccelerate` |
| Count-up / progress ring fill | long2 (500ms) to extralong1 (700ms) | `emphasizedDecelerate` |
| Celebration | ≤1500ms total, once | — |

Reduced motion:
- `final reduce = MediaQuery.of(context).disableAnimations || MediaQuery.of(context).accessibleNavigation;`
- When `reduce` is true, use a duration of zero (jump to the final value), skip confetti and the mascot's loop, and keep color and text changes.
- Web: I could not confirm from the docs that the flag follows `prefers-reduced-motion` on Chrome. Test it in the browser; if it does not follow, treat Chrome web as a manual-only target.

Dependencies:

| Need | Choice | Added dependency? |
| --- | --- | --- |
| Implicit motion: `AnimatedContainer/Opacity/Scale/Slide/Switcher`, `TweenAnimationBuilder` (count-up), `AnimatedSwitcher` (state swaps) | Built-in | None |
| Shared element: catalog card to package detail | `Hero` | None |
| Haptics: `HapticFeedback.selectionClick()` on chip select, `lightImpact()` on primary confirm, `mediumImpact()` on payment success, `heavyImpact()` never | `HapticFeedback` (`services`) | None |
| Page transitions: `SharedAxisTransition` for checkout steps and tabs, `OpenContainer` for package card to detail, `FadeThroughTransition` for bottom-nav tabs | `animations` | Yes: first-party, small, gives M3 transitions that are hard to hand-roll |
| Mascot | `rive` | Only if the animated mascot is approved |

Skip:
- `flutter_animate`. It is convenient, but its chaining duplicates what implicit widgets already do here.
- `lottie`, unless one specific asset needs it.
- `confetti`. A ~40-line `CustomPainter` burst is enough, or the `confetti` package if time is short; justify it if you add it.

Hero and `OpenContainer` both target the catalog card to detail transition. Use one of them, not both.

Performance:
- Wrap the animated ring and the mascot in `RepaintBoundary`.
- Animate transforms and opacity, not layout size. Avoid `AnimatedContainer` height changes in long lists.

### Gaps
- I could not fetch the M3 motion page (m3.material.io renders client-side), so the usage guidance for each easing (which token for enter vs exit) is inferred from the token names and Flutter's values, not quoted.
- `animations` 3.0.0 breaking changes were not reviewed. Check the changelog against the project's Flutter version.

## Q6. Which micro-interactions should Kuota+ use, with do and don't?

### Takeaway
Animate 1-2 meaningful things per screen. The lead number and its ring on home, selection and confirmation feedback, and one celebration on rewards and payment success are enough. Everything else should be instant or a short fade.

### Cited Findings
- "Animate 1-2 key elements per view maximum" (ui-ux-pro-max ux, local).
- "Add pressed/active state visual change"; haptics "for confirmations and important actions", not every tap (ui-ux-pro-max ux, local).
- "Motion is feedback… Nothing on the screen performs an entrance"; loading uses real-size grey bars, "no shimmer gradient"; usage is shown as "a bar at the true ratio with both ends labelled" (taste-skill app-screens §§2.8, 11, local).
- Overshoot (`back.out`) "reads as sloppy on informational UI" (ui-ux-pro-max design-system output, local).
- M3 durations and easings as listed in Q5 ([Durations](https://api.flutter.dev/flutter/material/Durations-class.html), [motion.dart](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/motion.dart)).

### Inferences
Catalogue. The "Do" column uses Q5's tokens; the "Don't" column lists the failure to avoid.

| Interaction | Do | Don't |
| --- | --- | --- |
| Press feedback on cards and buttons | Scale to 0.97 over 100-150ms with `standard`, plus the Material ink ripple (keep `InkWell`) | Scale below 0.95; bounce; haptic on every tap |
| Quota number count-up | `TweenAnimationBuilder<double>` from the old value to the new one, 500-700ms, `emphasizedDecelerate`, tabular figures, only on first load and refresh | Counting from 0 on every rebuild; proportional digits (jitter); counting money in checkout totals |
| Progress ring or bar fill (sisa kuota) | Animate the sweep to the true ratio together with the count-up. The color comes from the state (green/amber/red) and switches at thresholds. Label both ends ("3,2 GB dari 10 GB"). | Gradient rings; rainbow; color as the only signal (add the "Aman"/"Hampir habis"/"Habis" label) |
| Skeleton loading | Grey bars at the real size of each value, layout fixed, optional subtle opacity pulse, static under reduced motion | Sweeping shimmer across the whole screen; layout jump when data lands; spinner for content areas |
| Pull-to-refresh | `RefreshIndicator` (built-in). Keep old values while refreshing and update a "Diperbarui 09.14" stamp. | Blanking the screen to a skeleton on refresh |
| State swap (loading → success/empty/error) | `AnimatedSwitcher` fade, 200ms | Slide or scale entrances on data blocks |
| Chip selection (filters, nominal, payment method) | Filled/outlined swap in 150ms, plus `HapticFeedback.selectionClick()` | Animating chip width; multiple accent colors |
| Bottom sheet (package detail, payment method) | `showModalBottomSheet` with M3 defaults (drag handle, enter emphasized, exit faster) | Custom spring overshoot; nested sheets |
| Checkout steps | `SharedAxisTransition` (horizontal) between steps; back reverses direction | Fancy transitions on the pay button; mascot on the payment form |
| Payment success | Check mark drawn (stroke animation about 400ms) with success green, `mediumImpact` haptic, mascot celebrate about 1.5s once, amount and reference number shown immediately | Delaying the receipt behind the animation; looping the celebration |
| Payment failed or error | Instant, inline in the failing block, one sentence plus "Coba lagi", danger color only on the icon | Shake animations on money errors; mascot; full-screen red |
| Reward points or streak | Confetti burst (≤1.2s, ≤40 particles) only when points are actually earned or a streak milestone is hit; streak calendar day fills with a 200ms scale; points count-up | Confetti on every app open; guilt copy when a streak breaks |
| Quota-at-risk forecast | Amber card fades in with the text forecast ("Kuota diperkirakan habis 3 hari sebelum masa aktif") and an action | Pulsing or blinking warning; red before it is actually exhausted |
| Charts (per-app usage) | Bars grow once on first load (300-400ms, staggered ≤40ms per bar), static on filter change or a 200ms cross-fade, one hue plus neutrals | Re-animating on every tab switch; more than four hues; animating under reduced motion |
| Quota sharing / transfer | Confirm sheet, then a success state with the amount; `lightImpact` | Animations that hide the amount or recipient |
| Notifications | List items appear without entrance; unread is a dot plus bold weight | Badge bounce; mascot in every notification |

Contrast check, computed locally with the WCAG formula on the current tokens:
- Text tokens:
  - primary #1E40AF is 8.72:1 on white and 8.14:1 on #F6F7F9.
  - success #15803D and warning #B45309 are each 5.02:1 on white and 4.68:1 on #F6F7F9. Both pass AA.
  - danger #B91C1C is 6.47:1 on white.
- Tinted chips: #15803D on #DCFCE7 is 4.57:1 and #B45309 on #FEF3C7 is 4.51:1, both just above AA. Do not lighten those text colors.
- Grey #64748B is only **4.44:1 on #F6F7F9, which fails AA for normal text**. Use #475569 (7.07:1) for secondary text on the page background, or keep #64748B only on white cards (4.76:1).

### Gaps
- No usability data was found that compares count-up animation with static numbers for comprehension. The count-up is recommended for delight only, kept short, and disabled under reduced motion.
- Confetti particle limits and timings above are design judgment, not sourced figures.
