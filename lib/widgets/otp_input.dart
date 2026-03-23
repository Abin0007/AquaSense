import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OtpInput extends StatelessWidget {
  final TextEditingController controller;
  final bool autoFocus;
  final double width;
  final double height;

  const OtpInput({
    super.key,
    required this.controller,
    required this.autoFocus,
    this.width = 40,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: TextFormField(
        autofocus: autoFocus,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        showCursor: true,
        keyboardType: TextInputType.number,
        keyboardAppearance: Brightness.light,
        controller: controller,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        enableSuggestions: false,
        autocorrect: false,
        cursorColor: Colors.black87,
        style: const TextStyle(
          fontSize: 22,
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          counterText: '',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFB0BEC5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFB0BEC5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black87, width: 2),
          ),
        ),
        onChanged: (value) {
          if (value.length == 1) {
            FocusScope.of(context).nextFocus();
          } else if (value.isEmpty) {
            FocusScope.of(context).previousFocus();
          }
        },
      ),
    );
  }
}
