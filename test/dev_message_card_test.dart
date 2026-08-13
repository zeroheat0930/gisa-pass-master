import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gisa_pass_master/config.dart';
import 'package:gisa_pass_master/widgets/copy_email_row.dart';

/// 개발자 카드의 문의 메일 줄. 홈에서 리뷰와 문의를 받는 유일한 창구다.
void main() {
  testWidgets('메일 주소가 보인다', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: CopyEmailRow(email: AppConfig.contactEmail)),
    ));

    expect(find.text('zeroheat0930@gmail.com'), findsOneWidget);
    expect(find.textContaining('복사'), findsOneWidget,
        reason: '누르면 뭐가 되는지 알려줘야 한다');
  });

  testWidgets('탭하면 주소가 클립보드에 복사된다', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: CopyEmailRow(email: AppConfig.contactEmail)),
    ));

    await tester.tap(find.text('zeroheat0930@gmail.com'));
    await tester.pump();

    expect(copied, AppConfig.contactEmail);
  });

  testWidgets('바깥이 탭을 가진 카드 안에서도 메일 탭이 먼저 먹는다', (tester) async {
    // 실제 배치가 이렇다 — 개발자 카드 전체가 구독 화면으로 가는 탭이다.
    // 안쪽이 먼저 먹지 않으면 메일을 누르려다 결제 화면으로 끌려간다.
    var outerTapped = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GestureDetector(
          onTap: () => outerTapped++,
          child: const CopyEmailRow(email: AppConfig.contactEmail),
        ),
      ),
    ));

    await tester.tap(find.text('zeroheat0930@gmail.com'));
    await tester.pump();

    expect(outerTapped, 0, reason: '바깥(결제 화면) 탭이 같이 발동하면 안 된다');
  });

  test('연락처는 한 곳에서만 정의한다', () {
    // 주소가 여러 곳에 흩어지면 바꿀 때 한쪽만 고치게 된다.
    expect(AppConfig.contactEmail, 'zeroheat0930@gmail.com');
  });
}
