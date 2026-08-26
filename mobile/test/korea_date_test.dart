import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/korea_date.dart';

void main() {
  test('한국 시간 자정 전에는 같은 날짜를 반환한다', () {
    final today = koreaToday(now: DateTime.utc(2026, 8, 14, 14, 59));

    expect(today, DateTime(2026, 8, 14));
  });

  test('UTC 오후 3시부터 한국의 다음 날짜를 반환한다', () {
    final today = koreaToday(now: DateTime.utc(2026, 8, 14, 15));

    expect(today, DateTime(2026, 8, 15));
  });
}
