import 'package:flutter/material.dart';

class HelperFunctions {
  /// Show a simple snackbar for messages
  static void showSnackBar(BuildContext context, String message,
      {Color color = Colors.red}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show a success message
  static void showSuccess(BuildContext context, String message) {
    showSnackBar(context, message, color: Colors.green);
  }

  /// Show an error message
  static void showError(BuildContext context, String message) {
    showSnackBar(context, message, color: Colors.red);
  }
}