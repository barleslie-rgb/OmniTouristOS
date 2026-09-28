import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum MetallicVariant {
  cobaltBlue,
  deepNavy,
  titaniumSilver,
  emeraldGreen,
  crimsonRed,
  burnishedGold,
}

class MetallicEmbossedButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final MetallicVariant variant;
  final double height;
  final double? width;
  final double borderRadius;
  final bool isFullWidth;
  final double fontSize;

  const MetallicEmbossedButton({
    Key? key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.variant = MetallicVariant.cobaltBlue,
    this.height = 46.0,
    this.width,
    this.borderRadius = 13.0,
    this.isFullWidth = false,
    this.fontSize = 12.5,
  }) : super(key: key);

  @override
  State<MetallicEmbossedButton> createState() => _MetallicEmbossedButtonState();
}

class _MetallicEmbossedButtonState extends State<MetallicEmbossedButton> {
  bool _isPressed = false;

  Map<String, dynamic> _getThemeSpecs() {
    switch (widget.variant) {
      case MetallicVariant.deepNavy:
        return {
          "gradient": const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF38BDF8),
              Color(0xFF1E3A8A),
              Color(0xFF003580),
              Color(0xFF0A192F),
            ],
            stops: [0.0, 0.25, 0.70, 1.0],
          ),
          "textColor": Colors.white,
          "shadowColor": const Color(0xFF003580),
          "bevelLight": const Color(0xFF7DD3FC),
          "bevelDark": const Color(0xFF020C1B),
        };

      case MetallicVariant.titaniumSilver:
        return {
          "gradient": const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFE2E8F0),
              Color(0xFFCBD5E1),
              Color(0xFF94A3B8),
            ],
            stops: [0.0, 0.30, 0.70, 1.0],
          ),
          "textColor": const Color(0xFF0F172A),
          "shadowColor": const Color(0xFF64748B),
          "bevelLight": const Color(0xFFFFFFFF),
          "bevelDark": const Color(0xFF94A3B8),
        };

      case MetallicVariant.emeraldGreen:
        return {
          "gradient": const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF86EFAC),
              Color(0xFF22C55E),
              Color(0xFF16A34A),
              Color(0xFF14532D),
            ],
            stops: [0.0, 0.25, 0.70, 1.0],
          ),
          "textColor": Colors.white,
          "shadowColor": const Color(0xFF166534),
          "bevelLight": const Color(0xFFBBF7D0),
          "bevelDark": const Color(0xFF052E16),
        };

      case MetallicVariant.crimsonRed:
        return {
          "gradient": const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFCA5A5),
              Color(0xFFEF4444),
              Color(0xFFDC2626),
              Color(0xFF7F1D1D),
            ],
            stops: [0.0, 0.25, 0.70, 1.0],
          ),
          "textColor": Colors.white,
          "shadowColor": const Color(0xFF991B1B),
          "bevelLight": const Color(0xFFFECACA),
          "bevelDark": const Color(0xFF450A0A),
        };

      case MetallicVariant.burnishedGold:
        return {
          "gradient": const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFBEB),
              Color(0xFFFDE68A),
              Color(0xFFD97706),
              Color(0xFF92400E),
            ],
            stops: [0.0, 0.25, 0.75, 1.0],
          ),
          "textColor": const Color(0xFF451A03),
          "shadowColor": const Color(0xFFB45309),
          "bevelLight": const Color(0xFFFEF3C7),
          "bevelDark": const Color(0xFF78350F),
        };

      case MetallicVariant.cobaltBlue:
      default:
        return {
          "gradient": const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF93C5FD),
              Color(0xFF3B82F6),
              Color(0xFF1D4ED8),
              Color(0xFF1E3A8A),
            ],
            stops: [0.0, 0.25, 0.70, 1.0],
          ),
          "textColor": Colors.white,
          "shadowColor": const Color(0xFF1E40AF),
          "bevelLight": const Color(0xFFBFDBFE),
          "bevelDark": const Color(0xFF172554),
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final specs = _getThemeSpecs();
    final Color shadowColor = specs["shadowColor"];
    final Color textColor = specs["textColor"];

    return GestureDetector(
      onTapDown: (_) {
        if (widget.onPressed != null) {
          HapticFeedback.selectionClick();
          setState(() => _isPressed = true);
        }
      },
      onTapUp: (_) {
        if (widget.onPressed != null) {
          setState(() => _isPressed = false);
          widget.onPressed!();
        }
      },
      onTapCancel: () {
        if (mounted) setState(() => _isPressed = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        height: widget.height,
        width: widget.isFullWidth ? double.infinity : widget.width,
        transform: Matrix4.translationValues(0, _isPressed ? 2.5 : 0.0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: specs["gradient"],
          border: Border.all(
            color: _isPressed ? specs["bevelDark"] : specs["bevelLight"].withOpacity(0.85),
            width: 1.5,
          ),
          boxShadow: _isPressed
              ? [
                  BoxShadow(
                    color: shadowColor.withOpacity(0.30),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.70),
                    blurRadius: 2,
                    offset: const Offset(-1.2, -1.2),
                  ),
                  BoxShadow(
                    color: shadowColor.withOpacity(0.50),
                    blurRadius: 7,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius - 1.2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.28),
                Colors.white.withOpacity(0.0),
              ],
              stops: const [0.0, 0.50],
            ),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: widget.fontSize + 3.5, color: textColor),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                    shadows: [
                      Shadow(
                        color: textColor == Colors.white
                            ? Colors.black.withOpacity(0.40)
                            : Colors.white.withOpacity(0.60),
                        offset: Offset(0, textColor == Colors.white ? 1.0 : -1.0),
                        blurRadius: 1.2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}