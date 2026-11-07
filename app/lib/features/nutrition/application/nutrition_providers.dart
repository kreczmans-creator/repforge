import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/goals/daily_targets.dart';
import 'package:repforge/domain/nutrition/food_lookup_service.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/nutrition/saved_meal.dart';
import 'package:repforge/domain/nutrition/summaries.dart';
import 'package:repforge/features/dashboard/application/dashboard_providers.dart';
import 'package:repforge/features/nutrition/application/cache_food.dart';
import 'package:repforge/features/nutrition/application/create_custom_food.dart';
import 'package:repforge/features/nutrition/application/log_food.dart';
import 'package:repforge/features/nutrition/application/lookup_barcode.dart';
import 'package:repforge/features/nutrition/application/recent_items.dart';
import 'package:repforge/features/nutrition/application/saved_meals.dart';
import 'package:repforge/features/nutrition/application/scan_session.dart';

/// The diary day the Fuel tab is showing. Defaults to today and follows the
/// day rollover until the user navigates away from today.
class SelectedDay extends Notifier<String> {
  bool _pinned = false;

  @override
  String build() {
    final today = ref.watch(todayKeyProvider);
    return _pinned ? state : today;
  }

  void set(String day) {
    _pinned = day != ref.read(todayKeyProvider);
    state = day;
  }

  void shift(int days) {
    // Calendar arithmetic (not Duration) so DST days do not repeat or skip.
    final d = DateTime.parse(state);
    set(dayKey(DateTime(d.year, d.month, d.day + days)));
  }

  void today() {
    _pinned = false;
    state = ref.read(todayKeyProvider);
  }
}

final selectedDayProvider = NotifierProvider<SelectedDay, String>(
  SelectedDay.new,
);

/// Entries for the selected day.
final selectedDayEntriesProvider = StreamProvider<List<FoodLogEntry>>(
  (ref) => ref
      .watch(foodLogRepositoryProvider)
      .watchDay(ref.watch(selectedDayProvider)),
);

/// Intake vs targets for the selected day.
final selectedDaySummaryProvider = Provider<AsyncValue<DailySummary>>((ref) {
  final entries = ref.watch(selectedDayEntriesProvider);
  final targets = ref.watch(dailyTargetsProvider);
  if (entries.hasError) {
    return AsyncError(entries.error!, entries.stackTrace ?? StackTrace.empty);
  }
  if (targets.hasError) {
    return AsyncError(targets.error!, targets.stackTrace ?? StackTrace.empty);
  }
  if (entries.isLoading || targets.isLoading) return const AsyncLoading();
  return AsyncData(
    DailySummary.fromEntries(
      day: ref.watch(selectedDayProvider),
      entries: entries.value!,
      targets: targets.value!,
    ),
  );
});

/// Seven-day summary ending on the selected day.
final weeklySummaryProvider = FutureProvider<WeeklySummary>((ref) async {
  final end = DateTime.parse(ref.watch(selectedDayProvider));
  final days = lastSevenDays(end);
  // Re-run when the selected day's entries change.
  ref.watch(selectedDayEntriesProvider);
  final entries = await ref
      .watch(foodLogRepositoryProvider)
      .forDays(days.first, days.last);
  return WeeklySummary.fromEntries(days: days, entries: entries);
});

/// The weakest provenance among the entries of the seven days that
/// [weeklySummaryProvider] covers (NUT-019); null when nothing was logged.
final weeklyProvenanceProvider = FutureProvider<DataProvenance?>((ref) async {
  final end = DateTime.parse(ref.watch(selectedDayProvider));
  final days = lastSevenDays(end);
  ref.watch(selectedDayEntriesProvider);
  final entries = await ref
      .watch(foodLogRepositoryProvider)
      .forDays(days.first, days.last);
  return weakestProvenance(entries.map((e) => e.provenance));
});

final cacheFoodProvider = Provider<CacheFood>(
  (ref) => CacheFood(foods: ref.watch(foodRepositoryProvider)),
);

final logFoodProvider = Provider<LogFood>(
  (ref) => LogFood(
    foods: ref.watch(foodRepositoryProvider),
    log: ref.watch(foodLogRepositoryProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

final updateFoodLogEntryProvider = Provider<UpdateFoodLogEntry>(
  (ref) => UpdateFoodLogEntry(
    log: ref.watch(foodLogRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final deleteFoodLogEntryProvider = Provider<DeleteFoodLogEntry>(
  (ref) => DeleteFoodLogEntry(log: ref.watch(foodLogRepositoryProvider)),
);

final createCustomFoodProvider = Provider<CreateCustomFood>(
  (ref) => CreateCustomFood(
    foods: ref.watch(foodRepositoryProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

final savedMealsProvider = StreamProvider<List<SavedMeal>>(
  (ref) => ref.watch(savedMealRepositoryProvider).watchAll(),
);

final saveMealFromEntriesProvider = Provider<SaveMealFromEntries>(
  (ref) => SaveMealFromEntries(
    savedMeals: ref.watch(savedMealRepositoryProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

final deleteSavedMealProvider = Provider<DeleteSavedMeal>(
  (ref) => DeleteSavedMeal(savedMeals: ref.watch(savedMealRepositoryProvider)),
);

final logSavedMealProvider = Provider<LogSavedMeal>(
  (ref) => LogSavedMeal(
    log: ref.watch(foodLogRepositoryProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

/// Result of a food search: local matches first, then online matches not
/// already present locally, with the online status reported separately so
/// the UI can say "offline" without hiding local results.
final class FoodSearchState {
  const FoodSearchState({
    this.query = '',
    this.local = const [],
    this.online = const [],
    this.searchingOnline = false,
    this.onlineFailure,
  });

  final String query;
  final List<Food> local;
  final List<Food> online;
  final bool searchingOnline;
  final LookupFailure? onlineFailure;

  bool get isEmptyQuery => query.trim().length < 2;

  FoodSearchState copyWith({
    String? query,
    List<Food>? local,
    List<Food>? online,
    bool? searchingOnline,
    LookupFailure? onlineFailure,
    bool clearFailure = false,
  }) => FoodSearchState(
    query: query ?? this.query,
    local: local ?? this.local,
    online: online ?? this.online,
    searchingOnline: searchingOnline ?? this.searchingOnline,
    onlineFailure: clearFailure ? null : (onlineFailure ?? this.onlineFailure),
  );
}

/// Debounced search: local results as you type, online results 400 ms after
/// the last keystroke. Stale online responses are discarded.
class FoodSearchController extends Notifier<FoodSearchState> {
  Timer? _debounce;
  int _requestId = 0;

  @override
  FoodSearchState build() {
    ref.onDispose(() {
      _debounce?.cancel();
      _requestId++; // invalidates in-flight work after dispose
    });
    return const FoodSearchState();
  }

  Future<void> setQuery(String query) async {
    _debounce?.cancel();
    final id = ++_requestId;
    state = state.copyWith(
      query: query,
      online: const [],
      searchingOnline: false,
      clearFailure: true,
    );
    if (state.isEmptyQuery) {
      state = state.copyWith(local: const []);
      return;
    }
    final local = await ref.read(foodRepositoryProvider).search(query);
    if (!ref.mounted || id != _requestId) return;
    state = state.copyWith(local: local);
    _debounce = Timer(const Duration(milliseconds: 400), () => _online(id));
  }

  Future<void> _online(int id) async {
    if (id != _requestId) return;
    state = state.copyWith(searchingOnline: true);
    final result = await ref
        .read(foodLookupServiceProvider)
        .search(state.query);
    if (!ref.mounted || id != _requestId) return;
    switch (result) {
      case Ok(:final value):
        final localIds = {for (final f in state.local) f.barcode ?? f.id};
        state = state.copyWith(
          online: [
            for (final f in value)
              if (!localIds.contains(f.barcode ?? f.id)) f,
          ],
          searchingOnline: false,
        );
      case Err(:final error):
        state = state.copyWith(
          searchingOnline: false,
          onlineFailure:
              lookupFailureOf(error) ??
              const LookupUnavailable('Unexpected error'),
        );
    }
  }

  void clear() {
    _debounce?.cancel();
    _requestId++;
    state = const FoodSearchState();
  }
}

final NotifierProvider<FoodSearchController, FoodSearchState>
foodSearchControllerProvider =
    NotifierProvider.autoDispose<FoodSearchController, FoodSearchState>(
      FoodSearchController.new,
    );

final lookupBarcodeProvider = Provider<LookupBarcode>(
  (ref) => LookupBarcode(
    foods: ref.watch(foodRepositoryProvider),
    lookup: ref.watch(foodLookupServiceProvider),
  ),
);

/// State machine behind the barcode scan screen.
final NotifierProvider<ScanSession, ScanState> scanSessionProvider =
    NotifierProvider.autoDispose<ScanSession, ScanState>(ScanSession.new);

final loadRecentItemsProvider = Provider<LoadRecentItems>(
  (ref) => LoadRecentItems(
    log: ref.watch(foodLogRepositoryProvider),
    foods: ref.watch(foodRepositoryProvider),
    recipes: ref.watch(recipeRepositoryProvider),
  ),
);

/// Recently logged foods and recipes for the add flow. Recomputed when the
/// selected day's entries change, so a fresh log shows up on reopening.
// ignore: specify_nonobvious_property_types
final recentItemsProvider = FutureProvider.autoDispose<List<RecentItem>>((
  ref,
) async {
  ref.watch(selectedDayEntriesProvider);
  return switch (await ref.watch(loadRecentItemsProvider)()) {
    Ok(:final value) => value,
    Err() => const <RecentItem>[], // recents are a convenience, not critical
  };
});
