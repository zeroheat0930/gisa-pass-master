import 'package:flutter/material.dart';

class CodeViewer extends StatelessWidget {
  final String code;
  final String language;

  const CodeViewer({
    super.key,
    required this.code,
    required this.language,
  });

  static const _bgColor = Color(0xFF1E1E1E);
  static const _defaultText = Color(0xFFD4D4D4);
  static const _keywordColor = Color(0xFF569CD6);
  static const _stringColor = Color(0xFFCE9178);
  static const _commentColor = Color(0xFF6A9955);
  static const _numberColor = Color(0xFFB5CEA8);

  static const _cKeywords = {
    'int', 'void', 'return', 'if', 'else', 'for', 'while', 'do',
    'char', 'float', 'double', 'long', 'short', 'unsigned', 'signed',
    'struct', 'typedef', 'enum', 'union', 'switch', 'case', 'break',
    'continue', 'default', 'const', 'static', 'extern', 'include',
    'define', 'sizeof', 'NULL', 'true', 'false',
  };

  static const _javaKeywords = {
    'int', 'void', 'return', 'if', 'else', 'for', 'while', 'do',
    'class', 'public', 'private', 'protected', 'static', 'final',
    'new', 'this', 'super', 'extends', 'implements', 'interface',
    'abstract', 'boolean', 'byte', 'char', 'short', 'long', 'float',
    'double', 'import', 'package', 'try', 'catch', 'finally', 'throw',
    'throws', 'instanceof', 'null', 'true', 'false', 'String', 'System',
    'override', 'switch', 'case', 'break', 'continue', 'default',
  };

  static const _pythonKeywords = {
    'def', 'class', 'return', 'if', 'elif', 'else', 'for', 'while',
    'in', 'not', 'and', 'or', 'is', 'import', 'from', 'as', 'with',
    'try', 'except', 'finally', 'raise', 'pass', 'break', 'continue',
    'lambda', 'yield', 'global', 'nonlocal', 'assert', 'del',
    'True', 'False', 'None', 'print', 'range', 'len', 'int', 'str',
    'list', 'dict', 'tuple', 'set', 'float', 'bool', 'type',
    'self', 'super', '__init__', '__str__', '__repr__',
    'map', 'filter', 'zip', 'enumerate', 'sorted', 'reversed',
    'input', 'open', 'append', 'extend', 'pop', 'remove',
  };

  static const _sqlKeywords = {
    'SELECT', 'FROM', 'WHERE', 'JOIN', 'LEFT', 'RIGHT', 'INNER', 'OUTER',
    'ON', 'GROUP', 'BY', 'ORDER', 'HAVING', 'INSERT', 'INTO', 'VALUES',
    'UPDATE', 'SET', 'DELETE', 'CREATE', 'TABLE', 'DROP', 'ALTER', 'ADD',
    'INDEX', 'PRIMARY', 'KEY', 'FOREIGN', 'REFERENCES', 'DISTINCT',
    'COUNT', 'SUM', 'AVG', 'MAX', 'MIN', 'AS', 'AND', 'OR', 'NOT',
    'IN', 'LIKE', 'BETWEEN', 'IS', 'NULL', 'UNION', 'ALL', 'LIMIT',
    'OFFSET', 'ASC', 'DESC', 'WITH', 'CASE', 'WHEN', 'THEN', 'ELSE', 'END',
    'GRANT', 'REVOKE', 'VIEW', 'REPLACE', 'EXISTS', 'TRIGGER',
    'VARCHAR', 'INTEGER', 'INT', 'TEXT', 'DATE', 'FLOAT', 'BOOLEAN',
    'DEFAULT', 'CHECK', 'UNIQUE', 'CASCADE', 'CONSTRAINT',
  };

  Set<String> get _keywords {
    switch (language.toLowerCase()) {
      case 'java':
        return _javaKeywords;
      case 'python':
        return _pythonKeywords;
      case 'sql':
        return _sqlKeywords;
      default:
        return _cKeywords;
    }
  }

  static final _digitRegex = RegExp(r'[0-9]');
  static final _digitDotRegex = RegExp(r'[0-9.]');
  static final _wordStartRegex = RegExp(r'[a-zA-Z_#@]');
  static final _wordRegex = RegExp(r'[a-zA-Z0-9_]');

  List<TextSpan> _tokenize(String source) {
    final spans = <TextSpan>[];
    final keywords = _keywords;
    final isSql = language.toLowerCase() == 'sql';
    final isPython = language.toLowerCase() == 'python';

    int i = 0;
    while (i < source.length) {
      final ch = source[i];

      // Python comment #
      if (isPython && ch == '#') {
        final end = source.indexOf('\n', i);
        final commentEnd = end == -1 ? source.length : end;
        spans.add(TextSpan(
          text: source.substring(i, commentEnd),
          style: const TextStyle(color: _commentColor),
        ));
        i = commentEnd;
        continue;
      }

      // Line comment //
      if (!isSql && !isPython && i + 1 < source.length && ch == '/' && source[i + 1] == '/') {
        final end = source.indexOf('\n', i);
        final commentEnd = end == -1 ? source.length : end;
        spans.add(TextSpan(
          text: source.substring(i, commentEnd),
          style: const TextStyle(color: _commentColor),
        ));
        i = commentEnd;
        continue;
      }

      // SQL comment --
      if (isSql && i + 1 < source.length && ch == '-' && source[i + 1] == '-') {
        final end = source.indexOf('\n', i);
        final commentEnd = end == -1 ? source.length : end;
        spans.add(TextSpan(
          text: source.substring(i, commentEnd),
          style: const TextStyle(color: _commentColor),
        ));
        i = commentEnd;
        continue;
      }

      // String literal " or '
      if (ch == '"' || ch == "'") {
        final quote = ch;
        int j = i + 1;
        while (j < source.length) {
          if (source[j] == quote) { j++; break; }
          if (source[j] == '\\' && j + 1 < source.length) j++;
          j++;
        }
        spans.add(TextSpan(
          text: source.substring(i, j),
          style: const TextStyle(color: _stringColor),
        ));
        i = j;
        continue;
      }

      // Number
      if (_digitRegex.hasMatch(ch)) {
        int j = i;
        while (j < source.length && _digitDotRegex.hasMatch(source[j])) {
          j++;
        }
        spans.add(TextSpan(
          text: source.substring(i, j),
          style: const TextStyle(color: _numberColor),
        ));
        i = j;
        continue;
      }

      // Word (keyword or identifier)
      if (_wordStartRegex.hasMatch(ch)) {
        int j = i;
        while (j < source.length && _wordRegex.hasMatch(source[j])) {
          j++;
        }
        final word = source.substring(i, j);
        final isKeyword = isSql
            ? keywords.contains(word.toUpperCase())
            : keywords.contains(word);
        spans.add(TextSpan(
          text: word,
          style: TextStyle(
            color: isKeyword ? _keywordColor : _defaultText,
          ),
        ));
        i = j;
        continue;
      }

      // Everything else
      spans.add(TextSpan(
        text: ch,
        style: const TextStyle(color: _defaultText),
      ));
      i++;
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final spans = _tokenize(code);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3C3C3C), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF3C3C3C),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  language.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF9CDCFE),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: RichText(
              softWrap: true,
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.5,
                  color: _defaultText,
                ),
                children: spans,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
