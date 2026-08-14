import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// iOS 프라이버시 매니페스트 검사.
///
/// **왜 테스트로 두는가.** 이 파일이 잘못되면 앱은 멀쩡히 빌드되고 시뮬레이터에서도
/// 잘 돌아간다. 문제는 App Store 에 올린 **뒤에야** 드러난다 — 업로드하고,
/// 처리되기를 기다리고, 심사에 제출하고 나서 "잘못된 바이너리" 메일을 받는다.
/// 한 번 왕복에 반나절이 날아간다.
///
/// 실제로 v1.8.2 빌드 37 이 이 이유로 반려됐다:
///   ITMS-91064 잘못된 추적 정보 — NSPrivacyTrackingDomains 가 빈 배열이었다.
///
/// 그래서 애플이 검사하는 규칙을 여기로 가져왔다. 몇 초 만에 잡힌다.
void main() {
  final file = File('ios/Runner/PrivacyInfo.xcprivacy');
  late String xml;

  setUpAll(() {
    expect(file.existsSync(), isTrue,
        reason: '프라이버시 매니페스트가 없으면 애플이 업로드를 거부한다');
    xml = file.readAsStringSync();
  });

  test('NSPrivacyTrackingDomains 를 빈 배열로 두지 않는다', () {
    // ITMS-91064 의 원인. 키를 쓸 거면 값이 있어야 하고, 없으면 키를 빼야 한다.
    final emptyArray = RegExp(
      r'<key>\s*NSPrivacyTrackingDomains\s*</key>\s*<array\s*/>',
      multiLine: true,
    );
    expect(emptyArray.hasMatch(xml), isFalse,
        reason: 'NSPrivacyTrackingDomains 가 빈 배열이다 — 애플이 반려한다. '
            '적을 도메인이 없으면 키 자체를 빼라.');

    final emptyPair = RegExp(
      r'<key>\s*NSPrivacyTrackingDomains\s*</key>\s*<array>\s*</array>',
      multiLine: true,
    );
    expect(emptyPair.hasMatch(xml), isFalse,
        reason: '여닫는 태그만 있는 빈 배열도 같은 이유로 반려된다');
  });

  test('추적한다고 선언한다', () {
    // ATT 프롬프트를 띄우고 IDFA 로 맞춤형 광고를 하므로 추적이 맞다.
    // false 로 바꾸면 개인정보 라벨과 어긋나 심사에서 걸린다.
    final tracking = RegExp(
      r'<key>\s*NSPrivacyTracking\s*</key>\s*<true\s*/>',
      multiLine: true,
    );
    expect(tracking.hasMatch(xml), isTrue,
        reason: 'ATT 프롬프트를 띄우면서 추적 안 한다고 선언하면 안 된다');
  });

  test('광고 도메인을 추적 도메인으로 적지 않는다', () {
    // 여기 적힌 도메인은 ATT 를 거부한 사용자에게 iOS 가 **연결을 차단한다.**
    // AdMob 은 맞춤형/비맞춤형을 같은 도메인으로 서빙하므로, 적는 순간
    // 거부한 사용자에게 광고가 아예 안 나가고 그만큼 수익이 사라진다.
    for (final domain in const [
      'googlesyndication.com',
      'doubleclick.net',
      'googleadservices.com',
      'google-analytics.com',
      'app-measurement.com',
    ]) {
      expect(xml.contains(domain), isFalse,
          reason: '$domain 을 추적 도메인으로 적으면 ATT 거부 사용자에게 '
              '광고가 차단된다');
    }
  });

  test('수집 항목과 접근 API 선언이 남아 있다', () {
    // 지워지면 개인정보 라벨과 어긋나 심사에서 걸린다.
    expect(xml, contains('NSPrivacyCollectedDataTypeDeviceID'));
    expect(xml, contains('NSPrivacyAccessedAPICategoryUserDefaults'));
  });

  test('plist 로서 유효하다', () {
    // 태그가 깨지면 애플이 파일 자체를 못 읽는다.
    final result = Process.runSync('plutil', ['-lint', file.path]);
    expect(result.exitCode, 0,
        reason: 'plutil -lint 실패: ${result.stdout}${result.stderr}');
  });
}
