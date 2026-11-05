import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/features/training/application/exercise_library_providers.dart';

/// Every call throws an [Error] (not an [Exception]), like a driver failure
/// surfacing as a StateError.
class _ThrowingSettings implements SettingsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('disk');
}

void main() {
  test('SetAvailableEquipment returns a storage error for any throwable '
      '(L5)', () async {
    final useCase = SetAvailableEquipment(_ThrowingSettings());
    final r = await useCase({Equipment.dumbbell});
    expect(r, isA<Err<void>>());
    expect((r as Err<void>).error, isA<StorageError>());
    final b = await useCase.setBodyweightOnly(value: true);
    expect((b as Err<void>).error, isA<StorageError>());
  });
}
