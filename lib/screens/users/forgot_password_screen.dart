import 'dart:async';

import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:magentoegypt/core/colors.dart';
import 'package:magentoegypt/screens/users/reset_password_screen.dart';
import 'package:provider/provider.dart';

import '../../common/tools/flash.dart';
import '../../generated/l10n.dart';
import '../../models/app_model.dart';
import '../../services/index.dart';
import '../../widgets/common/ToggleButton.dart';
import '../../widgets/common/flux_image.dart';
import '../../widgets/common/webview.dart';
import 'otp_dialog.dart';

class ForgotPasswordScreen extends StatefulWidget {
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPasswordScreen> {
  final TextEditingController forgotPasswordController =
      TextEditingController();
  final TextEditingController emailController = TextEditingController();
  String selectedCode = '20'; // default value
  bool isSubmitting = false;
  bool isLoginOTP = true;

  void onSubmitPassword(BuildContext context) async {
    var currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus) {
      currentFocus.unfocus();
    }

    var userName =
        isLoginOTP ? forgotPasswordController.text : emailController.text;
    if(isLoginOTP){
      if(userName.trim().isEmpty){
        unawaited(
          FlashHelper.errorMessage(context, message: S.of(context).enterMobile),
        );
      }else if(userName.trim().startsWith("0")){
        unawaited(
          FlashHelper.errorMessage(context, message: S.of(context).validMobileWithout0),
        );
      }else if(userName.trim().length != 10){
        unawaited(
          FlashHelper.errorMessage(context, message: S.of(context).validMobile),
        );
      }else{
        String currentOtp = OtpDialog.generateOtp();
        setState(() {
          isSubmitting = true;
        });
        final json = await Services().api.mobileSendOtp("$selectedCode${userName.trim()}",currentOtp);
        final message = json?['error']?['message'] ?? '';
        setState(() {
          isSubmitting = false;
        });
        if(message.isEmpty){
          OtpDialog.showOtpDialog(context, "$selectedCode${userName.trim()}",currentOtp,((otpCode,actionFrom) async {
            if(actionFrom == "resend"){
              Services().api.mobileSendOtp("$selectedCode${userName.trim()}",currentOtp);
            }else if(actionFrom == "verify"){
              setState(() {
                isSubmitting = true;
              });
              final response = await Services().api.forgotPasswordMobile(mobile: "$selectedCode${userName.trim()}");
              setState(() {
                isSubmitting = false;
              });
              if ((response ?? "").startsWith("http")){
                // In-app WebView, not launchUrl(). That URL carries a
                // single-use password-reset token — a full account-takeover
                // credential until it is consumed — and launchUrl with no
                // LaunchMode resolves to platformDefault, i.e. Chrome Custom
                // Tabs / SFSafariViewController. The token would land in the
                // system browser's history and be synced to the shopper's
                // Google/Apple account. Keeping it in the app's own WebView
                // keeps it in the app's storage, and matches how
                // login_screen.dart already opens the same reset URL.
                if (!mounted) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => WebView(
                      url: response,
                      title: S.of(context).resetPassword,
                    ),
                    fullscreenDialog: true,
                  ),
                );
              }else{
                unawaited(
                  FlashHelper.errorMessage(context, message: response ?? ""),
                );
              }
            }
          }));

          // await Navigator.push(context,
          //   MaterialPageRoute(builder: (context) => ResetPasswordScreen(phoneNumber: "$selectedCode${userName.trim()}",currentOtp: currentOtp,)),
          // );
        }else{
          unawaited(
            FlashHelper.errorMessage(context, message: message),
          );
        }
      }
    }else{
      if (userName.isEmpty) {
        final snackBar = SnackBar(
          content: Text(S.of(context).emptyUsername),
          duration: const Duration(seconds: 3),
        );

        ScaffoldMessenger.of(context).showSnackBar(snackBar);
        return;
      }
      setState(() {
        isSubmitting = true;
      });

      try {
        await Services().widget.resetPassword(context, userName);
        setState(() {
          isSubmitting = false;
        });
      } catch (e) {
        setState(() {
          isSubmitting = false;
        });
        final snackBar = SnackBar(
          content: Text(e.toString()),
          duration: const Duration(seconds: 3),
        );

        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    }
  }

  @override
  void dispose() {
    forgotPasswordController.dispose();
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appModel = Provider.of<AppModel>(context, listen: true);
    final themeConfig = appModel.themeConfig;
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: Theme.of(context).colorScheme.secondary,
            size: 24,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        centerTitle: false,
        title: FractionallySizedBox(
          widthFactor: 0.3,
          child: FluxImage(
            imageUrl: themeConfig.logo,
            fit: BoxFit.contain,
          ),
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
                    S.of(context).forgotpassword,
                    style: TextStyle(
                        fontSize: 30.0, color: Theme.of(context).primaryColor),
                  ),
                  const SizedBox(
                    height: 40.0,
                  ),
                  Container(
                    padding: EdgeInsets.all(10.0),
                    child: ToggleButton(
                      width: MediaQuery.of(context).size.width,
                      height: 60.0,
                      toggleBackgroundColor: Theme.of(context).primaryColor,
                      toggleBorderColor: (Colors.grey[350])!,
                      toggleColor: Theme.of(context).primaryColor,
                      activeTextColor: AppColors.textColor(context),
                      inactiveTextColor: Colors.grey,
                      leftDescription: S.of(context).phoneNumber,
                      rightDescription: S.of(context).email,
                      onLeftToggleActive: () {
                        setState(() {
                          isLoginOTP = true;
                        });
                      },
                      onRightToggleActive: () {
                        setState(() {
                          isLoginOTP = false;
                        });
                      },
                    ),
                  ),
                  if(isLoginOTP)
                    Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Padding(
                                padding: const EdgeInsets.only(top: 0.0),
                                child: CountryCodePicker(
                                  onChanged: (country) {
                                    setState(() {
                                      selectedCode = (country.dialCode ?? '').replaceAll('+', '');
                                    });
                                  },
                                  // Initial selection and favorite can be one of code ('IT') OR dial_code('+39')
                                  initialSelection: "eg",
                                  //Get the country information relevant to the initial selection
                                  backgroundColor:
                                  Theme.of(context).colorScheme.background,
                                  dialogBackgroundColor:
                                  Theme.of(context).dialogBackgroundColor,
                                ),
                              ),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: TextField(
                                decoration:
                                InputDecoration(labelText: S.of(context).phone),
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                controller: forgotPasswordController,
                              ),
                            )
                          ],
                        ),
                    ),
                  const SizedBox(
                    height: 10.0,
                  ),
                  Text(
                    isLoginOTP ? "":S.of(context).getPasswordInstruction,
                    style: TextStyle(
                      color: AppColors.textColorWithoutBg(context),
                      fontSize: 16.0,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if(!isLoginOTP)
                    const SizedBox(
                      height: 10.0,
                    ),
                  if(!isLoginOTP)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.of(context).email, // Label text
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          autocorrect: false,
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          // decoration: InputDecoration(
                          //   hintText: S.of(context).username,
                          // ),
                          decoration: InputDecoration(
                            contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Colors.grey, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Colors.black, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(
                    height: 30.0,
                  ),
                  InkWell(
                    onTap: () =>
                        isSubmitting ? null : onSubmitPassword(context),
                    child: Container(
                      height: 50.0,
                      //width: 200.0,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(10.0)),
                      ),
                      child: Center(
                        child: Text(
                          isSubmitting
                              ? S.of(context).loading
                              : isLoginOTP ? S.of(context).sendSMSCode:S.of(context).getPasswordLink,
                          style:  TextStyle(
                            color: AppColors.textColor(context),
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
