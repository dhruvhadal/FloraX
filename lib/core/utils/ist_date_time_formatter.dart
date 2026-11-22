import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Global Indian Standard Time (IST = UTC + 05:30) Formatter
///
/// Ensures all timestamps, dates, and session displays across LeafGuard
/// are accurately and consistently rendered in IST while preserving UTC storage.
class IstTimeUtils {
  IstTimeUtils._();

  static const Duration istOffset = Duration(hours: 5, minutes: 30);

  /// Converts any DateTime to Indian Standard Time (UTC+05:30)
  static DateTime toIst(DateTime utcOrLocal) {
    final DateTime utc = utcOrLocal.isUtc ? utcOrLocal : utcOrLocal.toUtc();
    return utc.add(istOffset);
  }

  /// Converts a Firestore Timestamp to IST DateTime
  static DateTime timestampToIst(Timestamp timestamp) {
    return toIst(timestamp.toDate());
  }

  /// Formats in IST: "22 Nov 2026, 04:30 PM IST"
  static String formatDateTimeIst(DateTime dateTime, {bool showSeconds = false}) {
    final ist = toIst(dateTime);
    final pattern = showSeconds ? 'dd MMM yyyy, hh:mm:ss a' : 'dd MMM yyyy, hh:mm a';
    return '${DateFormat(pattern).format(ist)} IST';
  }

  /// Formats Firestore Timestamp in IST: "22 Nov 2026, 04:30 PM IST"
  static String formatTimestampIst(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    return formatDateTimeIst(timestamp.toDate());
  }

  /// Formats IST time only: "04:30 PM IST"
  static String formatTimeOnlyIst(DateTime dateTime) {
    final ist = toIst(dateTime);
    return '${DateFormat('hh:mm a').format(ist)} IST';
  }

  /// Formats IST date only: "22 Nov 2026"
  static String formatDateOnlyIst(DateTime dateTime) {
    final ist = toIst(dateTime);
    return DateFormat('dd MMM yyyy').format(ist);
  }

  /// Returns current time in IST
  static DateTime nowIst() {
    return toIst(DateTime.now().toUtc());
  }
}
