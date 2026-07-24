import 'package:flutter/material.dart';

import '../../core/theme/type_colors.dart';

class TypeBadge extends StatelessWidget {
  const TypeBadge({required this.type, this.compact = false, super.key});

  final String type;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = typeColor(type);
    return Semantics(
      label: '$type type',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 12,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          type,
          style: TextStyle(
            color: typeForegroundColor(type),
            fontSize: compact ? 12 : 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
