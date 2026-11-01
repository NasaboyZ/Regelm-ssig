import 'mlqr_decoded.dart';

enum TransferDataCategory {
  cycleAndDayData,
  notesAndMeasurements,
  appointments,
}

enum TransferFailureReason {
  incomplete,
  unreadable,
  verificationFailed,
  importFailed,
  cameraPermissionDenied,
  cameraUnavailable,
}

enum TransferResultAction { overview, retry }

/// Optical read or atomic import result on the receiving device.
sealed class TransferResult {
  const TransferResult();
}

/// The optical decoder recovered every payload layer; no database import or
/// cryptographic authentication is implied by this result.
class TransferCodeRead extends TransferResult {
  const TransferCodeRead(this.decoded);
  final MlqrDecoded decoded;
}

/// Create only after verification and the local database commit have succeeded.
class TransferSucceeded extends TransferResult {
  TransferSucceeded({
    required this.codeCount,
    required Set<TransferDataCategory> importedCategories,
  }) : importedCategories = Set.unmodifiable(importedCategories) {
    if (codeCount < 1) {
      throw RangeError.range(codeCount, 1, null, 'codeCount');
    }
  }

  final int codeCount;
  final Set<TransferDataCategory> importedCategories;
}

/// No data has been committed, or the failed import has been rolled back.
class TransferFailed extends TransferResult {
  TransferFailed({
    required this.reason,
    this.receivedCodeCount,
    this.expectedCodeCount,
  }) {
    final received = receivedCodeCount;
    final expected = expectedCodeCount;
    if ((received == null) != (expected == null)) {
      throw ArgumentError(
        'Empfangene und erwartete Codeanzahl gemeinsam angeben.',
      );
    }
    if (received != null && expected != null) {
      if (expected < 1) {
        throw RangeError.range(expected, 1, null, 'expectedCodeCount');
      }
      RangeError.checkValueInInterval(
        received,
        0,
        expected,
        'receivedCodeCount',
      );
      if (reason == TransferFailureReason.incomplete && received == expected) {
        throw ArgumentError(
          'Eine unvollständige Übertragung muss fehlende Codes haben.',
        );
      }
    }
  }

  final TransferFailureReason reason;
  final int? receivedCodeCount;
  final int? expectedCodeCount;
}
