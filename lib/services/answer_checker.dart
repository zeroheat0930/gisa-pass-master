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
    //    같은 이유로, 숫자가 공백으로 구분된 정답("30 50" — printf("%d %d") 류
    //    96문항)은 공백이 값의 경계라서 지우면 "3050"(한 값으로 오해한 오답)이
    //    정답 처리된다. 그때는 이 단계를 건너뛴다.
    if (_spaceCollapseSafe(normCorrect) &&
        _stripSpaces(normUser) == _stripSpaces(normCorrect)) {
      return true;
    }

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

    // 3b) 항목마다 설명 괄호가 붙은 나열형 정답 — "POST(Create), GET(Read)".
    //     여기서 괄호는 항목별 부연이지 답의 일부가 아니므로, 괄호를 생략해도
    //     정답으로 본다. 단 **유저가 괄호를 직접 썼다면 그 내용까지 맞아야 한다** —
    //     "POST(Read)" 처럼 대응 관계를 틀리게 쓴 답을 괄호만 벗겨 정답 처리하면
    //     출제 의도(대응 관계)가 사라진다.
    if (_allowsItemParenVariants(questionType, normCorrect)) {
      final us = _tokens(normUser);
      final cs = _tokens(normCorrect);
      if (_itemParenListMatches(us, cs)) return true;
      if (_allowsUnorderedList(questionType, questionText) &&
          _itemParenMultisetMatches(us, cs)) {
        return true;
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
  ///
  /// "delivery(또는 deployment)" 의 괄호는 전체 답의 대체표기가 아니라
  /// **바로 앞 단어의 대체어**다. 앞 단어를 치환한 문장을 변형으로 만들고,
  /// 괄호 안 문구 단독("또는 deployment")은 변형으로 인정하지 않는다.
  static List<String> _parenVariants(String normalized) {
    if (!normalized.contains('(')) return const [];

    final withoutParens =
        normalized.replaceAll(RegExp(r'\([^)]*\)'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

    final orSubstituted = normalized.replaceAllMapped(
        RegExp(r'(\S+)\s*\(\s*또는\s+([^)]+?)\s*\)'), (m) => m.group(2)!);

    // 괄호 안 문구 **단독** 답변은 한 단어짜리 동의어("스택(stack)")일 때만
    // 인정한다. "컨테이너 오케스트레이션(자동 배포, 확장, 관리)" 처럼 괄호가
    // 부연 설명이면, 핵심 용어 없이 설명만 쓴 답이 정답이 되어버린다.
    final inside = RegExp(r'\(([^)]*)\)')
        .allMatches(normalized)
        .map((m) => m.group(1)?.trim() ?? '')
        .where((v) =>
            v.isNotEmpty && !v.startsWith('또는') && !v.contains(' '))
        .toList();

    return [
      if (withoutParens.isNotEmpty) withoutParens,
      if (orSubstituted != normalized) orSubstituted,
      ...inside,
    ];
  }

  /// 항목별 설명 괄호를 인정해도 되는 정답인지 판정한다.
  ///
  /// 항목이 2개 이상 나열되고, 그중 하나 이상이 "이름(설명)" 꼴이어야 한다.
  /// 실행 결과 문제의 괄호는 출력 구문이므로 제외하고, "COUNT(*)" 처럼
  /// 괄호 안에 글자가 없는 것은 문법의 일부로 보고 벗기지 않는다.
  static bool _allowsItemParenVariants(String? questionType, String normCorrect) {
    if (questionType == 'code_reading') return false;

    final tokens = _tokens(normCorrect);
    if (tokens.length < 2) return false;

    final annotated = RegExp(r'^[^(].*\(([^)]*)\)$');
    return tokens.any((t) {
      final m = annotated.firstMatch(t);
      if (m == null) return false;
      return RegExp(r'[a-zA-Z가-힣]').hasMatch(m.group(1) ?? '');
    });
  }

  /// "이름(설명)" 항목에서 끝에 붙은 괄호 하나를 벗긴다. 벗길 게 없으면 그대로.
  static String _stripItemParen(String token) {
    final m = RegExp(r'^(.*?)\s*\([^)]*\)$').firstMatch(token);
    final stripped = m?.group(1)?.trim() ?? '';
    return stripped.isNotEmpty ? stripped : token;
  }

  /// 유저 항목 하나가 정답 항목 하나와 맞는지.
  /// 괄호를 생략했으면 이름만 비교하고, 괄호를 썼으면 통째로 맞아야 한다.
  static bool _itemParenTokenMatches(String user, String correct) {
    if (user.contains('(')) return user == correct;
    return user == _stripItemParen(correct);
  }

  static bool _itemParenListMatches(List<String> us, List<String> cs) {
    if (us.length != cs.length) return false;
    for (var i = 0; i < us.length; i++) {
      if (!_itemParenTokenMatches(us[i], cs[i])) return false;
    }
    return true;
  }

  /// 순서 무관 버전. 정답 항목을 하나씩 소모하며 짝을 찾는다 (중복 항목 보존).
  static bool _itemParenMultisetMatches(List<String> us, List<String> cs) {
    if (us.length != cs.length) return false;
    final remaining = [...cs];
    for (final u in us) {
      final i = remaining.indexWhere((c) => _itemParenTokenMatches(u, c));
      if (i < 0) return false;
      remaining.removeAt(i);
    }
    return true;
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
      // C 관용구: 'A'+32 == 'a'. 이 마커 없이 대소문자를 접으면
      // 입력 문자열을 그대로 옮겨 적어도 정답 처리된다.
      // 숫자 출력 문항이 오탐되어도 답에 알파벳이 없으니 무해하다.
      'toupper',
      'tolower',
      '+32',
      '+ 32',
      '-32',
      '- 32',
    ];
    for (final m in markers) {
      if (haystack.contains(m)) return true;
    }
    return false;
  }

  static String _stripSpaces(String s) => s.replaceAll(' ', '');

  /// 공백 제거 비교를 해도 되는 정답인지. 숫자가 공백으로 구분되어 있으면
  /// 그 공백은 띄어쓰기 허용이 아니라 **값의 경계**다.
  static bool _spaceCollapseSafe(String normCorrect) =>
      !RegExp(r'\d\s+\d').hasMatch(normCorrect);

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

    // "알고리즘 2개", "빅데이터의 3V" 도 같은 나열형이다. "가지" 만 보던 시절에는
    // 이 문항들에서 순서만 바꾼 정답이 오답 처리됐다 (실기 채점은 순서 무관).
    // "몇 개가 출력되는가" 류 개수 문항도 걸리지만, 그 답은 항목이 하나라
    // 다중집합 비교가 순서 비교와 동일해 무해하다.
    if (RegExp(r'\d+\s*개').hasMatch(text)) return true;
    if (RegExp(r'\d+\s*[vV]\b').hasMatch(text)) return true;

    return false;
  }
}
