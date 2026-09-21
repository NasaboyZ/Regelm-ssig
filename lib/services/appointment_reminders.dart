import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/day_entry.dart';

abstract interface class AppointmentReminders {
  /// Returns a user-facing warning if the records saved but alarms could not.
  Future<String?> synchronize(TrackingSnapshot snapshot);
}

class LocalAppointmentReminders implements AppointmentReminders {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  @override
  Future<String?> synchronize(TrackingSnapshot snapshot) async {
    final appointments = snapshot.days.values
        .expand((d) => d.appointments)
        .where(
          (a) =>
              a.alarmMinutes != null &&
              a.startsAt
                  .subtract(Duration(minutes: a.alarmMinutes!))
                  .isAfter(DateTime.now()),
        )
        .toList();
    if (kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        ].contains(defaultTargetPlatform)) {
      return appointments.isEmpty
          ? null
          : 'Termine gespeichert. Erinnerungen sind auf diesem Gerät nicht verfügbar.';
    }
    try {
      if (!_initialized) {
        const darwin = DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: darwin,
            macOS: darwin,
          ),
        );
        _initialized = true;
      }
      // Reconcile only this feature's pending alarms; never cancel other notifications.
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending.where(
        (p) => p.payload?.startsWith('appointment:') ?? false,
      )) {
        await _plugin.cancel(id: request.id);
      }
      if (appointments.isEmpty) return null;
      final granted = switch (defaultTargetPlatform) {
        TargetPlatform.android =>
          await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission(),
        TargetPlatform.iOS =>
          await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true),
        TargetPlatform.macOS =>
          await _plugin
              .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true),
        _ => false,
      };
      if (granted != true) {
        return 'Termine gespeichert. Erlaube Mitteilungen in den Geräteeinstellungen, damit Alarme angezeigt werden.';
      }
      appointments.sort(
        (a, b) => a.startsAt
            .subtract(Duration(minutes: a.alarmMinutes!))
            .compareTo(b.startsAt.subtract(Duration(minutes: b.alarmMinutes!))),
      );
      // Darwin allows at most 64 pending local notifications.
      for (var i = 0; i < appointments.length && i < 60; i++) {
        final appointment = appointments[i];
        await _plugin.zonedSchedule(
          id: 100000 + i,
          title: 'Terminerinnerung',
          body: 'Du hast einen Termin in Regelmässig.',
          scheduledDate: tz.TZDateTime.from(
            appointment.startsAt
                .subtract(Duration(minutes: appointment.alarmMinutes!))
                .toUtc(),
            tz.UTC,
          ),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'appointments',
              'Terminerinnerungen',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
            macOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'appointment:${appointment.id}',
        );
      }
      return appointments.length > 60
          ? 'Gespeichert. Die nächsten 60 Erinnerungen sind geplant.'
          : null;
    } catch (_) {
      return 'Einträge gespeichert. Die Alarme konnten nicht aktiviert werden. Öffne den Tag und speichere erneut, um es noch einmal zu versuchen.';
    }
  }
}
