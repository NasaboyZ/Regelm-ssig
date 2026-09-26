import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'repositories/tracking_repository.dart';
import 'services/appointment_reminders.dart';
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
          keyProvider: () async {
            if (kDebugMode) {
              // Public development fixture, never use for personal data.
              return 'regelmaessig-debug-test-key-v1';
            }
            throw StateError('Production key management is not configured');
          },
        ),
  );
  services.registerLazySingleton<TrackingRepository>(
    () => TrackingRepository(services<TrackingStorage>()),
  );
  services.registerLazySingleton<AppointmentReminders>(
    LocalAppointmentReminders.new,
  );
}
