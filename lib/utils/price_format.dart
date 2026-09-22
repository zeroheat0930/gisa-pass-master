/// 가격 표기 (단일 정본).
///
/// 가격은 `AppConfig.premiumPrice` 에 있는데 화면에는 `'₩4,900'` 이 문자열로
/// 박혀 있었다. 상수를 고쳐도 화면은 그대로라 표기-실제 불일치가 나고,
/// 그게 결제 화면이면 환불·심사 분쟁이 된다. 금액을 보여주는 곳은 이 함수만 쓴다.
String formatPrice(int won) {
  final negative = won < 0;
  final digits = (negative ? -won : won).toString();

  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    // 뒤에서부터 3자리마다 쉼표. 맨 앞에는 붙이지 않는다.
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return negative ? '-₩$buf' : '₩$buf';
}
