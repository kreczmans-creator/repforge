# D01 — Project Recovery Report

Status: Final for WP 0
Date: 2026-10-31
Evidence basis: repository at commit `de7c0b1` (main), GitHub Actions runs 1–9 of workflow `build-android-apk.yml`, full job logs of runs 8 and 9, archive contents of both ZIPs, and a local build reproduction (§5).

## 1. Current repository state

| Item | Finding |
|---|---|
| Branches | `main` only (plus this WP 0 branch `ccr-ac6db77c-jcnexo`). No tags, no releases. |
| Commits | 7 commits, 2026-10-28 to 2026-10-31, all by the owner. Two are ZIP uploads; five edit the workflow file. No commit has ever changed application source as text. |
| Tracked files on `main` | `.github/workflows/build-android-apk.yml`, `RepForge-Android-Project.zip` (13,345 bytes), `RepForge-v0.3.0-Android-source.zip` (23,899 bytes). Nothing else: no README at root, no source tree, no tests, no licence. |
| Source of truth | The v0.3.0 ZIP is the active build input (workflow step "Extract Android project" unzips it). This is confirmed as the source of truth and is the central source-control defect (TD-01). |
| Competing versions | Yes. The two ZIPs contain the same nine file paths with different content. The 2026-10-28 archive (`RepForge-Android-Project.zip`) is older: `MainActivity.kt` 29,245 bytes with literal `\n` sequences in source (compile errors in run 8); `RepForgeDatabase.kt` has Room schema v1 and no `Recipe` entity. The v0.3.0 archive: `MainActivity.kt` 66,126 bytes, schema v2 with `Recipe` and migration 1→2, 22 seed recipes. The older ZIP is obsolete and nothing references it except a stale error message in the workflow. |
| Documentation | Only `README.md` inside the archive. It states the code "has not been compiled or device-tested in this environment" and lists known gaps. Its Settings screen string says "v0.1.0" while the archive and `versionName` say 0.3.0. |
| Assets/resources | None. No `res/` directory, no icon, no strings, no themes (theme set inline to `Theme.Material.Light.NoActionBar`). |
| Tests | None of any kind. |
| Gradle wrapper | Absent. CI installs Gradle 8.11.1 itself. |

### 1.1 Archive contents (v0.3.0)

```
repforge-android/
  README.md                       3,818 B
  settings.gradle.kts             (":app", AGP/Kotlin plugin repos)
  build.gradle.kts                AGP 8.7.3, Kotlin 2.0.21, Compose plugin 2.0.21, KSP 2.0.21-1.0.28
  gradle.properties               jvmargs -Xmx3g, useAndroidX, nonTransitiveRClass
  app/build.gradle.kts            compileSdk/targetSdk 35, minSdk 26, versionCode 3, versionName 0.3.0; Compose BOM 2024.12.01, Material3, icons-extended, lifecycle-runtime-ktx 2.8.7, lifecycle-viewmodel-compose 2.8.7, Room 2.6.1 (+KSP), coroutines 1.9.0, play-services-code-scanner 16.1.0
  app/src/main/AndroidManifest.xml  INTERNET permission, allowBackup=true, single exported MainActivity
  app/src/main/java/com/tempest/repforge/MainActivity.kt          1,053 lines
  app/src/main/java/com/tempest/repforge/data/RepForgeDatabase.kt   135 lines
  app/src/main/java/com/tempest/repforge/data/OpenFoodFacts.kt       ~60 lines
```

A verbatim extraction is now tracked at `legacy/android/` on this branch (checksums verified identical to the archive) so the code can be reviewed in git. No fixes were applied.

## 2. CI build status

Workflow: `.github/workflows/build-android-apk.yml`. Nine runs, nine failures, zero artefacts ever produced.

| Run | Commit | Trigger | Outcome | Failure class |
|---|---|---|---|---|
| 1 (attempt 2) | 82a566f | push | failed | CI infrastructure: workflow expected archive/paths that did not exist |
| 2, 3 | b1c6c4a | push, manual | failed in < 20 s | CI infrastructure: Android SDK package setup |
| 4, 5, 6, 7 | cc230e1 | push, manual ×3 | failed in < 45 s | CI infrastructure: `setup-android` package list |
| 8 | 3ffe04d | push | failed after 3 m 02 s | **Source compilation** (older ZIP) |
| 9 | de7c0b1 | push | failed after 36 s | **Source compilation** (v0.3.0 ZIP) |

Latest run: ID 41243131372, commit `de7c0b121e4510992edc00d81af1ef230577bce9`, 2026-10-31 21:20 UTC, job `build` (ID 124660955277).

Environment of runs 8–9 (from logs): `ubuntu-latest`, Temurin JDK 17, `android-actions/setup-android@v3` with `platform-tools`, then `sdkmanager "platforms;android-35" "build-tools;35.0.0"`, Gradle 8.11.1 via `gradle/actions/setup-gradle@v4`. Dependency resolution **succeeded** in both runs (Gradle dependency cache of ~270 MB was saved; failure occurs in `:app:kspDebugKotlin`, which runs after resolution).

### 2.1 Verified compiler errors

Run 9 (v0.3.0 ZIP), task `:app:kspDebugKotlin`:

```
e: file:///…/repforge-android/app/src/main/java/com/tempest/repforge/data/RepForgeDatabase.kt:127:36 Expecting member declaration
e: file:///…/repforge-android/app/src/main/java/com/tempest/repforge/data/RepForgeDatabase.kt:127:37 Expecting member declaration
```

Run 8 (older ZIP), same task:

```
e: …/MainActivity.kt:173:40 Expecting a top level declaration
e: …/MainActivity.kt:173:41 Expecting a top level declaration
e: …/MainActivity.kt:248:40 Expecting a top level declaration
e: …/MainActivity.kt:248:41 Expecting a top level declaration
```
Cause in the older ZIP: lines 173 and 248 contain the two characters `\` `n` between `@OptIn(ExperimentalMaterial3Api::class)` and `@Composable` instead of a line break. Not present in v0.3.0.

### 2.2 Failure classification summary

| Class | Status |
|---|---|
| CI infrastructure | Fixed as of run 8 (commits cc230e1, 3ffe04d). |
| Dependency resolution | Passing. |
| Source compilation | **Failing** (details §3). |
| Unit tests | Not applicable: no tests exist. |
| Integration tests | Not applicable. |
| Packaging / signing | Never reached. No signing configuration exists. |
| Artifact generation | Never reached. |

## 3. Confirmed source defects (v0.3.0 archive)

The three previously reported issues were checked independently against the archive and the compiler output.

| # | Reported issue | Verification | Verdict |
|---|---|---|---|
| 1 | `abstract fun dao(): RepForgeDao()` | `legacy/android/app/src/main/java/com/tempest/repforge/data/RepForgeDatabase.kt:127` reads exactly that. Kotlin parses `RepForgeDao()` as a call expression, hence "Expecting member declaration" at 127:36. Matches CI run 9. The older archive (line 91) has the correct form, so this was introduced in v0.3.0. | **Confirmed, blocking** |
| 2 | `collectAsStateWithLifecycle` without `lifecycle-runtime-compose` | `MainActivity.kt:30` imports `androidx.lifecycle.compose.collectAsStateWithLifecycle`; it is used at lines 67–71. `app/build.gradle.kts` declares `lifecycle-runtime-ktx` and `lifecycle-viewmodel-compose` but not `lifecycle-runtime-compose`, which is the artifact that contains `androidx.lifecycle.compose`. Not yet reported by CI because the parser stops at defect 1. | **Confirmed by inspection; CI evidence in §5** |
| 3 | Barcode import package | `MainActivity.kt:8` imports `com.google.android.gms.mlkit.codescanner.GmsBarcodeScanning`. The `play-services-code-scanner` artifact exposes `com.google.mlkit.vision.codescanner.GmsBarcodeScanning`. Not yet reported by CI for the same reason. | **Confirmed by inspection; CI evidence in §5** |

No other syntax errors were found by reading the three source files. Semantic errors beyond these three can only be excluded by a compile, which is what §5 provides.

## 4. Existing functionality inventory

Classification key: Verified = demonstrated on a device or by test; Unverified = code exists and reads plausibly but has never compiled or run; Partial = code exists but a core part of the feature is missing; Placeholder = UI text only; Broken = defect prevents it; Obsolete = superseded.

Because the application has never compiled, **no feature is "Implemented and verified"**. Every entry below is at best "Implemented but unverified".

| Feature | Where | Classification | Notes |
|---|---|---|---|
| App shell with 6 bottom tabs (Home, Food, Recipes, Train, Progress, Settings) | `RepForgeApp` | Unverified | Tab index held in `remember`; no navigation library; no back-stack. |
| Dark Material 3 theme with custom palette | `RepForgeApp`, colour vals | Unverified | Dark only; no light theme. |
| Home dashboard: calories remaining, protein, macro bars, today's diary, next session, latest weight, workout count | `HomeScreen` | Unverified | Pure sums over today's entries. |
| Daily targets (kcal, P, C, F) | `SettingsScreen` | Partial | In-memory only; reset on process death (admitted in UI text). |
| Food search via Open Food Facts | `OpenFoodFacts.search`, `FoodScreen` | Partial | Works only online; results logged "per 100 g" with no portion input, so macros are wrong for real servings (TD-10). |
| Barcode scan → OFF lookup → diary entry | `RepForgeApp` onScan, `OpenFoodFacts.barcode` | Broken | Import package wrong (defect 3); flow otherwise coded; also logs per 100 g. |
| Quick-add custom food with servings multiplier and meal | `FoodScreen` | Unverified | Multiplies entered macros by servings; no persistence of the custom food itself (only the diary entry). |
| Today's diary list with delete | `FoodScreen` | Unverified | `dao.deleteFood` is called; today only; no date navigation, no edit. |
| Recipe library (22 seeded recipes) with ingredients, method, freezer flag, per-serving macros, "Log serving" | `RecipesScreen`, `defaultStarterRecipes` | Partial | Seeds are hard-coded in UI file; nutrition is self-described "planning estimate"; no create/edit/delete; ingredients are free text, not linked to foods. |
| Room schema v2 with migration 1→2 | `RepForgeDatabase.kt` | Unverified | Migration SQL present; no schema export; untested. |
| Workout template builder (pipe-delimited lines) | `TrainingScreen` | Partial | Stores `"Name|sets|reps"` strings; no exercise entity. |
| Session logging (weight per set, notes) → history | `TrainingScreen` | Partial | Persists only a free-text summary and a set count; per-set data is not stored (TD-09). No PRs, no rest timer, no RPE. |
| Measurements: weight + 12 circumference sites, notes, date | `ProgressScreen` | Partial | Date is free text with no validation; no edit; delete present. |
| Trend chart per metric (Canvas) | `ProgressScreen` | Partial | No axes labels, no dates on axis, equal spacing regardless of date gaps. |
| Measurement history list with delete | `ProgressScreen` | Unverified | |
| Fibre, saved meals, meal planning, exercise library, PRs, goals beyond macros, export/backup, accounts, sync, health platforms, notifications, light theme | — | Planned but not implemented | Listed in README "Known gaps" or absent. |
| Older archive (`RepForge-Android-Project.zip`) | repo root | Obsolete | Superseded by v0.3.0. |

## 5. Local build verification

See §5.1 below (filled from the reproduction performed during WP 0).

## 6. Source-control issues
1. Application code is tracked only as ZIP blobs (TD-01). No diff, review, blame or partial change is possible.
2. Two divergent archives coexist with no marker of which is current (TD-02).
3. The workflow's guard step checks for the v0.3.0 archive but its error message names the older archive.
4. No root README, no licence, no `.gitignore`, no branch protection, no PR history.
5. Version identity is inconsistent (0.1.0 in UI, 0.3.0 in archive name and Gradle).

## 7. Technical debt and immediate risks
Full register: D05. The items that matter this week:
- **Decision risk (R-01):** continuing on the Android-only prototype contradicts the cross-platform requirement.
- **Source-control (TD-01/02):** nothing can be reviewed until code lives in the tree.
- **Data-integrity design (TD-09/10/12):** the prototype's training and portion models would need a rewrite even on Android.
- **No tests, no gates (TD-07):** every CI run so far has proven only that the pipeline can fail.

## 8. Reusable value of the existing implementation
Low as code, moderate as specification. Reusable: the measurement site list, the six-tab information architecture, the colour tokens, the Open Food Facts endpoint/field knowledge, and the 22 recipes as labelled-estimate seed data. Not reusable: the UI/data coupling, string-encoded training model, in-memory settings, raw networking. Disposition per asset: D08.
