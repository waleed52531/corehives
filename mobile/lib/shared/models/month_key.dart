/// Business date keys: transactionDateKey = YYYY-MM-DD, monthKey = YYYY-MM.
/// Always derive from the business date the user picked (Asia/Karachi),
/// never from device UTC instant, to keep monthly reports stable.
class MonthKey {
  static String fromDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  static String dateKeyFromDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String current() => fromDate(DateTime.now());
}
