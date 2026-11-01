import 'dart:convert';

import '../models/transfer_result.dart';

class TransferResultViewModel {
  const TransferResultViewModel({required this.result, this.isPreview = false});

  final TransferResult result;
  final bool isPreview;

  bool get codeReadOnly => result is TransferCodeRead;
  bool get succeeded => result is TransferSucceeded || codeReadOnly;
  String get title => codeReadOnly
      ? 'Multi-Layer-QR gelesen'
      : succeeded
      ? 'Übertragung abgeschlossen'
      : 'Übertragung nicht abgeschlossen';

  String get description => switch (result) {
    TransferCodeRead() =>
      'Alle Nutzdatenebenen dieses Codes wurden aus dem Kamerabild zurückgewonnen.',
    TransferFailed(reason: TransferFailureReason.cameraPermissionDenied) =>
      'Bitte erlaube den Kamerazugriff in den Geräteeinstellungen und versuche es erneut.',
    TransferFailed(reason: TransferFailureReason.cameraUnavailable) =>
      'Die Kamera konnte nicht gestartet werden. Schliess andere Kamera-Apps und versuche es erneut.',
    TransferSucceeded() =>
      'Deine Daten wurden geprüft und auf diesem Gerät wiederhergestellt.',
    TransferFailed(reason: TransferFailureReason.incomplete) =>
      'Es wurden nicht alle QR-Codes empfangen. '
          'Die Daten konnten deshalb nicht vollständig wiederhergestellt werden.',
    TransferFailed(reason: TransferFailureReason.unreadable) =>
      'Die QR-Codes konnten nicht zuverlässig gelesen werden. '
          'Bitte halte beide Geräte ruhig und versuche es erneut.',
    TransferFailed(reason: TransferFailureReason.verificationFailed) =>
      'Die empfangenen Daten konnten nicht sicher geprüft oder entschlüsselt '
          'werden. Prüfe deine Passphrase und versuche es erneut.',
    TransferFailed(reason: TransferFailureReason.importFailed) =>
      'Die empfangenen Daten konnten auf diesem Gerät nicht gespeichert werden. '
          'Bitte versuche es erneut.',
  };

  List<TransferDataCategory> get categories => switch (result) {
    TransferCodeRead() => [],
    TransferSucceeded(:final importedCategories) => [
      for (final category in TransferDataCategory.values)
        if (importedCategories.contains(category)) category,
    ],
    TransferFailed() => TransferDataCategory.values,
  };

  String get verificationLabel => switch (result) {
    TransferCodeRead() => 'Alle Nutzdatenebenen dekodiert',
    TransferSucceeded() => 'Integritätsprüfung erfolgreich',
    TransferFailed(reason: TransferFailureReason.verificationFailed) =>
      'Datenprüfung nicht erfolgreich',
    TransferFailed(reason: TransferFailureReason.importFailed) =>
      'Speichern nicht abgeschlossen',
    TransferFailed() => 'Keine Daten übernommen',
  };

  String get reassurance => codeReadOnly
      ? 'Der Code wurde gelesen. Es wurden keine Gesundheitsdaten importiert. '
            'Die Paketansicht findest du in den Übertragungsdetails.'
      : succeeded
      ? 'Deine Daten sind jetzt auf diesem Gerät verfügbar und bleiben '
            'lokal verschlüsselt gespeichert.'
      : 'Deine bisherigen Daten bleiben unverändert. '
            'Du kannst die Übertragung erneut starten.';

  String get codeSummary => switch (result) {
    TransferCodeRead(:final decoded) =>
      '1 Multi-Layer-QR-Code · ${decoded.packets.length} Datenebenen · ${decoded.dummyCount} Füllebenen',
    TransferSucceeded(:final codeCount) =>
      '$codeCount von $codeCount Codes empfangen',
    TransferFailed(:final receivedCodeCount, :final expectedCodeCount)
        when receivedCodeCount != null && expectedCodeCount != null =>
      '$receivedCodeCount von $expectedCodeCount Codes empfangen',
    TransferFailed() => 'Keine bestätigte Codeanzahl verfügbar',
  };

  String get dataSummary => result is TransferSucceeded
      ? 'Daten geprüft und gespeichert'
      : 'Keine Daten gespeichert';

  List<String> get packetPreviews => switch (result) {
    TransferCodeRead(:final decoded) => [
      for (var i = 0; i < decoded.packets.length; i++)
        'Ebene ${i + 1} · ${decoded.packets[i].length} Bytes\n'
            '${utf8.decode(decoded.packets[i].take(300).toList(), allowMalformed: true)}'
            '${decoded.packets[i].length > 300 ? '…' : ''}',
    ],
    _ => [],
  };

  String categoryLabel(TransferDataCategory category) => switch (category) {
    TransferDataCategory.cycleAndDayData => 'Zyklus- und Tagesdaten',
    TransferDataCategory.notesAndMeasurements => 'Notizen und Messwerte',
    TransferDataCategory.appointments => 'Termine',
  };
}
