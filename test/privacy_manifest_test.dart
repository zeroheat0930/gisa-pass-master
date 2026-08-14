import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// iOS 프라이버시 매니페스트 검사.
///
/// **왜 테스트로 두는가.** 이 파일이 잘못되면 앱은 멀쩡히 빌드되고 시뮬레이터에서도,
/// TestFlight 에서도 잘 돌아간다. 문제는 심사에 제출한 **뒤에야** 드러난다 —
/// 업로드하고, 처리를 기다리고, 제출하고 나서 '잘못된 바이너리' 메일을 받는다.
/// 한 번 왕복에 반나절이 날아간다. 실제로 두 번 날렸다.
///
///   빌드 37  tracking=true, domains=<array/>   → ITMS-91064 반려
///   빌드 38  tracking=true, domains 키 없음     → ITMS-91064 반려
///
/// ── 애플의 규칙 (한 줄) ──
///
///   NSPrivacyTracking 이 true 면 NSPrivacyTrackingDomains 에 도메인이
///   **최소 하나** 있어야 한다. false 면 0개여도 된다.
///
/// 빌드 38 때 "도메인이 없으면 키를 빼면 된다" 고 판단했는데 틀렸다. 키를 빼도
/// true 인 이상 도메인이 0개인 것은 마찬가지다. 그래서 이 테스트는 **키의 유무가
/// 아니라 규칙 자체**를 검사한다.
void main() {
  final file = File('ios/Runner/PrivacyInfo.xcprivacy');
  late String xml;

  setUpAll(() {
    expect(file.existsSync(), isTrue,
        reason: '프라이버시 매니페스트가 없으면 애플이 업로드를 거부한다');
    xml = file.readAsStringSync();
  });

  /// `<key>NAME</key>` 바로 뒤에 오는 값을 문자열로 돌려준다.
  String? valueAfter(String key) {
    final m = RegExp('<key>\\s*$key\\s*</key>\\s*(.*?)(?=<key>|</dict>)',
            dotAll: true)
        .firstMatch(xml);
    return m?.group(1);
  }

  bool tracking() =>
      valueAfter('NSPrivacyTracking')?.contains('<true/>') ?? false;

  /// 추적 도메인 개수. 키가 없으면 0.
  int domainCount() {
    final v = valueAfter('NSPrivacyTrackingDomains');
    if (v == null) return 0;
    return RegExp(r'<string>\s*\S+\s*</string>').allMatches(v).length;
  }

  group('ITMS-91064 을 부르는 조합을 막는다', () {
    test('tracking 이 true 라면 도메인이 최소 하나 있어야 한다', () {
      if (!tracking()) return; // false 면 0개여도 된다
      expect(domainCount(), greaterThan(0),
          reason: 'NSPrivacyTracking 이 true 인데 추적 도메인이 0개다. '
              '애플이 ITMS-91064 로 반려한다. 도메인을 적거나 tracking 을 false 로 하라. '
              '단, 광고 도메인을 적으면 ATT 거부 사용자에게 광고가 차단된다.');
    });

    test('도메인이 있다면 tracking 이 true 여야 한다', () {
      if (domainCount() == 0) return;
      expect(tracking(), isTrue,
          reason: '추적 도메인을 적어놓고 tracking 을 false 로 두면 반려된다');
    });
  });

  group('수익을 지키는 선택을 유지한다', () {
    test('광고 도메인을 추적 도메인으로 적지 않는다', () {
      // 여기 적은 도메인은 ATT 거부 사용자에게 iOS 가 **연결을 차단한다.**
      // AdMob 은 맞춤형·비맞춤형을 같은 도메인으로 서빙하므로, 적는 순간
      // 거부한 사용자에게 광고가 아예 안 나가고 그만큼 수익이 사라진다.
      for (final domain in const [
        'googlesyndication.com',
        'doubleclick.net',
        'googleadservices.com',
        'google-analytics.com',
        'app-measurement.com',
        'googletagmanager.com',
      ]) {
        expect(xml.contains(domain), isFalse,
            reason: '$domain 을 추적 도메인으로 적으면 ATT 거부 사용자에게 '
                '광고가 차단된다 — 수익 직결');
      }
    });

    test('매니페스트가 자기모순이 아니다', () {
      // 한쪽은 추적 안 한다 하고 다른 쪽 수집 항목은 추적한다 하면 어긋난다.
      final collectedTracksSomething =
          RegExp(r'<key>\s*NSPrivacyCollectedDataTypeTracking\s*</key>\s*<true/>')
              .hasMatch(xml);
      expect(collectedTracksSomething, equals(tracking()),
          reason: 'NSPrivacyTracking 과 수집 항목의 Tracking 플래그가 어긋난다');
    });
  });

  group('지워지면 안 되는 것', () {
    test('수집 항목 선언이 남아 있다', () {
      // 개인정보 라벨과 어긋나면 심사에서 걸린다. 추적 여부와 별개로
      // 무엇을 수집하는지는 사실대로 남겨야 한다.
      expect(xml, contains('NSPrivacyCollectedDataTypeDeviceID'));
      expect(xml, contains('NSPrivacyCollectedDataTypeAdvertisingData'));
      expect(xml, contains('NSPrivacyCollectedDataTypePurchaseHistory'));
    });

    test('접근 API 사유 선언이 남아 있다', () {
      expect(xml, contains('NSPrivacyAccessedAPICategoryUserDefaults'));
      expect(xml, contains('CA92.1'));
    });

    test('plist 로서 유효하다', () {
      final r = Process.runSync('plutil', ['-lint', file.path]);
      expect(r.exitCode, 0, reason: 'plutil -lint 실패: ${r.stdout}${r.stderr}');
    });
  });
}
