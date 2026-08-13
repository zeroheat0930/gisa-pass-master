import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';

/// 탭하면 오픈소스 라이선스·출처 고지 화면을 여는 줄.
///
/// **왜 필요한가.** 이 앱이 쓰는 pub 패키지들은 대부분 BSD·MIT·Apache 2.0 이고,
/// 셋 다 "배포물에 저작권 고지와 라이선스 사본을 포함하라" 를 조건으로 건다.
/// 앱에 그 화면이 없으면 조건을 안 지킨 것이 된다. `showLicensePage` 는 Flutter 가
/// 빌드 때 모아둔 패키지 라이선스를 그대로 보여주므로 이 한 줄이면 충족된다.
///
/// 문항 데이터의 출처(CC BY 4.0)는 패키지가 아니라 자동 수집 대상이 아니어서
/// `LicenseNotices.register()` 가 같은 목록에 따로 넣는다.
///
/// 이 줄은 홈의 개발자 카드 안에 있는데 **그 카드 전체가 구독 화면으로 가는
/// 탭이다.** 안쪽에서 탭을 먼저 받아 결제 화면으로 끌려가지 않게 한다
/// ([CopyEmailRow] 와 같은 이유).
class LicenseNoticeRow extends StatelessWidget {
  const LicenseNoticeRow({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        showLicensePage(
          context: context,
          applicationName: AppConfig.appTitle,
          applicationLegalese: '문항 출처와 오픈소스 라이선스를 아래에 밝힙니다.',
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(Icons.description_outlined, color: Colors.grey[500], size: 14),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '문항 출처 · 오픈소스 라이선스',
              style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
            ),
          ),
          Text(
            '보기',
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
        ],
      ),
    );
  }
}
