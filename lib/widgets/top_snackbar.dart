import 'package:flutter/material.dart';

/// Shows a SnackBar positioned at the **top** of the screen.
/// Use this instead of ScaffoldMessenger.of(context).showSnackBar(...)
/// whenever you want the notification to appear at the top.
void showTopSnackBar(
  BuildContext context, {
  required String message,
  Color backgroundColor = const Color(0xFFC62828),
  Color textColor = Colors.white,
  Duration duration = const Duration(seconds: 3),
  IconData? icon,
  double topOffset = 60,
}) {
  ScaffoldMessenger.of(context).clearSnackBars();
  final screenHeight = MediaQuery.of(context).size.height;
  // Push snackbar to the top by using a large bottom margin
  final bottomMargin = screenHeight - topOffset - MediaQuery.of(context).padding.top - 60;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: textColor, fontSize: 14),
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
        bottom: bottomMargin > 0 ? bottomMargin : 0,
        left: 16,
        right: 16,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 6,
    ),
  );
}
