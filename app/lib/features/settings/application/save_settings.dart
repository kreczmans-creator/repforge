import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/settings/settings.dart';

/// Use case: persist app settings.
final class SaveSettings {
  const SaveSettings({required this.repository});

  final SettingsRepository repository;

  Future<Result<AppSettings>> call(AppSettings settings) async {
    if (settings.dayStartHour < 0 || settings.dayStartHour > 23) {
      return const Err(
        ValidationError('Day start must be 0–23.', field: 'dayStartHour'),
      );
    }
    if (settings.weekStartDay < 1 || settings.weekStartDay > 7) {
      return const Err(
        ValidationError('Week start must be 1–7.', field: 'weekStartDay'),
      );
    }
    try {
      await repository.save(settings);
    } on Exception catch (e) {
      return Err(StorageError('Could not save settings.', cause: e));
    }
    return Ok(settings);
  }
}
