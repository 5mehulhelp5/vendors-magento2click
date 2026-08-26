import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../common/tools/tools.dart';
import '../../generated/l10n.dart';

class OtpDialog  {

  static  String generateOtp() {
    final rnd = Random.secure();
    final code = rnd.nextInt(900000) + 100000; // ensures 6 digits
    // Debug-only: surfaces the OTP in `adb logcat -s flutter` for QA testing.
    // Guarded by kDebugMode so it is tree-shaken out of release/profile builds
    // and can never leak the code in a shipped app.
    if (kDebugMode) {
      print('GENERATED_OTP=$code');
    }
    return code.toString();
  }

  static void showOtpDialog(BuildContext context,String phoneNumber,String currentOtp,Function(String,String) loginSms) {

    var  onTapRecognizer = TapGestureRecognizer()
      ..onTap = () {
        loginSms("", "resend");
      };

    final TextEditingController pinCodeController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String otp = '';

        return AlertDialog(
          title: Text(S.of(context).phoneNumberVerification),
          contentPadding: const EdgeInsets.fromLTRB(12, 20, 12, 24),
          content: Wrap(
            children: [
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 0.0, vertical: 4),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: RichText(
                    text: TextSpan(
                      text: S.of(context).enterSendedCode,
                      children: [
                        TextSpan(
                          text: Tools.isRTL(context)
                              ? ' ${phoneNumber.replaceAll('+', '')}+'
                              : ' +${phoneNumber.replaceAll('+', '')}',
                          style:
                          Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: 15,
                          ),
                        ),
                      ],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withOpacity(0.54),
                        fontSize: 15,
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0.0),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: PinCodeTextField(
                    appContext: context,
                    controller: pinCodeController,
                    keyboardType: TextInputType.number,
                    pinTheme: PinTheme(
                      shape: PinCodeFieldShape.underline,
                      borderWidth: 2,
                      fieldWidth: 36,
                      activeFillColor: Theme.of(context).colorScheme.background,
                      disabledColor: Theme.of(context).disabledColor,
                    ),
                    length: 6,
                    mainAxisAlignment: MainAxisAlignment.center,
                    cursorHeight: 25,
                    autoFocus: true,
                    obscuringCharacter: '*',
                    textStyle: Theme.of(context)
                        .primaryTextTheme
                        .displaySmall!
                        .copyWith(
                      color: Theme.of(context).primaryColor,
                    ),
                    animationType: AnimationType.scale,
                    hapticFeedbackTypes: HapticFeedbackTypes.light,
                    useHapticFeedback: true,
                    autoDisposeControllers: false,
                    animationDuration: const Duration(milliseconds: 300),
                    onChanged: (value) {
                      //  if (value.length == 6) _loginSMS(value, context);
                    },
                  ),
                ),
              ),
              // Full-width so the "Didn't receive the code? RESEND" line
              // centres in the dialog. It was pinned to the trailing edge
              // (Alignment.topRight), which read as off to one side — right in
              // English, left in Arabic. TextAlign.center is direction-agnostic
              // so it centres in both views (86d3pkmkd #4).
              //
              // The prefix span also needs an explicit colour: RichText does
              // not inherit DefaultTextStyle, so `TextStyle(fontSize: 15)` with
              // no colour rendered the "Didn't receive the code?" invisible —
              // only RESEND (which sets its own colour) showed, which made the
              // centring look off because the invisible prefix still took up
              // half the line.
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  // Resend on its own, centred. The "Didn't receive the code?"
                  // / "لم استلم رمز التأكيد؟" lead-in was dropped at QA's
                  // request (86d3pkmkd #4): with it, the tappable RESEND sat
                  // off to one side of the sentence rather than centred in the
                  // dialog. The strings are trimmed because both carry padding
                  // that only made sense when they were joined.
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      text: S.of(context).resend.trim(),
                      recognizer: onTapRecognizer,
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
          actions: [
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(S.of(context).cancel),
                ),
                Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    // Handle OTP submission
                    if (pinCodeController.text.trim().length == 6 && pinCodeController.text.trim() == currentOtp) {
                      Navigator.of(context).pop();
                      loginSms(pinCodeController.text, "verify");
                    }else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(S.of(context).validOTP)),
                      );
                    }
                  },
                  child: Text(S.of(context).verifySMSCode),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

}