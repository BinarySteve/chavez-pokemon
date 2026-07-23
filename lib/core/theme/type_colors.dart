import 'package:flutter/material.dart';

Color typeColor(String type) {
  return switch (type.toLowerCase()) {
    'grass' => const Color(0xFF4F8F5B),
    'poison' => const Color(0xFF8A5A9B),
    'fire' => const Color(0xFFD7673F),
    'flying' => const Color(0xFF6B91AE),
    'electric' => const Color(0xFFD79E1C),
    'normal' => const Color(0xFF81796F),
    'water' => const Color(0xFF4F7FB8),
    'psychic' => const Color(0xFFB85B78),
    'dark' => const Color(0xFF544D59),
    'fairy' => const Color(0xFFB9689B),
    'dragon' => const Color(0xFF6B5BA8),
    'ice' => const Color(0xFF4E929C),
    'fighting' => const Color(0xFFA34E42),
    'ground' => const Color(0xFFA9783F),
    'rock' => const Color(0xFF81713D),
    'bug' => const Color(0xFF718B35),
    'ghost' => const Color(0xFF665887),
    'steel' => const Color(0xFF647D89),
    _ => const Color(0xFF61706A),
  };
}

Color typeForegroundColor(String type) {
  final background = typeColor(type);
  final whiteContrast = _contrastRatio(background, Colors.white);
  final blackContrast = _contrastRatio(background, Colors.black);
  return whiteContrast >= blackContrast ? Colors.white : Colors.black;
}

double contrastRatio(Color first, Color second) {
  return _contrastRatio(first, second);
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
