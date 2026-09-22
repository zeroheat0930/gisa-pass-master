import 'dart:io';

/// grep 기반 배선 검증용: 라인 주석을 걷어낸 소스.
/// 원본을 그대로 grep 하면 주석에도 매칭되어, 호출을 주석 처리해 되돌려도 통과한다.
String activeSource(String path) {
  return File(path)
      .readAsStringSync()
      .split('\n')
      .map((line) {
        final i = line.indexOf('//');
        return i < 0 ? line : line.substring(0, i);
      })
      .join('\n');
}
