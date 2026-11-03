# RepForge Android — native prototype

RepForge Android is the native Android companion to the first RepForge PWA. It uses Kotlin, Jetpack Compose and Room.

## Implemented
- Native Material 3 dark UI with Home, Nutrition, Training, Progress and Settings sections.
- On-device Room database for nutrition entries, workout templates, workout logs and measurements.
- Open Food Facts text search and barcode lookup.
- Google Play Services Code Scanner flow (where Google Play Services supports it).
- Quick-add food with calories/macros, meal selection and serving multiplier.
- Starter recipe library with batch ingredients, method, freezer suitability and per-serving macro estimates.
- Log one recipe serving directly to the daily food diary.
- Room schema v2 migration adds recipes without deleting existing v1 diary, workout or measurement records.
- Custom workout template builder (`Exercise | sets | reps` per line) and session logging.
- Weight and 12 circumference metrics with a selectable trend chart.

## Build
Open this folder in Android Studio (current stable recommended), allow Gradle sync, then run the `app` configuration on an Android device or emulator. Requires JDK 17 and Android SDK platform 35. Gradle wrapper files are not included; Android Studio can configure/download the wrapper.

## Known prototype gaps
- This is source code, not a prebuilt APK. It has not been compiled or device-tested in this environment.
- Settings targets are currently in-memory state, not persisted after process restart.
- Food diary UI currently shows entries for the current date only; date selection/editing and logged-food portion editing need a follow-up iteration.
- Food database nutrition is imported per 100 g; users must verify labels and portions.
- Barcode scanning uses Google Play Services Code Scanner, so availability depends on device services.
- No cloud account, cross-device sync, backup/export UI, health-platform integration, or production test suite yet.
- Recipe nutrition values are provisional estimates, not label-derived calculations; update them when exact brands, weights and cooked yields are known.
- The v1-to-v2 Room migration preserves existing diary, workout and measurement data. Backups/export are still not implemented; do not rely on this prototype as the sole store for irreplaceable records.

## Recipe library (v0.3.0)
- 22 seeded recipes: the original Smoky Chicken Burrito Wrap (8 servings) and Slow-Braised Brisket & Pork Lasagne (10 servings), plus 20 additional breakfast, lunch and dinner recipes.
- Breakfast includes turkey sausage, egg and cheese freezer wraps; berry cheesecake and chocolate-peanut-butter overnight oats; apple-cinnamon baked oats; and turkey bacon egg muffins.
- Main meals cover Korean, Mediterranean, Thai, Mexican, Moroccan, Cajun, Italian, Japanese, Vietnamese and Greek flavour profiles, with chicken, beef, pork, turkey, salmon, prawns and lamb.
- New seed records are inserted with Room `IGNORE` conflict handling on startup, so existing saved recipes and user data are retained while missing starter recipes are added.
- Recipe cards show estimated kcal and macros per serving, batch yield, ingredients and method.
- “Log serving” adds one recipe serving to the current day diary.
- Recipe cards show estimated kcal and macros per serving, batch yield, ingredients and method.
- “Log serving” adds the recipe serving to the current day diary.

## Recommended next
1. Compile, resolve any Android Studio/Gradle compatibility issues, and add automated tests.
2. Persist settings and implement edit/delete for food entries.
3. Add gram/serving quantities and per-serving conversion for food database results.
4. Add export/import and cloud sync.
5. Add progression recommendations, rest timer and scheduled workout programmes.
