DateTime koreaToday({DateTime? now}) {
  final koreaNow = (now ?? DateTime.now()).toUtc().add(
    const Duration(hours: 9),
  );
  return DateTime(koreaNow.year, koreaNow.month, koreaNow.day);
}
