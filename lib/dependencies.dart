import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'repositories/tracking_repository.dart';
import 'services/appointment_reminders.dart';
import 'services/tracking_storage.dart';

void configureDependencies() {
  final services = GetIt.instance;
  if (services.isRegistered<TrackingRepository>()) return;
  services.registerLazySingleton<TrackingStorage>(
    () => const SecureTrackingStorage(FlutterSecureStorage()),
  );
  services.registerLazySingleton<TrackingRepository>(
    () => TrackingRepository(services<TrackingStorage>()),
  );
  services.registerLazySingleton<AppointmentReminders>(
    LocalAppointmentReminders.new,
  );
}
