// Private named parameters cannot be initializing formals here.
// ignore_for_file: prefer_initializing_formals

import 'package:dio/dio.dart';
import 'package:repforge/data/external/open_food_facts_mapper.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/food_lookup_service.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';

/// [FoodLookupService] backed by Open Food Facts. Never throws.
class OpenFoodFactsClient implements FoodLookupService {
  OpenFoodFactsClient({
    required Dio dio,
    required Clock clock,
    String appVersion = '0.4.0',
  }) : _dio = dio,
       _clock = clock,
       _appVersion = appVersion;

  static const _fields =
      'code,product_name,brands,nutriments,nutrition_data_per,'
      'serving_size,serving_quantity,quantity';
  static const _searchUrl = 'https://search.openfoodfacts.org/search';
  static const _productUrl = 'https://world.openfoodfacts.org/api/v2/product';

  final Dio _dio;
  final Clock _clock;
  final String _appVersion;

  Options get _options => Options(
    headers: {
      'User-Agent':
          'RepForge/$_appVersion '
          '(https://github.com/kreczmans-creator/repforge)',
      'Accept': 'application/json',
    },
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 10),
    responseType: ResponseType.json,
    validateStatus: (_) => true,
  );

  @override
  Future<Result<List<Food>>> search(String query, {int limit = 20}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const Ok([]);
    final body = await _get(_searchUrl, {
      'q': trimmed,
      'page_size': limit,
      'fields': _fields,
    });
    return switch (body) {
      Ok(:final value) => Ok(mapOffSearchResponse(value, now: _clock.now())),
      Err(:final error) => Err(error),
    };
  }

  @override
  Future<Result<Food?>> byBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return const Ok(null);
    final body = await _get('$_productUrl/${Uri.encodeComponent(code)}.json', {
      'fields': _fields,
    });
    return switch (body) {
      Ok(:final value) => Ok(
        mapOffProductResponse({
          ...value,
          'code': value['code'] ?? code,
        }, now: _clock.now()),
      ),
      Err(:final error) => Err(error),
    };
  }

  Future<Result<Map<String, dynamic>>> _get(
    String url,
    Map<String, Object?> query,
  ) async {
    try {
      final res = await _dio.get<Object?>(
        url,
        queryParameters: query,
        options: _options,
      );
      final status = res.statusCode ?? 0;
      if (status == 429) {
        return Err(
          lookupError(const LookupRateLimited(), 'Open Food Facts rate limit.'),
        );
      }
      // OFF answers an unknown barcode with 404 and a status-0 body; let the
      // body mapping report "not found" rather than an outage.
      if ((status < 200 || status >= 300) && status != 404) {
        return Err(_unavailable('HTTP $status'));
      }
      final type = res.headers.value('content-type') ?? '';
      final data = res.data;
      if (type.contains('html') || data is! Map) {
        return Err(_unavailable('Unexpected response ($type)'));
      }
      return Ok(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return Err(
            lookupError(const LookupOffline(), 'Open Food Facts unreachable.'),
          );
        case DioExceptionType.transformTimeout:
        case DioExceptionType.badResponse:
        case DioExceptionType.badCertificate:
        case DioExceptionType.cancel:
        case DioExceptionType.unknown:
          if (e.error is FormatException) {
            return Err(_unavailable('Malformed response'));
          }
          return Err(_unavailable(e.type.name));
      }
    } on Object catch (e) {
      return Err(_unavailable(e.runtimeType.toString()));
    }
  }

  UnexpectedError _unavailable(String detail) => lookupError(
    LookupUnavailable(detail),
    'Open Food Facts unavailable: $detail',
  );
}
