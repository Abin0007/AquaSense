import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SocialLoginButton extends StatelessWidget {
  final String assetName;
  final VoidCallback onPressed;

  const SocialLoginButton({
    super.key,
    required this.assetName,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color.fromRGBO(255, 255, 255, 0.2), // <-- FIX: Replaced withOpacity
          border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.3)), // <-- FIX: Replaced withOpacity
        ),
        child: SvgPicture.asset(
          assetName,
          height: 30,
          width: 30,
        ),
      ),
    );
  }
}