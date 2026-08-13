import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gisa_pass_master/services/license_notices.dart';
import 'package:gisa_pass_master/widgets/license_notice_row.dart';

/// 저작권 고지의 회귀 방지.
///
/// 이 앱이 쓰는 pub 패키지는 대부분 BSD·MIT·Apache 2.0 이고 셋 다 배포물에
/// 저작권 고지를 포함할 것을 조건으로 건다. 화면이 없으면 조건을 안 지킨 것이다.
/// 그리고 복원 기출은 CC BY 4.0 이라 저작자·라이선스 종류·**링크**·**변경 사실**
/// 넷을 밝혀야 한다(제3조 (a)(1)). 하나라도 빠지면 라이선스가 소멸한다(제6조 (a)).
void main() {
  group('문항 출처가 라이선스 목록에 등록된다', () {
    setUp(() {
      LicenseRegistry.reset();
      LicenseNotices.debugReset();
      LicenseNotices.register();
    });

    tearDown(() {
      LicenseRegistry.reset();
      LicenseNotices.debugReset();
    });

    Future<List<LicenseEntry>> collect() =>
        LicenseRegistry.licenses.toList();

    test('복원 기출 항목이 CC BY 4.0 의 네 가지를 모두 담는다', () async {
      final entries = await collect();
      final restored = entries.firstWhere(
        (e) => e.packages.any((p) => p.contains('복원 기출')),
        orElse: () => throw StateError('복원 기출 라이선스 항목이 없다'),
      );
      final text = restored.paragraphs.map((p) => p.text).join('\n');

      expect(text, contains('Life-Journey'), reason: '1. 저작자');
      expect(text, contains('CC BY 4.0'), reason: '2. 라이선스 종류');
      expect(text, contains('creativecommons.org/licenses/by/4.0'),
          reason: '3. 라이선스 링크(URI)');
      expect(text, contains('변경 사항'), reason: '4. 변경 사실 공지');
      expect(text, contains('chobopark.tistory.com'),
          reason: '원문에 도달할 수 있어야 한다');
    });

    test('변경 내용이 무엇이었는지 구체적으로 적는다', () async {
      final entries = await collect();
      final text = entries
          .where((e) => e.packages.any((p) => p.contains('복원 기출')))
          .expand((e) => e.paragraphs)
          .map((p) => p.text)
          .join('\n');

      // "수정했다" 만 적으면 무엇을 어떻게 바꿨는지 알 수 없다.
      expect(text, contains('이미지'));
      expect(text, contains('텍스트'));
    });

    test('영문 고지도 함께 넣는다', () async {
      // 앱스토어 심사와 해외 이용자를 위해서다.
      final entries = await collect();
      final text = entries
          .where((e) => e.packages.any((p) => p.contains('복원 기출')))
          .expand((e) => e.paragraphs)
          .map((p) => p.text)
          .join('\n');

      expect(text, contains('Creative Commons Attribution 4.0'));
      expect(text, contains('Changes were made'));
    });

    test('AI 예상문제가 기출이 아님을 여기서도 밝힌다', () async {
      final entries = await collect();
      final ai = entries.where((e) => e.packages.any((p) => p.contains('AI')));
      expect(ai, isNotEmpty, reason: 'AI 문항 고지가 없다');
      expect(ai.expand((e) => e.paragraphs).map((p) => p.text).join(),
          contains('기출 시험지가 아닙니다'));
    });

    test('두 번 등록해도 항목이 중복되지 않는다', () async {
      LicenseNotices.register();
      LicenseNotices.register();

      final entries = await collect();
      final restoredCount = entries
          .where((e) => e.packages.any((p) => p.contains('복원 기출')))
          .length;
      expect(restoredCount, 1, reason: '같은 고지가 여러 번 뜨면 안 된다');
    });
  });

  group('라이선스 화면으로 가는 입구', () {
    testWidgets('개발자 카드에서 누를 수 있는 줄이 보인다', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: LicenseNoticeRow()),
      ));

      expect(find.textContaining('오픈소스 라이선스'), findsOneWidget);
      expect(find.textContaining('출처'), findsOneWidget);
    });

    testWidgets('탭하면 라이선스 화면이 열린다', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: LicenseNoticeRow()),
      ));

      await tester.tap(find.textContaining('오픈소스 라이선스'));
      await tester.pumpAndSettle();

      expect(find.byType(LicensePage), findsOneWidget,
          reason: '고지 화면이 안 열리면 줄만 있고 알맹이가 없는 셈이다');
    });

    testWidgets('바깥이 탭을 가진 카드 안에서도 이 줄이 먼저 먹는다', (tester) async {
      // 실제 배치가 이렇다 — 개발자 카드 전체가 구독 화면으로 가는 탭이다.
      var outerTapped = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GestureDetector(
            onTap: () => outerTapped++,
            child: const LicenseNoticeRow(),
          ),
        ),
      ));

      await tester.tap(find.textContaining('오픈소스 라이선스'));
      await tester.pumpAndSettle();

      expect(outerTapped, 0, reason: '바깥(결제 화면) 탭이 같이 발동하면 안 된다');
    });
  });
}
