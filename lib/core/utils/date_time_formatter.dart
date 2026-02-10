/// Utility class for formatting date and time values
/// Displays dates in Indian Standard Time format (12-hour with AM/PM)
class DateTimeFormatter {
  DateTimeFormatter._(); // Private constructor to prevent instantiation

  /// Formats DateTime to "dd MMM yyyy • hh:mm AM/PM" format
  /// Example: "27 Jan 2026 • 10:42 PM"
  static String formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    
    final day = local.day.toString().padLeft(2, '0');
    final month = months[local.month - 1];
    final year = local.year;
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    
    return '$day $month $year • ${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  /// Formats DateTime to only time "hh:mm AM/PM"
  /// Example: "10:42 PM"
  static String formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  /// Formats DateTime to only date "dd MMM yyyy"
  /// Example: "27 Jan 2026"
  static String formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    
    final day = local.day.toString().padLeft(2, '0');
    final month = months[local.month - 1];
    final year = local.year;
    
    return '$day $month $year';
  }
}
