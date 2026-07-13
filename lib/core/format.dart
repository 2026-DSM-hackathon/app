/// 한국어 날짜/시간 포맷터.
///
/// intl 의 로케일 데이터 초기화(LocaleDataException)에 의존하지 않도록
/// 순수 Dart 로 구현한다 — 알림/홈에서 로케일 초기화 오류가 나지 않는다.
library;

const List<String> _weekdaysKo = <String>[
  '월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일',
];

/// 예: `7월 13일 일요일`
String formatKoreanDate(DateTime d) =>
    '${d.month}월 ${d.day}일 ${_weekdaysKo[d.weekday - 1]}';

/// 예: `오후 3:24`, `오전 12:05`
String formatTimeKo(DateTime t) {
  final bool am = t.hour < 12;
  int h = t.hour % 12;
  if (h == 0) h = 12;
  final String mm = t.minute.toString().padLeft(2, '0');
  return '${am ? '오전' : '오후'} $h:$mm';
}
