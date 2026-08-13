import 'package:flutter/material.dart';
import '../config.dart';
import '../services/answer_parts.dart';

/// 주관식 답안 입력창 (단일 정본).
///
/// 전체 1000문항 중 125문항은 정답이 여러 줄이다(예: C/Java 출력 결과 `3\n1`).
/// 예전에는 세 화면 모두 한 줄짜리 TextField 를 복붙해 쓰고 있어서, 유저가 줄을
/// 나누려고 엔터를 누르면 줄바꿈 대신 곧바로 제출돼 첫 줄만 채점됐다.
///
/// 여기에 더해, 복원 기출에는 **답을 여러 개 요구하는 문항이 94개** 있다
/// (예: `"1. 문장\n2. 분기\n3. 조건"`). 칸이 하나뿐이면 유저는 세 답을 어떻게
/// 구분해 넣어야 하는지 알 수 없다. 그래서 번호가 붙은 정답은 **번호 라벨이
/// 달린 칸을 번호 수만큼** 만든다.
///
/// - 번호가 붙은 여러 답: 칸 N개. 각 칸에 라벨(`1.` `ㄱ.`)을 붙인다.
/// - 그냥 여러 줄 정답:   칸 1개, 엔터 = 줄바꿈. 제출은 버튼으로만.
/// - 한 줄 정답:         칸 1개, 엔터 = 제출. (기존 동작 유지)
///
/// **바깥 계약은 그대로다.** 화면은 여전히 컨트롤러 하나만 넘기고 `.text` 로
/// 답을 읽는다. 칸이 여러 개일 때는 이 위젯이 값을 줄바꿈으로 이어 그 컨트롤러에
/// 써 넣는다. 덕분에 이 위젯을 쓰는 세 화면을 건드릴 필요가 없다.
class AnswerInputField extends StatefulWidget {
  final TextEditingController controller;

  /// 정답 원문. 칸을 몇 개 만들지 여기서 결정한다.
  final String correctAnswer;

  /// 마지막 칸에서 엔터를 눌렀을 때 호출된다(여러 줄 정답은 제외).
  final VoidCallback onSubmit;

  const AnswerInputField({
    super.key,
    required this.controller,
    required this.correctAnswer,
    required this.onSubmit,
  });

  @override
  State<AnswerInputField> createState() => _AnswerInputFieldState();
}

class _AnswerInputFieldState extends State<AnswerInputField> {
  List<AnswerPart> _parts = const [];
  List<TextEditingController> _subs = const [];

  /// 서로에게 되먹임되는 것을 막는 빗장.
  /// 칸 -> 본 컨트롤러로 쓸 때 본 컨트롤러의 리스너가 다시 칸을 지우면 안 된다.
  bool _syncing = false;

  bool get _isSplit => _parts.length >= 2;
  bool get _isMultiLine => widget.correctAnswer.contains('\n');

  @override
  void initState() {
    super.initState();
    _rebuildParts();
    widget.controller.addListener(_onOuterChanged);
  }

  @override
  void didUpdateWidget(AnswerInputField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onOuterChanged);
      widget.controller.addListener(_onOuterChanged);
    }
    // 다음 문제로 넘어가면 정답이 바뀌므로 칸 구성을 다시 잡는다.
    if (old.correctAnswer != widget.correctAnswer) {
      _rebuildParts();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onOuterChanged);
    for (final c in _subs) {
      c.dispose();
    }
    super.dispose();
  }

  void _rebuildParts() {
    for (final c in _subs) {
      c.dispose();
    }
    _parts = AnswerParts.split(widget.correctAnswer);
    _subs = _parts.length >= 2
        ? List.generate(_parts.length, (_) => TextEditingController())
        : const [];
    for (final c in _subs) {
      c.addListener(_onInnerChanged);
    }
  }

  /// 칸에 입력이 생기면 줄바꿈으로 이어 본 컨트롤러에 써 넣는다.
  void _onInnerChanged() {
    if (!_isSplit || _syncing) return;
    _syncing = true;
    widget.controller.text = _subs.map((c) => c.text.trim()).join('\n');
    _syncing = false;
  }

  /// 화면이 다음 문제로 넘어가며 컨트롤러를 비우면 칸도 함께 비운다.
  /// 이걸 안 하면 앞 문제의 답이 다음 문제 칸에 남는다.
  void _onOuterChanged() {
    if (!_isSplit || _syncing) return;
    if (widget.controller.text.isNotEmpty) return;
    if (_subs.every((c) => c.text.isEmpty)) return;
    _syncing = true;
    for (final c in _subs) {
      c.clear();
    }
    _syncing = false;
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: AppConfig.cardColor,
        isDense: _isSplit,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppConfig.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppConfig.primaryColor, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppConfig.borderColor),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: _isSplit ? 12 : 14,
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_isSplit) return _buildSplit();
    return _buildSingle();
  }

  Widget _buildSingle() {
    return TextField(
      controller: widget.controller,
      style: const TextStyle(color: Colors.white),
      minLines: 1,
      maxLines: _isMultiLine ? 5 : 1,
      keyboardType:
          _isMultiLine ? TextInputType.multiline : TextInputType.text,
      textInputAction:
          _isMultiLine ? TextInputAction.newline : TextInputAction.done,
      // 여러 줄 모드에서는 엔터가 줄바꿈이어야 하므로 제출 콜백을 걸지 않는다.
      onSubmitted: _isMultiLine ? null : (_) => widget.onSubmit(),
      decoration: _decoration(
          _isMultiLine ? '정답 입력 (줄바꿈은 엔터)' : '정답을 입력하세요'),
    );
  }

  Widget _buildSplit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '답이 ${_parts.length}개입니다',
          style: const TextStyle(color: Color(0xFF8A8A8A), fontSize: 12),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _parts.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  _parts[i].label,
                  style: const TextStyle(
                    color: Color(0xFFBDBDBD),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _subs[i],
                  style: const TextStyle(color: Colors.white),
                  textInputAction: i == _parts.length - 1
                      ? TextInputAction.done
                      : TextInputAction.next,
                  onSubmitted: i == _parts.length - 1
                      ? (_) => widget.onSubmit()
                      : null,
                  decoration: _decoration('${i + 1}번째 답'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
