class AppHelpers {
  static String formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  static String getFirstName(String name) {
    final parts = name.trim().split(' ');

    return parts.isEmpty ? name : parts.first;
  }
}
