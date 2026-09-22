import 'package:flutter_test/flutter_test.dart';

import 'package:gisa_pass_master/config.dart';
import 'package:gisa_pass_master/utils/price_format.dart';

// 가격 표기 정본. 결제 화면에 박혀 있던 '₩4,900' 을 대체한다.
// 쉼표 위치가 틀리면 유저가 보는 금액이 실제 결제액과 달라진다.
void main() {
  group('formatPrice', () {
    test('프리미엄 가격을 화면 표기 그대로 만든다', () {
      expect(formatPrice(4900), '₩4,900');
      expect(formatPrice(AppConfig.premiumPrice), '₩4,900');
    });

    test('0원과 세 자리 이하는 쉼표를 붙이지 않는다', () {
      expect(formatPrice(0), '₩0');
      expect(formatPrice(7), '₩7');
      expect(formatPrice(999), '₩999');
    });

    test('세 자리마다 쉼표를 넣는다', () {
      expect(formatPrice(1000), '₩1,000');
      expect(formatPrice(12345), '₩12,345');
      expect(formatPrice(1234567), '₩1,234,567');
    });

    test('음수는 부호를 앞에 둔다', () {
      // 환불 표기 같은 데 쓰이더라도 '₩-4,900' 처럼 기호 사이에 끼지 않게.
      expect(formatPrice(-4900), '-₩4,900');
    });
  });
}
