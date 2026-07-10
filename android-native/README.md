# Awkati

A native Android successor to TaskFlow Pro (`prayer_time_manager`), built on
the thesis that the five daily prayers are the skeleton of the day, not an
offset bolted onto a clock-based task list. Full product/engineering plan:
see the conversation this scaffold came from, or ask for it to be
regenerated.

## Status: M0 (Foundation)

| Module | State |
|---|---|
| `core:domain` | **Builds and passes 25/25 tests** in this sandbox (pure Kotlin/JVM, no Android SDK needed) |
| `core:designsystem` | Written, reviewed, **not build-verified here** (needs AGP + Android SDK) |
| `app` | Written, reviewed, **not build-verified here** (needs AGP + Android SDK) |
| Gradle wrapper | Real, byte-identical files fetched from the official `gradle/gradle` v8.14.3 tag. Its first-run download could not be exercised in this sandbox (see below) |

### Why the split

This scaffold was authored in a sandboxed environment whose network policy
blocks `dl.google.com` and GitHub's release-asset host — both required to
resolve the Android Gradle Plugin, the Android SDK, and to bootstrap the
Gradle wrapper's own distribution. Maven Central was reachable, which is
enough to build a plain Kotlin/JVM module. So:

- **`core:domain`** was deliberately kept free of any Android dependency —
  it wraps `adhan` (prayer time calculation) and implements `occursOn`
  (the single recurrence engine) in pure Kotlin — specifically so it could
  be built and unit-tested for real in that environment, not just written
  and hoped for. It's also the KMP-ready core if iOS is ever pursued.
- **`core:designsystem`** and **`app`** need the Android SDK and were
  written with the same care but could not be compiled there. Run
  `./gradlew build` on a machine with Android Studio / the SDK installed —
  that is the first thing to do with this scaffold.

### First build

```bash
./gradlew build
./gradlew :core:domain:test   # already known-green; the rest needs the SDK
./gradlew :app:installDebug   # requires a connected device/emulator
```

If `./gradlew` fails on the very first invocation trying to download the
Gradle distribution, your network reached this repo but not
`services.gradle.org` — check a proxy/VPN, or point
`gradle/wrapper/gradle-wrapper.properties` at a mirror.

## Module map

```
core/domain/         Pure Kotlin. Prayer engine (adhan wrapper), day-segment
                      math, Anchor/Recurrence models, occursOn(). Has tests.
core/designsystem/    Compose Material3 theme: AwkatiColors, AwkatiTypography,
                      AwkatiTheme. Both light and dark defined from day one.
app/                  Single-activity Compose app. MainActivity -> TodayScreen,
                      which renders the day as six SegmentWindows using
                      core:domain -- the thesis screen. Hilt-wired.
```

## Rules encoded from TaskFlow Pro's post-mortem

These aren't style preferences, they're direct responses to real bugs found
and fixed in TaskFlow Pro (see that repo's PR #1 for the full list):

1. **One recurrence function.** `occursOn()` in `core:domain` is the only
   place "does this item occur on date X" is ever computed. TaskFlow Pro had
   two independently-maintained copies that disagreed.
2. **Occurrences are a table, not a field.** Per-date completion belongs in
   `Occurrence`, never crammed onto the `Item` as a list of date strings —
   that's what made completion state split-brained across screens.
3. **Real foreign keys.** `Item.areaId` is a column, not a `#hashtag`
   embedded in a text field.
4. **No secrets, ever, in any commit.** Not even ones you plan to rotate
   later.
5. **Manifest permissions land in the same commit as the feature that uses
   them.** Never speculatively.
6. **No raw color literals in UI code.** Everything goes through
   `AwkatiColors` / `MaterialTheme.colorScheme`, checked in both themes.

## Roadmap

- **M1** — Today screen wired to real location + item CRUD, notifications
  (AlarmManager + WorkManager), home-screen widget (Glance).
- **M2** — Routines with streaks, focus timer, Ramadan mode, qibla, JSON
  import from TaskFlow Pro.
- **M3** — Firebase sync (soft-deletes + `updatedAt` merge rules designed
  and tested *before* the first sync ships), AI quick-capture fallback,
  Wear tile, 1.0.
