import 'package:flutter/material.dart';

enum AuthSocialBrand { facebook, google }

class AuthSocialButton extends StatelessWidget {
  const AuthSocialButton({
    super.key,
    required this.brand,
    this.onTap,
  });

  final AuthSocialBrand brand;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final button = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE5E9FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D1F2937),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Image.asset(
          _assetPath(brand),
          fit: BoxFit.contain,
        ),
      ),
    );

    if (onTap == null) {
      return button;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: button,
    );
  }
  String _assetPath(AuthSocialBrand brand) {
    switch (brand) {
      case AuthSocialBrand.facebook:
        return 'assets/social/facebook.png';
      case AuthSocialBrand.google:
        return 'assets/social/google.png';
    }
  }
}
