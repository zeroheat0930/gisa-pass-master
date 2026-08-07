/// 경과 시간 표기 (단일 정본).
///
/// 예전에는 화면마다 아래 계산이 복붙되어 있었다.
///
///   final mm = elapsed.inMinutes.remainder(60)...
///   final ss = elapsed.inSeconds.remainder(60)...
///   '$mm:$ss'
///
/// `remainder(60)` 은 '시' 단위를 통째로 버린다. 그래서 1시간 12분 경과가 `12:xx`,
/// 1시간 0분이 `00:xx` 로 표시됐다. 모의고사는 시간 제한이 없어 실제로 1시간을
/// 넘길 수 있으므로 결과 화면의 '소요 시간'이 거짓값이 됐다.
String formatElapsed(Duration elapsed) {
  final d = elapsed.isNegative ? Duration.zero : elapsed;
  final hours = d.inHours;
  final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}
