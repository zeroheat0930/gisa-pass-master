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
        codeSnippet: question.codeSnippet,
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
    String? codeSnippet,
  }) {
    // 대소문자 변환 자체를 묻는 문항은 대소문자를 접으면 채점이 무의미해진다.
    // (입력 문자열을 그대로 옮겨 적어도 정답 처리됐다)
    final caseSensitive = _isCaseSensitive(questionText, codeSnippet);

    final normUser = _normalize(userAnswer, caseSensitive: caseSensitive);
    final normCorrect = _normalize(correctAnswer, caseSensitive: caseSensitive);

    // 1) 정규화 후 완전 일치
    if (normUser == normCorrect) return true;

    // 2) 공백만 제거해 비교 (상호배제 vs 상호 배제).
    //    쉼표는 남긴다. 쉼표까지 지우면 항목 경계가 사라져 "3,5"(두 줄 출력)와
    //    "35"(한 값)가 서로 정답 처리되는 오탐이 생긴다.
    if (_stripSpaces(normUser) == _stripSpaces(normCorrect)) return true;

    // 3) 괄호 안 대체표기 허용 — 용어 문항에 한정한다.
    //    정답이 "스택(Stack)" 일 때 "스택" 이나 "Stack" 만 써도 맞는 답이다.
    //    단, 실행 결과 문제의 괄호는 대체표기가 아니라 파이썬 튜플 같은 **출력 구문**이다.
    //    거기까지 허용하면 "Alice(30)" 에 "30" 만 써도, "[(0, 0), (0, 1)]" 에
    //    "0, 0" 만 써도 정답이 되어버린다.
    if (_allowsParenVariants(questionType, correctAnswer)) {
      for (final variant in _parenVariants(normCorrect)) {
        if (normUser == variant) return true;
        if (_stripSpaces(normUser) == _stripSpaces(variant)) return true;
      }
    }

    // 4) SQL 결과 행 비교 — ORDER BY 가 없으면 행 순서는 보장되지 않는다.
    //    행(개행) 단위 다중집합으로 본다. 쉼표로 쪼개면 한 행 안의 컬럼 순서까지
    //    무너져서 "개발, 6000" 과 "6000, 개발" 이 같아져버린다.
    if (questionType == 'sql' && !_hasOrderBy(codeSnippet)) {
      if (_sameMultiset(
        _rows(userAnswer, caseSensitive: caseSensitive),
        _rows(correctAnswer, caseSensitive: caseSensitive),
      )) {
        return true;
      }
    }

    // 5) 나열 순서 무관 비교 — 지문이 순서를 묻지 않을 때만 허용
    if (_allowsUnorderedList(questionType, questionText)) {
      if (_sameMultiset(_tokens(normUser), _tokens(normCorrect))) return true;
    }

    return false;
  }

  static bool _hasOrderBy(String? codeSnippet) =>
      (codeSnippet ?? '').toUpperCase().contains('ORDER BY');

  /// 답안을 '행' 단위로 쪼갠다. 행 안의 컬럼 순서는 그대로 보존한다.
  static List<String> _rows(String s, {bool caseSensitive = false}) {
    final t = s.trim().replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return t
        .split('\n')
        .map((r) => r.replaceAll(RegExp(r'\s+'), ' ').trim())
        .map((r) => caseSensitive ? r : r.toLowerCase())
        .where((r) => r.isNotEmpty)
        .toList();
  }

  /// 괄호 변형을 인정해도 되는 문항인지 판정한다.
  ///
  /// 용어 단답형에서 "스택(stack)" 처럼 **끝에 붙은 하나의 괄호**만 대체표기로 본다.
  /// 실행 결과·SQL 결과의 괄호는 출력 구문이므로 제외한다.
  static bool _allowsParenVariants(String? questionType, String correctAnswer) {
    if (questionType != 'short_answer') return false;

    final trimmed = correctAnswer.trim();
    // 괄호가 정확히 한 쌍이고, 그것이 답 끝에 붙어 있어야 한다.
    if ('('.allMatches(trimmed).length != 1) return false;
    if (!trimmed.endsWith(')')) return false;
    // "(전체가 괄호)" 형태는 대체표기가 아니다.
    if (trimmed.startsWith('(')) return false;
    return true;
  }

  /// 괄호가 있는 정답에서 인정 가능한 표기들을 만든다.
  /// "스택(stack)" -> ["스택", "stack"]
  static List<String> _parenVariants(String normalized) {
    if (!normalized.contains('(')) return const [];

    final withoutParens =
        normalized.replaceAll(RegExp(r'\([^)]*\)'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

    final inside = RegExp(r'\(([^)]*)\)')
        .allMatches(normalized)
        .map((m) => m.group(1)?.trim() ?? '')
        .where((v) => v.isNotEmpty)
        .toList();

    return [
      if (withoutParens.isNotEmpty) withoutParens,
      ...inside,
    ];
  }

  /// 줄바꿈을 쉼표로 바꿔 여러 줄 정답과 한 줄 나열 답안을 같은 형태로 만든다.
  /// (전체 1000문항 중 125문항은 정답이 여러 줄이다.)
  static String _normalize(String s, {bool caseSensitive = false}) {
    final t = s
        .trim()
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\n', ', ')
        .replaceAll(RegExp(r'\s+'), ' ');
    return caseSensitive ? t : t.toLowerCase();
  }

  /// 대소문자가 채점 대상인 문항인지 판정한다.
  ///
  /// 보통은 대소문자를 접어야 한다("Stack"과 "stack"은 같은 답이다).
  /// 하지만 대소문자 변환 결과를 묻는 문항에서 접어버리면, 유저가 입력 문자열을
  /// 그대로 옮겨 적어도 정답이 되어 문제가 성립하지 않는다.
  static bool _isCaseSensitive(String? questionText, String? codeSnippet) {
    final haystack = '${questionText ?? ''}\n${codeSnippet ?? ''}';
    if (haystack.isEmpty) return false;

    const markers = [
      '대문자',
      '소문자',
      'toUpperCase',
      'toLowerCase',
      'upper(',
      'lower(',
      'UPPER(',
      'LOWER(',
      'capitalize',
      'swapcase',
      'title()',
    ];
    for (final m in markers) {
      if (haystack.contains(m)) return true;
    }
    return false;
  }

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

    // "N가지를 쓰시오" 는 나열형의 가장 흔한 표현이다. 순서를 묻는 게 아니다.
    // (예: "동시성 문제 3가지", "SCM 주요 활동 4가지")
    // 반면 "각각 쓰시오"(HTTP와 HTTPS 포트를 각각)는 지문의 순서와 짝이 맞아야
    // 하므로 여기 포함하지 않는다.
    if (RegExp(r'\d+\s*가지').hasMatch(text)) return true;

    return false;
  }
}
