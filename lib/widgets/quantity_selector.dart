/// Quantity selector widget with circular +/- buttons
///
/// Used in the cart screen and product detail screen.
/// Supports min value 1 and max value 99 with callbacks.

import 'package:flutter/material.dart';
import '../config/app_config.dart';

class QuantitySelector extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onIncrement;
  final ValueChanged<int> onDecrement;
  final int minValue;
  final int maxValue;
  final double buttonSize;
  final double iconSize;
  final double fontSize;
  final Color? activeColor;
  final Color? inactiveColor;

  const QuantitySelector({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.minValue = 1,
    this.maxValue = 99,
    this.buttonSize = 32,
    this.iconSize = 18,
    this.fontSize = 15,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = activeColor ?? const Color(AppConfig.PRIMARY_COLOR);
    final canDecrement = quantity > minValue;
    final canIncrement = quantity < maxValue;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Minus button
        _CircleButton(
          onTap: canDecrement ? () => onDecrement(quantity - 1) : null,
          icon: Icons.remove_rounded,
          size: buttonSize,
          iconSize: iconSize,
          color: canDecrement ? primaryColor : (inactiveColor ?? const Color(AppConfig.TEXT_HINT)),
        ),

        // Quantity display
        SizedBox(
          width: buttonSize + 8,
          child: Center(
            child: Text(
              '$quantity',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: const Color(AppConfig.TEXT_PRIMARY),
              ),
            ),
          ),
        ),

        // Plus button
        _CircleButton(
          onTap: canIncrement ? () => onIncrement(quantity + 1) : null,
          icon: Icons.add_rounded,
          size: buttonSize,
          iconSize: iconSize,
          color: canIncrement ? primaryColor : (inactiveColor ?? const Color(AppConfig.TEXT_HINT)),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final double size;
  final double iconSize;
  final Color color;

  const _CircleButton({
    required this.onTap,
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.2),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: iconSize,
            color: color,
          ),
        ),
      ),
    );
  }
}
