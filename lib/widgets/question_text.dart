import 'package:flutter/material.dart';

/// 문제 본문을 그린다. 표로 보이는 줄은 **진짜 표 레이아웃**으로 따로 그린다.
///
/// 복원 기출은 원문의 표를 텍스트로 옮겨 담는다(앱에 이미지 표시 경로가 없다).
/// 본문 전체를 Text 하나로 그리면 두 가지가 동시에 깨진다.
///
///   1. 파이프로 맞춰둔 열이 어긋난다 — '프로세스'와 'P1' 의 폭이 다르기 때문이다.
///   2. 폭이 좁으면 표의 한 행이 중간에서 줄바꿈되어 어느 값이 어느 열인지 사라진다.
///
/// **고정폭 폰트로 해결하지 않는다.** 이 앱은 폰트를 번들하지 않아서
/// `fontFamily: 'monospace'` 는 Android 에서만 실제 고정폭으로 잡히고
/// iOS·macOS 에는 그런 이름의 폰트가 없어 비례폭으로 조용히 되돌아간다.
/// 즉 정작 매출이 나오는 iOS 에서는 아무 효과가 없다.
/// 대신 파이프로 셀을 갈라 Flutter `Table` 로 그린다. 열 정렬을 폰트가 아니라
/// 레이아웃이 보장하므로 어떤 플랫폼에서도 어긋나지 않는다.
class QuestionText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const QuestionText({super.key, required this.text, required this.style});

  /// 표의 한 행으로 볼 줄인가.
  ///
  /// 구분자가 **둘 이상**이어야 표로 본다. 파이프 하나짜리는 '가상회선 | 데이터그램'
  /// 처럼 평범한 나열일 수 있어서, 표로 바꾸면 오히려 어색해진다.
  static bool isTableRow(String line) => line.split('|').length >= 3;

  /// 한 줄을 셀로 가른다. 앞뒤 공백은 표 정렬용 패딩이라 버린다.
  static List<String> cellsOf(String line) =>
      line.split('|').map((c) => c.trim()).toList();

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');

    // 연속한 표 줄끼리 한 블록으로 묶는다. 블록 단위여야 열 폭이 함께 계산된다.
    final blocks = <({bool isTable, List<String> lines})>[];
    for (final line in lines) {
      final table = isTableRow(line);
      if (blocks.isNotEmpty && blocks.last.isTable == table) {
        blocks.last.lines.add(line);
      } else {
        blocks.add((isTable: table, lines: [line]));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks)
          if (block.isTable)
            _TableBlock(lines: block.lines, style: style)
          else
            Text(block.lines.join('\n'), style: style),
      ],
    );
  }
}

class _TableBlock extends StatelessWidget {
  final List<String> lines;
  final TextStyle style;

  const _TableBlock({required this.lines, required this.style});

  @override
  Widget build(BuildContext context) {
    final rows = lines.map(QuestionText.cellsOf).toList();
    // 행마다 셀 수가 다를 수 있다(원문이 그런 경우가 있다). Table 은 열 수가
    // 모두 같아야 하므로 가장 긴 행에 맞춰 빈 셀로 채운다.
    final columns = rows.fold(0, (m, r) => r.length > m ? r.length : m);

    final border = BorderSide(color: Colors.white.withValues(alpha: 0.12));
    final cellStyle = style.copyWith(height: 1.4);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        // 화면보다 좁은 표가 왼쪽에 쪼그라들지 않도록 최소 폭만 잡아둔다.
        constraints: const BoxConstraints(minWidth: 0),
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder(
            horizontalInside: border,
            verticalInside: border,
          ),
          children: [
            for (final row in rows)
              TableRow(
                children: [
                  for (var i = 0; i < columns; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: Text(
                        i < row.length ? row[i] : '',
                        style: cellStyle,
                        softWrap: false,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
