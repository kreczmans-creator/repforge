# RepForge nutrition calculation specification (NUT-017)

- Status: **Revision 1.3 submitted for owner approval** (§4 approved 2026-11-04; §2.1 revised to the owner's portion-precision decision and implemented at 7c62e9c). Written before WP 7 recipe calculation work, per the owner's allocation of NUT-017.
- Scope: every nutrition figure the app stores, totals, averages, labels or displays: foods, diary entries, day and week summaries, saved meals, recipes, meal plans.
- Normative: code that calculates nutrition must follow this document. A change to a rule here needs a new revision of this document and updated worked examples. The worked examples in §10 are executed as automated tests (`app/test/domain/nutrition_spec_examples_test.dart`); test ids match the example ids.
- Open decision: **§4 carbohydrate convention (D04 OQ-14)** is written as current behaviour with a recommendation; it needs the owner's decision.

## 1. Reference basis
1. Every food states its nutrients **per 100 g or per 100 ml** (its *reference unit*). A food has exactly one reference unit.
2. Nutrients covered: energy (kcal), protein (g), carbohydrate (g), fat (g), fibre (g).
3. Nutrients for a quantity *q* in the food's reference unit: `value(q) = value_per100 × q ÷ 100`, for each nutrient independently.
4. A quantity must be in the food's reference unit. **No conversion between mass and volume** is made (no density is stored). A quantity in the other unit is a validation error and nothing is calculated (NUT-022(2)).
5. A named serving (for example "1 slice = 35 g") is a quantity in the reference unit. *n* servings = *n* × the serving's quantity, then rule 1.3.

## 2. Quantities and storage precision
1. Quantities are stored in canonical metric units (g, ml) as entered, **rounded to 0.1** of the unit at entry: to the nearest step of the stored binary value, with exact binary ties away from zero. A decimal input such as 12.35 or 1.255 is not exactly representable in binary and may round down (12.3, 1.25); inputs are limited to the stored precision, so a user cannot type a finer value. Amounts must be greater than 0 to be logged. **Portion counts** (recipe portions logged, planned recipe portions, prepared-batch portions made and remaining, saved-meal multipliers) are stored to **0.01** (same rounding rule as above) and never to a coarser step: 1.25 portions is stored and calculated as 1.25, not 1.3; 1.234 becomes 1.23. Portion inputs accept two decimals. Recipe portion counts (§9.2) and derived portions (§9.3) are numbers in their own right and are not rounded for calculation. (Revision 1.3, owner decision 2026-11-04: a 0.1 step would introduce up to 4 % error into logged nutrition.)
2. Nutrient values are calculated from the stored quantity and stored at **full double precision**. There is **no intermediate rounding** in any calculation.
3. Unit conversions (GEN-004): 1 kg = 1000 g, 1 l = 1000 ml, 1 mg = 0.001 g, exactly. **Not yet implemented:** no entry path accepts kg, l or mg today (NUT-022 entry is open), so these rules have no code and no executed example; they bind the first package that adds such entry. Imperial units are display-only (1 lb = 0.45359237 kg; 1 oz = 28.349523125 g; imperial fl oz = 28.4130625 ml); imperial entry is not offered.

## 3. Display rounding
1. Rounding happens only for display. The stored value is rounded to the displayed number of decimals; an exact tie in the stored binary value rounds away from zero (for example 2.5 → 3, 131.25 → 131.3 at one decimal).
2. Totals, tiles and diary rows show energy and grams as whole numbers. Entry details and previews may show one decimal for grams.
3. Rounding a displayed total never changes the stored values or the totals built from them; the sum of displayed parts may differ from the displayed total by rounding.

## 4. Carbohydrate convention (D04 OQ-14 — **approved by the owner 2026-11-04**)
**Current behaviour:** carbohydrate is stored **exactly as stated by the source**, and fibre is a separate nutrient. The app never adds fibre to, or subtracts fibre from, carbohydrate. Open Food Facts supplies `carbohydrates_100g`, which for EU/UK labels is *available* carbohydrate (fibre listed separately); a custom food stores what the user types from the label.

**Decision (owner, 2026-11-04):** the UK/EU convention. Carbohydrate means **available carbohydrate**; fibre is recorded and displayed separately and is **never added to or subtracted from** carbohydrate; energy is the stated source energy (§5), never recalculated from macros. Accepted limitation: US-labelled products state total carbohydrate (fibre included) and the app cannot detect this, so their carbohydrate is overstated by their fibre.

## 5. Energy
1. Energy is the **stated kcal value** of the source. If only kJ is stated, `kcal = kJ ÷ 4.184`. If both are stated, kcal is used as stated.
2. Energy is **never calculated from macronutrients** (no Atwater factors), and energy from fibre is not modelled separately.
3. Energy is required for every food; a food without energy cannot be stored.

## 6. Validation limits (per 100 g or ml)
Energy 0–900 kcal. Protein, carbohydrate, fat, fibre 0–100 g each, or unknown. Negative, NaN and infinite values are rejected. An explicit 0 is a known zero; a blank or absent value is unknown.

## 7. Unknown values (NUT-021)
1. An unknown nutrient is stored and carried as unknown (null), **never as 0**.
2. Scaling keeps unknown as unknown.
3. A **total** (day, week, saved meal) is the sum of the **known** values of each nutrient, together with the **count of inputs that did not know it**. A total is unknown only when no input knows the nutrient. It is presented as the known sum with an "N unknown" marker.
4. A total of nothing (an empty day) is a **known zero** for every nutrient.
5. A **recipe** nutrient is complete only if every ingredient knows it. If any ingredient lacks it, the recipe's per-portion value for that nutrient is **incomplete**: the value stored in a diary snapshot is unknown (null), and the recipe view shows the partial sum labelled "incomplete" (RCP-007(2)).
6. Averages (week): energy is averaged over **logged days** (days with at least one entry). Each other nutrient is averaged over the logged days that **know** it; days that do not know it are excluded from numerator and denominator and reported as "N days unknown". An average is unknown when no logged day knows the nutrient. Days without entries are never counted.

## 8. Provenance (NUT-018, NUT-019; D04 §7 amendment)
1. Labels, strongest to weakest: **verified › crowdsourced › user-entered › estimated**.
2. A total, recipe or snapshot built from several inputs carries the **weakest** label among its inputs.
3. A recipe is **computed** from its ingredients only when it has at least one linked ingredient, **every** linked ingredient has a nutrient snapshot, **and it has no ingredient notes**. A note is a free-text ingredient the app cannot calculate, so a recipe that has any note (blank notes are ignored) is incomplete even when its linked ingredients are all calculable. Any other recipe uses its **declared** per-portion values, labelled **estimated** (seed recipes, RCP-007(1), NUT-021). A recipe with notes but no declared values has no per-portion nutrition (null), never a partial sum shown as complete.
4. Data entered or edited by the user is never labelled verified.

## 9. Recipes (RCP-006, 008, 009, 012, 013)
1. Recipe total = sum of ingredient nutrients (rule 1.3 for each ingredient, from its stored per-100 snapshot), with §7.5 for unknowns.
2. **Per portion** = total ÷ portions. Portions are a positive number; editing the portion count changes per-portion values and nothing else.
3. **Portion by weight** (RCP-008(2)): with a recipe total weight *W* g (the cooked yield entered by the user; defaults to the sum of ingredient grams when every ingredient is in g) and a portion weight *w* g, portions = *W* ÷ *w* (fractional allowed).
4. **Scaling** (RCP-009) by factor *f* = target portions ÷ portions, or target total weight ÷ *W*: each ingredient quantity × *f*; per-portion values are unchanged. Scaled quantities are kept exactly (not rounded to 0.1), so per-portion values stay exactly equal; they are rounded only for display. Scaling is a view; it changes the saved recipe only on "save as new" or "overwrite".
5. **Logging** (RCP-012): *n* portions → per-portion × *n*; *g* grams → total × *g* ÷ *W*. The diary entry stores a nutrient **snapshot**, the recipe name and portion count, and a link to the recipe; editing the recipe later never changes the entry (RCP-013).
6. Ingredient nutrient snapshots are taken from the food when the ingredient is added (per 100 of the food's reference unit). A later edit of the food does not change the recipe until the ingredient is re-linked.

## 10. Worked examples (executed as tests)
Foods used: **Oats** 380 kcal, P 13, C 60, F 7, fibre 10 per 100 g, verified. **Milk** 64 kcal, P 3.4, C 4.8, F 3.6 per 100 ml, fibre unknown, crowdsourced. **Bread** 250 kcal, P 9, C 45, F 3, fibre 6 per 100 g, serving "1 slice = 35 g", user-entered. **Chicken** 120 kcal, P 20, C 0, F 2 per 100 g, fibre unknown, verified.

| Id | Rule | Input | Expected |
|---|---|---|---|
| E01 | 1.3 | 150 g Oats | 570 kcal, P 19.5, C 90, F 10.5, fibre 15 |
| E02 | 1.3 | 250 ml Milk | 160 kcal, P 8.5, C 12, F 9, fibre unknown |
| E03 | 1.4 | 100 ml of Oats | validation error, nothing calculated |
| E04 | 2.1 | log 0 g Oats | validation error "Enter an amount greater than zero." |
| E05 | 2.1 | 12.36 g entered | stored 12.4 g |
| E06 | 1.5 | 2 slices Bread | 70 g → 175 kcal |
| E07 | 1.5, 2.2 | 1.5 slices Bread | 52.5 g → 131.25 kcal stored; displayed "131" |
| E08 | 7.2 | 50 g Chicken | 60 kcal, P 10, fibre unknown |
| E09 | 7.3 | day: 200, 350, 125 kcal | 675 kcal (NUT-001) |
| E10 | 7.3 | day protein: 20, unknown, 11 | known 31 g, 1 unknown |
| E11 | 7.3 | day fibre: all entries unknown | unknown (shown n/a), not 0 |
| E12 | 7.4 | empty day | every nutrient a known 0, fibre 0 |
| E13 | 5.1 | energy only 1674 kJ | 400.0956… kcal; displayed "400" |
| E14 | 5.1 | 100 kcal and 1000 kJ stated | 100 kcal |
| E15 | 5.2 | stated 100 kcal with P 10, C 10, F 10 | 100 kcal (not 170) |
| E16 | 4 | 50 g of a food with C 60, fibre 8 | C 30, fibre 4 (no addition or subtraction) |
| E17 | 6 | protein 101 g per 100 | validation error |
| E18 | 6 | energy 901 kcal per 100 | validation error |
| E19 | 6 | fat −1 | validation error |
| E20 | 6, 7.1 | macros blank, energy 300 | accepted; macros unknown |
| E21 | 6 | protein explicitly 0 | known 0, not unknown |
| E22 | 8.2 | verified + estimated | estimated |
| E23 | 8.2 | verified + crowdsourced | crowdsourced |
| E24 | 8.2 | crowdsourced + user-entered | user-entered |
| E25 | 8.2 | all verified | verified |
| E26 | 9.2 | recipe: 400 g Chicken, 4 portions | P 20 g per portion (RCP-006(1)) |
| E27 | 9.2 | E26 with 5 portions | P 16 g per portion (RCP-008(1)) |
| E28 | 7.5 | recipe: 100 g Oats + 100 g Chicken, 2 portions | per portion 250 kcal, P 16.5; fibre incomplete → snapshot unknown, recipe view partial 5 g "incomplete" |
| E29 | 8.3 | recipe with one unlinked ingredient, declared 460 kcal per portion | 460 kcal, estimated |
| E30 | 9.5 | log 1.5 portions of a recipe at 400 kcal per portion | 600 kcal (RCP-012(1)) |
| E31 | 9.4 | scale E26 from 4 to 6 portions | Chicken 600 g; per portion P 20 g unchanged (RCP-009(1)) |
| E32 | 9.3, 9.5 | recipe total 1200 kcal, *W* 1200 g, portion 300 g; log 450 g | 4 portions; 450 g → 450 kcal (1.5 portions) |
| E33 | 7.6 | week: day A 1000 kcal P 90; day B 2000 kcal P unknown | avg 1500 kcal; avg P 90 (1 day unknown) |
| E34 | 7.6 | week with 2 logged days out of 7, 1800 and 2200 kcal | avg 2000 kcal (5 unlogged days excluded) |
| E35 | 2.3 | 100 lb (display conversion) | 45.359237 kg ± 0.001 (kg/l/mg entry not implemented, see §2.3) |
| E36 | 3.1 | display 19.5, 2.25 (1 dp), 131.25 (1 dp) | "20", "2.3", "131.3" |
| E37 | 8.2, 9 | recipe: 100 g Oats (verified) + 250 ml Milk (crowdsourced) | recipe provenance crowdsourced |
| E38 | 8.3 | recipe: 4 portions, 3 ingredient notes, declared 460 kcal per portion, plus one linked 100 g Oats | 460 kcal per portion, estimated (not computed from the oats alone) |
| E39 | 2.1, 9.5 | log 1.25 portions of a recipe at 400 kcal and P 30 per portion | stored 1.25 portions (not 1.3); 500 kcal, P 37.5; diary row "1.25 portions" |
| E40 | 2.1 | log 1.234 portions of the E39 recipe | stored 1.23 portions; 492 kcal |
| E41 | 2.1 | prepared batch of 2 portions; consume 0.75, then 1.25 | 1.25 left, then 0 left (never below 0) |

## 11. Change history
| Revision | Date | Change |
|---|---|---|
| 1 | 2026-11-04 | First version, describing behaviour at commit 3111812 plus the approved crowdsourced ordering; §4 pending owner decision. |
| 1.1 | 2026-11-04 | §2.3 and E35 narrowed: metric multiple conversions have no code path yet (found while implementing the examples). Results: 35 examples pass, E31–E32 pending WP 7 stage 1, none fail. |
| 1.2 | 2026-11-04 | §8.3: a recipe with any ingredient note is not computed; it uses its declared values (estimated), or has no per-portion nutrition when none are declared (review finding H1). Example E38 added. §2.1: portion counts are entered and stored in 0.1 steps. §9.4: scaled quantities are not rounded, so per-portion values are exactly unchanged. E06/E07 use `ServingSize.quantityFor`. |
| 1.3 | 2026-11-04 | §2.1: portion counts stored to 0.01, not 0.1 (owner decision); examples E39–E41. §4: UK/EU carbohydrate convention approved by the owner. §2.1 rounding wording corrected to the binary-value rule the code has always used (independent review, low finding). |
