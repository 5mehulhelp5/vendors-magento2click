import 'package:flutter/material.dart';
import 'package:magentoegypt/common/extensions.dart';

import 'colors.dart';

TextTheme buildTextTheme(
  TextTheme base,
  String? language, [
  String fontFamily = 'El Messiri',
  String fontHeader = 'El Messiri',
]) {
  'inside buildTextTheme: the fontFamily: $fontFamily'.log();
  'inside buildTextTheme: the fontHeader: $fontHeader'.log();
  return base
      .copyWith(
        displayLarge: base.displayLarge!
            .copyWith(fontWeight: FontWeight.w700, fontFamily: fontFamily)
            .copyWith(
              /// If using the custom font
              /// un-comment below and clone to other headline.., bodyText..
              fontFamily: fontFamily,
            ),
        displayMedium: base.displayLarge!
            .copyWith(fontWeight: FontWeight.w700, fontFamily: fontFamily),
        displaySmall: base.displaySmall!
            .copyWith(fontWeight: FontWeight.w700, fontFamily: fontFamily),
        headlineMedium: base.headlineMedium!
            .copyWith(fontWeight: FontWeight.w700, fontFamily: fontFamily),
        headlineSmall: base.headlineSmall!
            .copyWith(fontWeight: FontWeight.w500, fontFamily: fontFamily),
        titleLarge:
            base.titleLarge!.copyWith(fontWeight: FontWeight.normal).copyWith(
                  fontFamily: fontFamily,
                ),
        bodySmall: base.bodySmall!.copyWith(
            fontWeight: FontWeight.w400,
            fontSize: 14.0,
            fontFamily: fontFamily),
        titleMedium: base.titleMedium!.copyWith(fontFamily: fontFamily),
        titleSmall: base.titleSmall!.copyWith(fontFamily: fontFamily),
        bodyLarge: base.bodyLarge!.copyWith(fontFamily: fontFamily),
        bodyMedium: base.bodyLarge!.copyWith(fontFamily: fontFamily),
        labelLarge: base.labelLarge!.copyWith(
            fontWeight: FontWeight.w400,
            fontSize: 14.0,
            fontFamily: fontFamily),
      )
      .apply(
        displayColor: textColorBlack,
        bodyColor: textColorBlack,
      );
}
