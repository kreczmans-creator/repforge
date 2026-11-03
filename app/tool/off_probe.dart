// Manual probe: exercises the real Open Food Facts client against the live
// API. Not a test (network); run with `dart run tool/off_probe.dart`.
import 'package:dio/dio.dart';
import 'package:repforge/data/external/open_food_facts_client.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';

Future<void> main() async {
  final client = OpenFoodFactsClient(dio: Dio(), clock: const SystemClock());
  final search = await client.search('greek yogurt', limit: 5);
  switch (search) {
    case Ok(:final value):
      print('search: ${value.length} foods');
      for (final f in value) {
        print(
          '  ${f.id} | ${f.name} | ${f.brand} | '
          '${f.profile.per100Amounts.kcal} kcal/100${f.profile.per100.symbol}'
          ' | servings=${f.servings.length} | ${f.profile.provenance.name}',
        );
      }
    case Err(:final error):
      print('search failed: ${error.message} ${error}');
  }
  for (final code in ['3017624010701', '0000000000000']) {
    final r = await client.byBarcode(code);
    print(
      'barcode $code: ${switch (r) {
        Ok(:final value) => value == null ? 'not found' : '${value.name} (${value.brand}) ${value.profile.per100Amounts.kcal} kcal',
        Err(:final error) => 'failed: ${error.message}',
      }}',
    );
  }
}
