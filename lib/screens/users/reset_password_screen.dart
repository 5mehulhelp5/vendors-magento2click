import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../common/constants.dart';
import '../../common/tools/flash.dart';
import '../../common/tools/tools.dart';
import '../../generated/l10n.dart';
import '../../services/index.dart';
import '../../widgets/common/custom_text_field.dart';

class ResetPasswordScreen extends StatefulWidget {
  String phoneNumber;
  String currentOtp;
   ResetPasswordScreen({
     super.key,
    required this.phoneNumber,
  required this.currentOtp
  });
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordState();
}

class _ResetPasswordState extends State<ResetPasswordScreen> {
  final TextEditingController passwordController =
  TextEditingController();
  final TextEditingController confirmPasswordController =
  TextEditingController();
  final TextEditingController pinCodeController = TextEditingController();
  bool isSubmitting = false;

  void onSubmitPassword(BuildContext context) async {

    var currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus) {
      currentFocus.unfocus();
    }

    if (pinCodeController.text.trim().length != 6) {
      _showMessage(S.of(context).validOTP);
    }else if (passwordController.text.trim().length < 8) {
      _showMessage(S.of(context).errorPasswordFormat);
    }else if(passwordController.text.trim() != confirmPasswordController.text.trim()){
      _showMessage(S.of(context).passwordNotMatch);
    }else{
      setState(() {
        isSubmitting = true;
      });

      try {
        final params = {"mobile":widget.phoneNumber,"otp": pinCodeController.text.trim(),"password": passwordController.text.trim(),"type": "FORGOTPASS"};
        // Deliberately not logged: this map holds the OTP and the shopper's new
        // password in cleartext, and a bare print() is not stripped from
        // release builds.
        // final json = await Services().api.mobileVerifyOtp(params);
        // setState(() {
        //   isSubmitting = false;
        // });
        // if(json?["status"]  == "success"){
        //   _showMessage(S.of(context).password_changeSuccess);
        //   Navigator.of(context).popUntil((route){
        //     return route.settings.name == RouteList.login;
        //   });
        // }else{
        //   _showMessage( json?["message"]);
        // }
      } catch (e) {
        setState(() {
          isSubmitting = false;
        });
        _showMessage(e.toString());
      }
    }
  }

  void _showMessage(
      String text, {
        bool isError = true,
      }) {
    if (!mounted) {
      return;
    }
    FlashHelper.message(
      context,
      message: text,
      isError: isError,
    );
  }

  @override
  void dispose() {
    pinCodeController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Theme.of(context).colorScheme.background,
      ),
      body: Builder(
        builder: (context) => SafeArea(
          child: Container(
            alignment: Alignment.center,
            width:
            screenSize.width / (2 / (screenSize.height / screenSize.width)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    S.of(context).resetYourPassword,
                    style: TextStyle(
                        fontSize: 30.0, color: Theme.of(context).primaryColor),
                  ),
                  const SizedBox(
                    height: 20.0,
                  ),
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
                                  ? ' ${widget.phoneNumber.replaceAll('+', '')}+'
                                  : ' +${widget.phoneNumber.replaceAll('+', '')}',
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
                  const SizedBox(
                    height: 20.0,
                  ),
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
                          activeFillColor: Theme.of(context).colorScheme.background,
                          disabledColor: Theme.of(context).disabledColor,
                        ),
                        length: 6,
                        cursorHeight: 30,
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
                  const SizedBox(height: 20.0),
                  CustomTextField(
                    key: const Key('registerPasswordField'),
                    autofillHints: const [AutofillHints.password],
                    showEyeIcon: true,
                    obscureText: true,
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: S.of(context).enterYourPassword,
                      hintText: S.of(context).enterYourPassword,
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  CustomTextField(
                    key: const Key('registerConfirmPasswordField'),
                    autofillHints: const [AutofillHints.password],
                    showEyeIcon: true,
                    obscureText: true,
                    controller: confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: S.of(context).enterYourConfirmPassword,
                      hintText: S.of(context).enterYourConfirmPassword,
                    ),
                  ),
                  const SizedBox(
                    height: 30.0,
                  ),
                  InkWell(
                    onTap: () =>
                    isSubmitting ? null : onSubmitPassword(context),
                    child: Container(
                      height: 50.0,
                      width: 200.0,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius:
                        const BorderRadius.all(Radius.circular(25.0)),
                      ),
                      child: Center(
                        child: Text(
                          isSubmitting
                              ? S.of(context).loading
                              : S.of(context).save,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16.0,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 50.0,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
