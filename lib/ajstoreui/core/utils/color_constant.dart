import 'dart:ui';
import 'package:flutter/material.dart';

class ColorConstant {
  static Color black9007f = fromHex('#7f050616');

  static Color black9007e = fromHex('#7e000000');

  static Color red600 = fromHex('#ee1c24');

  static Color blueA400 = fromHex('#1877f2');

  static Color red8007e = fromHex('#7ecf2027');

  static Color red800 = fromHex('#cf2027');

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


  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
