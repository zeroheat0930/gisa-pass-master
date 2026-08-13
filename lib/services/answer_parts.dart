/// 정답을 "번호가 붙은 여러 답"으로 나누는 단일 정본.
///
/// 복원 기출에는 한 문제가 답을 여러 개 요구하는 것이 많다
/// (예: `"1. 문장\n2. 분기\n3. 조건"`). 예전에는 이런 문항도 입력칸이 하나뿐이라,
/// 유저가 번호를 빼고 `"문장\n분기\n조건"` 이라고 쓰면 **전부 오답 처리**됐다.
/// 실측으로 그런 답안 97건이 97건 모두 틀린 것으로 나왔다.
///
/// 여기서 파싱한 결과를 입력 UI(칸 개수)와 채점(번호 무시)이 함께 쓴다.
/// **규칙을 바꿀 일이 생기면 이 파일만 고칠 것.** 사본을 만들지 말 것.
library;

class AnswerPart {
  /// 줄머리 번호. `1.` `(2)` `③` `ㄱ.` 같은 것. 번호가 없으면 빈 문자열.
  final String label;

  /// 번호를 뗀 실제 답.
  final String text;

  const AnswerPart({required this.label, required this.text});
}

class AnswerParts {
  AnswerParts._();

  /// 줄머리 번호 패턴.
  ///
  /// **숫자 뒤에 공백을 요구하는 것이 중요하다.** `\d+[.)]` 만 보면 `6.5ms` 나
  /// `106.00` 같은 정답의 앞부분을 번호로 오인해 답을 훼손한다.
  static final RegExp _marker =
      RegExp(r'^\s*(\(\d+\)|\d+[.)]|[①-⑳]|[ㄱ-ㅎ][.)])\s+');

  /// 정답을 파트로 나눈다.
  ///
  /// **모든 줄에 번호가 붙어 있고 두 줄 이상**일 때만 나눈다. 한 줄이라도 번호가
  /// 없으면 통째로 한 파트다 — `"3\n1"` 처럼 프로그램이 여러 줄 출력하는 정답을
  /// 칸 여러 개로 쪼개면 안 되기 때문이다. 그건 답이 여럿인 게 아니라 출력이
  /// 여러 줄인 것이다.
  static List<AnswerPart> split(String answer) {
    final lines =
        answer.split('\n').where((l) => l.trim().isNotEmpty).toList();

    if (lines.length >= 2 && lines.every((l) => _marker.hasMatch(l))) {
      return [
        for (final line in lines)
          AnswerPart(
            label: _marker.firstMatch(line)!.group(1)!,
            text: line.replaceFirst(_marker, '').trim(),
          ),
      ];
    }

    return [AnswerPart(label: '', text: answer.trim())];
  }

  /// 입력칸을 여러 개 보여줘야 하는 정답인가.
  static bool isMultiPart(String answer) => split(answer).length >= 2;

  /// 줄머리 번호를 뗀다 — 채점 정규화용.
  ///
  /// 유저가 번호를 쓰든 말든 같은 답으로 봐야 한다. 정답 쪽에서도 떼기 때문에
  /// `"1. 문장\n2. 분기"` 와 `"문장\n분기"` 가 같아진다.
  /// 줄 단위로 떼므로 `"6.5ms"` 처럼 번호가 아닌 것은 그대로 남는다.
  static String stripLabels(String s) =>
      s.split('\n').map((l) => l.replaceFirst(_marker, '')).join('\n');
}
