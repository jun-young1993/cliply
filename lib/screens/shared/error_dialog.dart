import 'package:flutter/material.dart';

/// 내보내기 실패처럼 사용자 액션이 필요한 중요 오류에 사용.
/// 권한 거부 같은 경미한 오류는 SnackBar를 유지할 것.
Future<void> showErrorDialog(
  BuildContext context, {
  required String message,
  VoidCallback? onRetry,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('오류'),
      content: Text(message),
      actions: [
        if (onRetry != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onRetry();
            },
            child: const Text('다시 시도'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ],
    ),
  );
}
