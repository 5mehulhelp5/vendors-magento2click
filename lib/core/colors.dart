import 'dart:ui';
import 'package:flutter/material.dart';

// class AppColors {
//   /// Primary Red Color #CF2027
//   static const Color kPrimaryRed = Color(0xFFCF2027);

//   /// Primary Blue Color #1C468C
//   static const Color kPrimaryBlue = Color(0xFF1C468C);

//   // top Status Bar Color #F77E2E
//   static const Color kOrange = Color(0xFFF77E2E);

//   // Primary Light Red Color #ECA6A8
//   static const Color kLightRed = Color(0xFFECA6A8);

//   /// a86ae1
//   static const Color kPrimaryLightColor = Color(0xFFa86ae1);

//   /// 22162c
//   static const Color kPrimaryMidColor = Color(0xFF22162c);

//   /// 827b92
//   static const Color kAppGreyColor = Color(0xFF827b92);

//   // Color(0xFF807e8b)
//   static const Color kProductBadgeGrey = Color(0xFF807e8b);

//   // Color(0xFF807e8b)
//   static const Color white = Color(0xFFFFFFFF);
// }

class AppColors {
  static Color kPrimaryBlue = fromHex('#1C468C');

  static Color black9007f = fromHex('#7f050616');

  static Color black9007e = fromHex('#7e000000');

  static Color red600 = fromHex('#ee1c24');

  static Color blueA400 = fromHex('#1877f2');

  static Color red8007e = fromHex('#7ecf2027');

  static Color kPrimaryRed = fromHex('#cf2027');

  static Color black90090 = fromHex('#90040516');

  static Color lightBlue700 = fromHex('#0078d7');

  static Color pinkA40000 = fromHex('#00e4003b');

  static Color teal9000c = fromHex('#0c023047');

  static Color pinkA40001 = fromHex('#e4003b');

  static Color black90087 = fromHex('#87000000');

  static Color greenA700 = fromHex('#25d366');

  static Color whiteA700Ef = fromHex('#efffffff');

  static Color teal900 = fromHex('#023047');

  static Color gray9000a = fromHex('#0a101828');

  static Color gray9000f = fromHex('#0f101828');

  static Color redA700 = fromHex('#e60023');

  static Color gray600 = fromHex('#717171');

  static Color black9004c = fromHex('#4c000000');

  static Color blueGray100 = fromHex('#d9d9d9');

  static Color blue500 = fromHex('#1da1f2');

  static Color lime900 = fromHex('#759e00');

  static Color whiteA70066 = fromHex('#66ffffff');

  static Color red80001 = fromHex('#c1272d');

  static Color black90099 = fromHex('#99000000');

  static Color whiteA70067 = fromHex('#67ffffff');

  static Color blueGray50019 = fromHex('#1972769c');

  static Color black90019 = fromHex('#19000000');

  static Color black90014 = fromHex('#14000000');

  static Color whiteA700 = fromHex('#ffffff');

  static Color black90059 = fromHex('#59000000');

  static Color black9005e = fromHex('#5e000000');

  static Color red700 = fromHex('#ed1c24');

  static Color blueGray50 = fromHex('#f0f1f3');

  static Color blueGray10001 = fromHex('#d1d5e9');

  static Color blueGray10002 = fromHex('#d1d5ea');

  static Color gray50 = fromHex('#f9f9f9');

  static Color lightGreen900 = fromHex('#428d00');

  static Color black900 = fromHex('#000000');

  static Color pinkA400 = fromHex('#f00073');

  static Color black90063 = fromHex('#63000000');

  static Color yellow900 = fromHex('#d1752f');

  static Color gray700 = fromHex('#646464');

  static Color whiteA7006c = fromHex('#6cffffff');

  static Color red60001 = fromHex('#e92728');

  static Color gray500 = fromHex('#adadad');

  static Color blueGray400 = fromHex('#888888');

  static Color black9006c = fromHex('#6c000000');

  static Color gray300 = fromHex('#e5e5e5');

  static Color gray100 = fromHex('#f4f2f2');

  static Color yellow90002 = fromHex('#ff841d');

  static Color yellow90001 = fromHex('#f77e2e');

  static Color lightBlue70001 = fromHex('#0088cc');

  static Color red80063 = fromHex('#63cf2027');

  static Color whiteA70005 = fromHex('#05ffffff');

  static Color pinkA4000c = fromHex('#0ce4003b');

  static Color colorIcon = fromHex('#878787');

  static Color colorActiveIcon = fromHex('#000000');

  static Color textColor(BuildContext context) {
    bool isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return isDarkTheme ? Colors.black87 : Colors.white;
  }

  static Color textColorWithoutBg(BuildContext context) {
    bool isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return isDarkTheme ? Colors.white : Colors.black87;
  }

  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
