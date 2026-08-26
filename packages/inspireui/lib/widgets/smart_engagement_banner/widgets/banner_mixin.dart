import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

mixin BannerMixin {
  Widget closeButton(
    context, {
    required VoidCallback onTap,
    required AlignmentGeometry alignment,
    double? iconSize,
    bool isCircleIcon = false,
  }) {
    var decoration = isCircleIcon
        ? ShapeDecoration(
            shape: CircleBorder(
              side: BorderSide(
                color: Theme.of(context).colorScheme.secondary,
                width: 1.0,
              ),
            ),
            color: Theme.of(context).colorScheme.background,
          )
        : BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            color: Theme.of(context).colorScheme.background,
          );

    return Align(
      alignment: alignment,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: isCircleIcon ? null : const EdgeInsets.all(4),
          decoration: decoration,
          child: Icon(
            Icons.close_rounded,
            size: iconSize ?? 25,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ),
    );
  }

  AlignmentGeometry getAlignment(
    String? alignment, {
    AlignmentGeometry? defaultValue,
  }) {
    switch (alignment) {
      case 'left':
      case 'centerLeft':
        return Alignment.centerLeft;
      case 'right':
      case 'centerRight':
        return Alignment.centerRight;
      case 'topLeft':
        return Alignment.topLeft;
      case 'topRight':
        return Alignment.topRight;
      case 'bottomLeft':
        return Alignment.bottomLeft;
      case 'bottomRight':
        return Alignment.bottomRight;
      case 'bottomCenter':
        return Alignment.bottomCenter;
      case 'topCenter':
        return Alignment.topCenter;
      case 'center':
        return Alignment.center;
      default:
        return defaultValue ?? Alignment.center;
    }
  }

  bool isRTL(BuildContext context) {
    return Bidi.isRtlLanguage(Localizations.localeOf(context).languageCode);
  }
}
