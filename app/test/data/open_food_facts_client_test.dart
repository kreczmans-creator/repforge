import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/external/open_food_facts_client.dart';
import 'package:repforge/data/external/open_food_facts_mapper.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/food_lookup_service.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/units.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final FutureOr<ResponseBody> Function(RequestOptions) handler;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    last = options;
    return Future.sync(() => handler(options));
  }

  @override
  void close({bool force = false}) {}
}

String _fixture(String name) =>
    File('test/fixtures/off/$name').readAsStringSync();

ResponseBody _json(String body, {int status = 200}) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json; charset=utf-8'],
  },
);

final _now = DateTime.utc(2026, 11, 3, 12);

(OpenFoodFactsClient, _Adapter) _client(
  FutureOr<ResponseBody> Function(RequestOptions) h,
) {
  final adapter = _Adapter(h);
  final dio = Dio()..httpClientAdapter = adapter;
  return (OpenFoodFactsClient(dio: dio, clock: FixedClock(_now)), adapter);
}

LookupFailure _failure<T>(Result<T> r) => lookupFailureOf((r as Err<T>).error)!;

void main() {
  test('search maps Chobani hits', () async {
    final (c, _) = _client((_) => _json(_fixture('search_greek_yogurt.json')));
    final r = await c.search('greek yogurt');
    final foods = (r as Ok<List<Food>>).value;
    expect(foods, hasLength(5));
    final f = foods.first;
    expect(f.id, 'off:0894700010137');
    expect(f.name, 'Nonfat Greek Yogurt');
    expect(f.brand, 'Chobani');
    expect(f.barcode, '0894700010137');
    expect(f.source, FoodSource.openFoodFacts);
    expect(f.profile.per100, ReferenceUnit.grams);
    expect(f.profile.provenance, DataProvenance.crowdsourced);
    expect(f.profile.per100Amounts.kcal, 52.9);
    expect(f.profile.per100Amounts.proteinG, 9.41);
    expect(f.profile.per100Amounts.fibreG, isNull);
    expect(f.createdAt, _now);
    expect(foods[3].profile.per100Amounts.fibreG, 0.667);
  });

  test('sends User-Agent, Accept and query', () async {
    final (c, a) = _client((_) => _json(_fixture('search_greek_yogurt.json')));
    await c.search('greek yogurt', limit: 5);
    final h = a.last!.headers;
    expect(h['User-Agent'], contains('RepForge/0.4.0'));
    expect(h['User-Agent'], contains('github.com/kreczmans-creator/repforge'));
    expect(h['Accept'], 'application/json');
    expect(a.last!.uri.host, 'search.openfoodfacts.org');
    expect(a.last!.uri.queryParameters['q'], 'greek yogurt');
    expect(a.last!.uri.queryParameters['page_size'], '5');
  });

  test('product maps Nutella', () async {
    final (c, a) = _client((_) => _json(_fixture('product_nutella.json')));
    final r = await c.byBarcode('3017624010701');
    final f = (r as Ok<Food?>).value!;
    expect(f.name, 'Nutella');
    expect(f.brand, 'Ferrero');
    expect(f.profile.per100Amounts.kcal, 539);
    expect(f.servings, isEmpty);
    expect(f.id, 'off:3017624010701');
    expect(a.last!.uri.path, '/api/v2/product/3017624010701.json');
  });

  test('HTTP 404 with a status-0 body is Ok(null), not an outage', () async {
    final (c, _) = _client(
      (_) => _json(_fixture('product_missing.json'), status: 404),
    );
    final r = await c.byBarcode('0000000000000');
    expect(r, isA<Ok<Food?>>());
    expect((r as Ok<Food?>).value, isNull);
  });

  test('missing product is Ok(null)', () async {
    final (c, _) = _client((_) => _json(_fixture('product_missing.json')));
    final r = await c.byBarcode('00000000');
    expect(r, isA<Ok<Food?>>());
    expect((r as Ok<Food?>).value, isNull);
  });

  test('429 is rate limited', () async {
    final (c, _) = _client((_) => _json('{}', status: 429));
    expect(_failure(await c.search('x')), isA<LookupRateLimited>());
  });

  test('503 html is unavailable', () async {
    final (c, _) = _client(
      (_) => ResponseBody.fromString(
        '<html>temporarily unavailable</html>',
        503,
        headers: {
          Headers.contentTypeHeader: ['text/html'],
        },
      ),
    );
    expect(_failure(await c.search('x')), isA<LookupUnavailable>());
  });

  test('200 html is unavailable', () async {
    final (c, _) = _client(
      (_) => ResponseBody.fromString(
        '<html>oops</html>',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/html'],
        },
      ),
    );
    expect(_failure(await c.byBarcode('123')), isA<LookupUnavailable>());
  });

  test('connection timeout is offline', () async {
    final (c, _) = _client(
      (o) => throw DioException.connectionTimeout(
        timeout: const Duration(seconds: 8),
        requestOptions: o,
      ),
    );
    expect(_failure(await c.search('x')), isA<LookupOffline>());
    expect(_failure(await c.byBarcode('1')), isA<LookupOffline>());
  });

  group('edge-case hits', () {
    late List<Food> foods;
    setUp(() async {
      final (c, _) = _client((_) => _json(_fixture('search_edge_cases.json')));
      foods = ((await c.search('x')) as Ok<List<Food>>).value;
    });

    test('skips missing energy, implausible protein, and nameless hits', () {
      expect(foods.map((f) => f.id), [
        'off:1000000000001',
        'off:1000000000002',
        'off:1000000000006',
      ]);
    });

    test('energy given only in kJ is converted to kcal', () {
      final f = foods.last;
      expect(f.name, 'Kilojoule Only');
      expect(f.profile.per100Amounts.kcal, closeTo(100, 0.01)); // 418.4 kJ
    });

    test('100ml maps to millilitres with serving and joined brands', () {
      final f = foods.first;
      expect(f.profile.per100, ReferenceUnit.millilitres);
      expect(f.brand, 'Oatly, Alt');
      expect(f.servings.single.label, '250 ml');
      expect(f.servings.single.quantity.unit, ReferenceUnit.millilitres);
      expect(f.servings.single.quantity.amount, 250);
      expect(f.profile.per100Amounts.fibreG, 0.8);
    });

    test('serving data_per still maps per 100 g; empty brands null', () {
      final f = foods[1];
      expect(f.profile.per100, ReferenceUnit.grams);
      expect(f.brand, isNull);
      expect(f.servings.single.quantity.amount, 40);
    });
  });

  group('mapper', () {
    test('default serving label', () {
      final f = mapOffProduct({
        'code': '1',
        'product_name': 'A',
        'serving_quantity': 30,
        'nutriments': {'energy-kcal_100g': 10},
      }, now: _now)!;
      expect(f.servings.single.label, '1 serving');
    });

    test('zero serving quantity adds no serving', () {
      final f = mapOffProduct({
        'code': '1',
        'product_name': 'A',
        'serving_quantity': 0,
        'nutriments': {'energy-kcal_100g': 10},
      }, now: _now)!;
      expect(f.servings, isEmpty);
    });

    test('brands helper', () {
      expect(mapOffBrands(['A', 'B']), 'A, B');
      expect(mapOffBrands('Ferrero'), 'Ferrero');
      expect(mapOffBrands(<String>[]), isNull);
      expect(mapOffBrands(null), isNull);
    });

    test('search response without hits is empty', () {
      expect(
        mapOffSearchResponse(
          jsonDecode('{}') as Map<String, dynamic>,
          now: _now,
        ),
        isEmpty,
      );
    });
  });
}
