import 'package:get_it/get_it.dart';
import 'repositories/tracking_repository.dart';
import 'services/appointment_reminders.dart';
import 'services/debug_tracking_keys.dart';
import 'services/sqlcipher_tracking_storage.dart';
import 'services/tracking_storage.dart';

void configureDependencies({TrackingStorage? trackingStorage}) {
  final services = GetIt.instance;
  if (services.isRegistered<TrackingRepository>()) return;
  services.registerLazySingleton<TrackingStorage>(
    () =>
        trackingStorage ??
        SqlCipherTrackingStorage.local(
          fileName: 'regelmaessig_tracking_debug.db',
          keyProvider: DebugTrackingKeys.databaseKey,
          dataKeyProvider: DebugTrackingKeys.dataKey,
        ),
  );
  services.registerLazySingleton<TrackingRepository>(
    () => TrackingRepository(services<TrackingStorage>()),
  );
  services.registerLazySingleton<AppointmentReminders>(
    LocalAppointmentReminders.new,
  );
}
