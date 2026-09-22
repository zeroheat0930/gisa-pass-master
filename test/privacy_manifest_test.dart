import 'dart:convert';
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

  // ── iOS 플러그인 의존성 ────────────────────────────────────────────────────
  //
  // 반려는 우리 매니페스트뿐 아니라 **동봉되는 플러그인 매니페스트**로도 난다.
  // 애플은 앱 번들 안의 모든 매니페스트를 본다. 의존성을 추가할 때마다
  // 여기에 한 줄 추가하고, 없으면 업로드 전에 알아야 한다(반려 1회 = 반나절).
  group('iOS 플러그인 의존성의 매니페스트', () {
    /// pub 이 해석한 패키지 경로. `flutter pub get` 을 돌린 적이 없으면 null.
    Directory? packageRoot(String name) {
      final config = File('.dart_tool/package_config.json');
      if (!config.existsSync()) return null;
      final packages = (jsonDecode(config.readAsStringSync())
          as Map<String, dynamic>)['packages'] as List<dynamic>;
      for (final p in packages.cast<Map<String, dynamic>>()) {
        if (p['name'] != name) continue;
        return Directory.fromUri(config.uri.resolve(p['rootUri'] as String));
      }
      return null;
    }

    List<File> manifestsIn(Directory root) {
      final ios = Directory('${root.path}/ios');
      if (!ios.existsSync()) return const [];
      return ios
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('PrivacyInfo.xcprivacy'))
          .toList();
    }

    // +41 에서 새로 들어온 것들. in_app_review 가 url_launcher 를 끌고 온다.
    for (final name in const ['in_app_review', 'url_launcher_ios']) {
      test('$name 이 프라이버시 매니페스트를 동봉한다', () {
        final root = packageRoot(name);
        expect(root, isNotNull,
            reason: '$name 을 해석하지 못했다. flutter pub get 을 먼저 돌릴 것');
        final manifests = manifestsIn(root!);
        expect(manifests, isNotEmpty,
            reason: '$name 이 PrivacyInfo.xcprivacy 없이 번들에 들어가면 '
                'ITMS-91064 로 반려된다(빌드 37·38 의 재발)');

        for (final manifest in manifests) {
          final body = manifest.readAsStringSync();
          final tracks = RegExp(r'<key>\s*NSPrivacyTracking\s*</key>\s*<true/>')
              .hasMatch(body);
          if (!tracks) continue;
          final domains = RegExp(
                  '<key>\\s*NSPrivacyTrackingDomains\\s*</key>\\s*(.*?)(?=<key>|</dict>)',
                  dotAll: true)
              .firstMatch(body)
              ?.group(1);
          final count = domains == null
              ? 0
              : RegExp(r'<string>\s*\S+\s*</string>').allMatches(domains).length;
          expect(count, greaterThan(0),
              reason: '${manifest.path} 가 tracking=true 인데 도메인이 0개다 '
                  '— 우리 앱이 그대로 반려된다');
        }
      });
    }
  });
}
