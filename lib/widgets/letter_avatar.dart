import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LetterAvatar extends StatelessWidget {
  final String name;
  final String seed;
  final double size;

  const LetterAvatar({
    super.key,
    required this.name,
    required this.seed,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final initials = AppTheme.initials(name);
    final color = AppTheme.avatarColor(seed.isNotEmpty ? seed : name);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}
