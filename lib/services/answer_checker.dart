import '../models/question.dart';

/// 주관식 답안 채점 로직 (단일 정본).
///
/// 이 파일이 생기기 전에는 같은 로직이 study_provider / ai_prediction_screen /
/// past_exam_screen / 테스트에 각각 복붙되어 있었고, 그 중 past_exam_screen(문제은행 탭)만
/// 단순 문자열 비교라서 정답을 오답으로 처리했다. 채점 규칙을 바꿀 일이 생기면
/// 반드시 이 파일만 고칠 것. 사본을 만들지 말 것.
class AnswerChecker {
  AnswerChecker._();

  /// 문제 객체로 채점한다. 화면·프로바이더는 되도록 이 진입점을 쓴다.
  static bool isCorrectFor(Question question, String userAnswer) => isCorrect(
        userAnswer,
        question.answer,
        questionType: question.questionType,
        questionText: question.questionText,
      );

  /// 줄바꿈·공백·대소문자 차이를 흡수해 정답 여부를 판정한다.
  ///
  /// **순서는 기본적으로 채점 대상이다.** 지문이 명시적으로 "모두 쓰시오" 류일 때만
  /// 나열 순서를 무시한다. 과거에는 순서를 항상 무시해서, 실행 결과 문제에서
  /// 출력 순서가 뒤바뀐 오답이 정답 처리됐다.
  static bool isCorrect(
    String userAnswer,
    String correctAnswer, {
    String? questionType,
    String? questionText,
  }) {
    final normUser = _normalize(userAnswer);
    final normCorrect = _normalize(correctAnswer);

    // 1) 정규화 후 완전 일치
    if (normUser == normCorrect) return true;

    // 2) 공백만 제거해 비교 (상호배제 vs 상호 배제).
    //    쉼표는 남긴다. 쉼표까지 지우면 항목 경계가 사라져 "3,5"(두 줄 출력)와
    //    "35"(한 값)가 서로 정답 처리되는 오탐이 생긴다.
    if (_stripSpaces(normUser) == _stripSpaces(normCorrect)) return true;

    // 3) 나열 순서 무관 비교 — 지문이 순서를 묻지 않을 때만 허용
    if (_allowsUnorderedList(questionType, questionText)) {
      if (_sameMultiset(_tokens(normUser), _tokens(normCorrect))) return true;
    }

    return false;
  }

  /// 줄바꿈을 쉼표로 바꿔 여러 줄 정답과 한 줄 나열 답안을 같은 형태로 만든다.
  /// (전체 1000문항 중 125문항은 정답이 여러 줄이다.)
  static String _normalize(String s) => s
      .trim()
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\n', ', ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase();

  static String _stripSpaces(String s) => s.replaceAll(' ', '');

  static List<String> _tokens(String s) =>
      s.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

  /// 다중집합 비교. Set 을 쓰면 중복 항목이 사라져
  /// 정답이 "a, a, b" 인데 "a, b" 만 적어도 통과해버린다.
  static bool _sameMultiset(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final x = [...a]..sort();
    final y = [...b]..sort();
    for (var i = 0; i < x.length; i++) {
      if (x[i] != y[i]) return false;
    }
    return true;
  }

  /// 순서를 무시해도 되는 문제인지 판정한다. 기본값은 "순서가 중요하다"(false).
  static bool _allowsUnorderedList(String? questionType, String? questionText) {
    // 실행 결과 문제는 출력되는 순서 자체가 정답이다.
    if (questionType == 'code_reading') return false;

    final text = questionText ?? '';
    if (text.isEmpty) return false;

    // "순서대로 쓰시오" 류는 순서가 곧 채점 기준이다.
    const orderedMarkers = ['순서대로', '순서에 맞게', '차례대로', '순서를', '순서와'];
    for (final m in orderedMarkers) {
      if (text.contains(m)) return false;
    }

    // 지문이 명시적으로 전부 나열하라고 요구할 때만 순서를 무시한다.
    const unorderedMarkers = ['모두 쓰시오', '모두 고르시오', '모두 나열', '나열하시오'];
    for (final m in unorderedMarkers) {
      if (text.contains(m)) return true;
    }

    return false;
  }
}
