import 'package:flutter/foundation.dart';

/// 앱이 쓴 **패키지가 아닌** 저작물의 라이선스를 Flutter 라이선스 목록에 넣는다.
///
/// Flutter 는 pub 패키지의 LICENSE 파일을 빌드할 때 자동으로 모아 `showLicensePage`
/// 에 보여준다. 하지만 문항 데이터처럼 패키지가 아닌 자료는 그 수집 대상이 아니다.
/// 여기서 직접 등록해줘야 한 곳에서 다 보인다.
///
/// **왜 굳이 하나.** CC BY 4.0 은 저작자·라이선스 종류·라이선스 링크·변경 사실을
/// 요구한다(제3조 (a)(1)). 회차 목록 상단 고지가 이미 넷을 다 담고 있지만,
/// 그 화면까지 들어가야 보인다. 라이선스 목록은 앱이 쓴 남의 것을 한자리에
/// 모아두는 관례적인 자리라, 여기에도 두면 어디서 찾든 걸린다.
class LicenseNotices {
  LicenseNotices._();

  static const String sourceName = 'Life-Journey 블로그';
  static const String sourceUrl = 'https://chobopark.tistory.com';
  static const String licenseUrl =
      'https://creativecommons.org/licenses/by/4.0';

  static bool _registered = false;

  /// 테스트에서 `LicenseRegistry.reset()` 과 짝으로 부른다.
  /// 레지스트리를 비워도 이쪽 빗장은 그대로라 재등록이 막히기 때문이다.
  @visibleForTesting
  static void debugReset() => _registered = false;

  /// `main()` 에서 한 번 부른다. 두 번 불러도 중복 등록되지 않는다.
  static void register() {
    if (_registered) return;
    _registered = true;

    LicenseRegistry.addLicense(() async* {
      yield const LicenseEntryWithLineBreaks(
        <String>['복원 기출 문항 (Restored exam questions)'],
        '복원 기출 420문항의 출처는 $sourceName ($sourceUrl) 입니다.\n'
        '\n'
        'Creative Commons 저작자표시 4.0 국제 (CC BY 4.0) 에 따라 이용합니다.\n'
        '$licenseUrl\n'
        '\n'
        '변경 사항: 원문에 이미지로 실려 있던 문항과 표를 앱에서 읽고 채점할 수 '
        '있도록 텍스트 및 JSON 형식으로 옮겼습니다. 문항 본문과 해설의 내용은 '
        '바꾸지 않았습니다.\n'
        '\n'
        'The restored exam questions in this app come from $sourceName '
        '($sourceUrl), used under the Creative Commons Attribution 4.0 '
        'International License ($licenseUrl). Changes were made: questions and '
        'tables originally published as images were transcribed into text and '
        'JSON so the app can display and grade them. The wording of the '
        'questions and explanations was not altered.',
      );

      yield const LicenseEntryWithLineBreaks(
        <String>['AI 예상문제 (AI-generated questions)'],
        'AI 예상문제 1,000문항은 이 앱을 위해 생성한 것이며 기출 시험지가 '
        '아닙니다. 앱은 이 문항에 항상 "AI 예상" 라벨을 붙여 복원 기출과 '
        '구분합니다.',
      );

      yield const LicenseEntryWithLineBreaks(
        <String>['회차별 합격률 (Pass rate statistics)'],
        '필기·실기 회차별 응시자·합격자·합격률은 한국산업인력공단이 공표한 '
        '시험 통계입니다. 사실 정보이며 특정 저작물을 옮긴 것이 아닙니다.',
      );
    });
  }
}
