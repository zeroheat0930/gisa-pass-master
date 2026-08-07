import 'package:flutter/material.dart';
import '../config.dart';

/// 주관식 답안 입력창 (단일 정본).
///
/// 전체 1000문항 중 125문항은 정답이 여러 줄이다(예: C/Java 출력 결과 `3\n1`).
/// 예전에는 세 화면 모두 한 줄짜리 TextField 를 복붙해 쓰고 있어서, 유저가 줄을
/// 나누려고 엔터를 누르면 줄바꿈 대신 곧바로 제출돼 첫 줄만 채점됐다.
/// 그래서 정답의 줄 수에 따라 입력 방식을 바꾼다.
///
/// - 여러 줄 정답: 엔터 = 줄바꿈. 제출은 버튼으로만.
/// - 한 줄 정답:   엔터 = 제출. (기존 동작 유지)
class AnswerInputField extends StatelessWidget {
  final TextEditingController controller;

  /// 정답 원문. 줄바꿈 포함 여부로 입력 방식을 결정한다.
  final String correctAnswer;

  /// 한 줄 정답일 때 엔터로 호출된다.
  final VoidCallback onSubmit;

  const AnswerInputField({
    super.key,
    required this.controller,
    required this.correctAnswer,
    required this.onSubmit,
  });

  bool get _isMultiLine => correctAnswer.contains('\n');

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      minLines: 1,
      maxLines: _isMultiLine ? 5 : 1,
      keyboardType:
          _isMultiLine ? TextInputType.multiline : TextInputType.text,
      textInputAction:
          _isMultiLine ? TextInputAction.newline : TextInputAction.done,
      // 여러 줄 모드에서는 엔터가 줄바꿈이어야 하므로 제출 콜백을 걸지 않는다.
      onSubmitted: _isMultiLine ? null : (_) => onSubmit(),
      decoration: InputDecoration(
        hintText:
            _isMultiLine ? '정답 입력 (줄바꿈은 엔터)' : '정답을 입력하세요',
        hintStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: AppConfig.cardColor,
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
