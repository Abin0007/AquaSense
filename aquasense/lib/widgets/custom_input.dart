import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomInput extends StatefulWidget {
  final String hintText;
  final IconData icon;
  final bool isPassword;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  // NEW: Animation for the glow effect
  final Animation<double> glowAnimation;

  const CustomInput({
    super.key,
    required this.hintText,
    required this.icon,
    this.isPassword = false,
    required this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    // NEW: Pass the animation controller
    required this.glowAnimation,
  });

  @override
  State<CustomInput> createState() => _CustomInputState();
}

class _CustomInputState extends State<CustomInput> {
  bool _obscureText = true;
  // NEW: FocusNode to detect when the text field is focused
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // NEW: Add a listener to the FocusNode to rebuild the widget on focus change
    _focusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // NEW: The AnimatedBuilder will handle the glow effect when focused
    return AnimatedBuilder(
      animation: widget.glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: _focusNode.hasFocus ? [
              BoxShadow(
                // FIX: Replaced deprecated withOpacity with a direct color definition.
                color: Color.fromRGBO(0, 255, 255, 0.3 + (widget.glowAnimation.value * 0.3)),
                blurRadius: 5 + (widget.glowAnimation.value * 5),
                spreadRadius: 1,
              )
            ] : [],
          ),
          child: child,
        );
      },
      child: TextFormField(
        focusNode: _focusNode, // NEW: Assign the FocusNode
        controller: widget.controller,
        obscureText: widget.isPassword ? _obscureText : false,
        validator: widget.validator,
        keyboardType: widget.keyboardType,
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'^\s*'))],
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(widget.icon, color: Colors.white70),
          hintText: widget.hintText,
          hintStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: const Color.fromRGBO(255, 255, 255, 0.2),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Color.fromRGBO(255, 255, 255, 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          ),
          suffixIcon: widget.isPassword
              ? IconButton(
            icon: Icon(
              _obscureText ? Icons.visibility_off : Icons.visibility,
              color: Colors.white70,
            ),
            onPressed: () => setState(() => _obscureText = !_obscureText),
          )
              : null,
        ),
      ),
    );
  }
}