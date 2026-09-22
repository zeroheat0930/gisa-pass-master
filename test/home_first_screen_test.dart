import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gisa_pass_master/providers/stats_provider.dart';
import 'package:gisa_pass_master/screens/home_screen.dart';
import 'package:gisa_pass_master/services/database_service.dart';
import 'package:gisa_pass_master/services/purchase_service.dart';

/// 홈 첫 화면(스크롤 없이 보이는 범위)에 **유료 입구가 들어와 있는지**를 고정한다.
///
/// 재배치 전에는 AI 실전 모의고사가 위에서 6번째라 iPhone 기준 접힘선 밖이었다.
/// 순서를 되돌리면 이 파일의 "들어온 것" 단언이 깨진다.
///
/// 주의: `physicalSize` 만 고정하면 `devicePixelRatio` 가 기본값이라 논리 크기가
/// 엉뚱해진다. 둘을 **함께** 고정해야 의미 있는 통과가 된다.
void main() {
  // ─── 기종 상수 ────────────────────────────────────────────────────────────
  // SafeArea 값은 기종별 실측값이다. iPhone 17 Pro 의 상단 62 는 Dynamic Island
  // 기준이며, 흔히 쓰는 47 은 390×844 노치 기기(iPhone 12~13) 값이라 오답이다.
  const iphone17Pro = _Device(
    name: 'iPhone 17 Pro',
    width: 402,
    height: 874,
    safeTop: 62,
    safeBottom: 34,
  );
  const iphoneSe3 = _Device(
    name: 'iPhone SE 3rd',
    width: 375,
    height: 667,
    safeTop: 20,
    safeBottom: 0,
  );

  Future<void> pumpHome(
    WidgetTester tester, {
    required _Device device,
    required double textScale,
  }) async {
    tester.view.physicalSize =
        Size(device.width * 3, device.height * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // DdayTimer 의 1초 주기 Timer 는 dispose 에서만 멈춘다. 트리를 치워주지
    // 않으면 테스트 끝에 "A Timer is still pending" 으로 실패한다.
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

    // 통계 로드는 DB 를 타지만 StatsProvider.loadStats 가 실패를 삼키고
    // 기본값(StudyStats())으로 렌더한다. 배치 검증에는 그 상태로 충분하다.
    final db = DatabaseService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => StatsProvider(db: db)),
          ChangeNotifierProvider(create: (_) => PurchaseService()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              // MaterialApp 이 만든 MediaQuery 를 이어받아야 논리 크기가 유지된다.
              data: MediaQuery.of(context).copyWith(
                padding: EdgeInsets.only(
                  top: device.safeTop,
                  bottom: device.safeBottom,
                ),
                viewPadding: EdgeInsets.only(
                  top: device.safeTop,
                  bottom: device.safeBottom,
                ),
                textScaler: TextScaler.linear(textScale),
              ),
              child: HomeScreen(db: db),
            ),
          ),
        ),
      ),
    );

    // 등장 애니메이션(_staggerController, 900ms)이 끝나야 최종 좌표가 나온다.
    // 각 버튼의 shimmer 는 무한 반복이라 pumpAndSettle 은 쓸 수 없다.
    await tester.pump(const Duration(milliseconds: 1200));

    // _AiPredictionButton 제목 Row('AI 실전 모의고사' + AI 배지)가 Flexible 없이는
    // 좁은 화면·큰 배율에서 가로로 넘쳤다(SE 375·배율 1.0 에서 14px, 배율 1.3 에서
    // 74px). 첫 화면 유료 입구의 이름이 잘리는 자리라 오버플로 자체를 단언한다.
    expect(tester.takeException(), isNull,
        reason: '${device.name} · 배율 $textScale 에서 RenderFlex 오버플로가 나면 안 된다');
  }

  for (final device in [iphone17Pro, iphoneSe3]) {
    for (final scale in [1.0, 1.3]) {
      final label = '${device.name} · 배율 $scale';

      testWidgets('$label — AI 실전 모의고사가 첫 화면 안에 있다', (tester) async {
        await pumpHome(tester, device: device, textScale: scale);

        expect(find.text('AI 실전 모의고사'), findsOneWidget,
            reason: '유료 입구의 이름표가 바뀌면 이 테스트가 지키는 대상이 사라진다');

        final ai = _byName('_AiPredictionButton');
        expect(ai, findsOneWidget);
        expect(tester.getBottomLeft(ai).dy, lessThanOrEqualTo(device.fold),
            reason: '$label: 버튼 전체가 스크롤 없이 보여야 한다 (접힘선 ${device.fold})');
      });

      testWidgets('$label — 학습 플랜이 첫 화면 안에서 시작한다', (tester) async {
        await pumpHome(tester, device: device, textScale: scale);

        final plan = _byName('_StudyPlanButton');
        expect(plan, findsOneWidget);
        expect(tester.getTopLeft(plan).dy, lessThan(device.fold),
            reason: '$label: 진입 즉시 보여야 한다');

        // SE 3rd + 배율 1.3 은 화면이 667 밖에 안 되고 D-Day 카드가 커져서
        // 학습 플랜 버튼의 아랫단(실측 766)이 접힘선을 넘는다. 이 조합만
        // "윗부분이 보인다"까지로 본다.
        final fitsWhole = !(device.height == iphoneSe3.height && scale > 1.0);
        if (fitsWhole) {
          expect(tester.getBottomLeft(plan).dy,
              lessThanOrEqualTo(device.fold),
              reason: '$label: 버튼 전체가 접힘선 위에 있어야 한다');
        }
      });

      testWidgets('$label — 복원 기출·합격률은 접힘선 아래로 밀린다', (tester) async {
        await pumpHome(tester, device: device, textScale: scale);

        for (final name in ['_RestoredExamButton', '_PassRateButton']) {
          final target = _byName(name);
          expect(target, findsOneWidget);
          expect(tester.getTopLeft(target).dy, greaterThan(device.fold),
              reason: '$label: $name 은 스크롤 뒤에 오는 자리다(의도된 배치)');
        }
      });

      testWidgets('$label — 학습 모드 버튼 3개는 유료 입구 뒤로 간다', (tester) async {
        await pumpHome(tester, device: device, textScale: scale);

        final modes = _byName('_ModeButton');
        expect(modes, findsNWidgets(3));

        final aiBottom = tester.getBottomLeft(_byName('_AiPredictionButton')).dy;
        for (var i = 0; i < 3; i++) {
          expect(tester.getTopLeft(modes.at(i)).dy, greaterThan(aiBottom),
              reason: '$label: 모드 버튼 $i 가 AI 모의고사보다 위로 올라오면 재배치가 무너진 것');
        }

        // 첫 모드 버튼은 iPhone 17 Pro 기본 배율에서 접힘선 안쪽에 걸친다
        // (실측 아랫단 827 · 접힘선 840). 4개 조합 모두에서 참인 것은
        // "마지막 모드 버튼은 접힘선 밖"이므로 그것만 고정한다.
        expect(tester.getTopLeft(modes.at(2)).dy, greaterThan(device.fold),
            reason: '$label: 세 번째 모드 버튼까지 첫 화면에 들어오면 유료 입구가 밀려난다');
      });
    }
  }
}

/// private 위젯이라 `find.byType` 을 쓸 수 없다. 타입 이름으로 찾는다.
Finder _byName(String typeName) =>
    find.byWidgetPredicate((w) => w.runtimeType.toString() == typeName);

class _Device {
  final String name;
  final double width;
  final double height;
  final double safeTop;
  final double safeBottom;

  const _Device({
    required this.name,
    required this.width,
    required this.height,
    required this.safeTop,
    required this.safeBottom,
  });

  /// 스크롤 없이 보이는 세로 범위의 끝.
  double get fold => height - safeBottom;
}
