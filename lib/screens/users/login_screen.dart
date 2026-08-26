// ignore_for_file: unused_element

import 'dart:async';
import 'dart:convert';

import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:magentoegypt/screens/users/otp_dialog.dart';
import 'package:magentoegypt/widgets/auth/social_login_button_row.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../common/config.dart';
import '../../common/constants.dart';
import '../../common/events.dart';
import '../../common/tools.dart';
import '../../common/tools/flash.dart';
import '../../core/colors.dart';
import '../../generated/l10n.dart';
import '../../models/index.dart';
import '../../services/index.dart';
import '../../widgets/common/ToggleButton.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/flux_image.dart';
import '../../widgets/common/login_animation.dart';
import '../../widgets/common/webview.dart';
import '../base_screen.dart';
import 'forgot_password_screen.dart';

typedef LoginSocialFunction = Future<void> Function({
  required Function(User user) success,
  required Function(String) fail,
  BuildContext context,
});

typedef LoginFunction = Future<void> Function({
  required String username,
  required String password,
  required Function(User user) success,
  required Function(String) fail,
});

typedef LoginMobileFunction = Future<void> Function({
required String mobile,
required Function(User user) success,
required Function(String) fail,
});

class LoginScreen extends StatefulWidget {
  final LoginFunction login;
  final LoginMobileFunction loginMobile;
  final LoginSocialFunction loginFB;
 // final LoginSocialFunction loginApple;
  final LoginSocialFunction loginGoogle;
  final VoidCallback? loginSms;

  const LoginScreen({
    required this.login,
    required this.loginMobile,
    required this.loginFB,
  //  required this.loginApple,
    required this.loginGoogle,
    this.loginSms,
  });

  @override
  BaseScreen<LoginScreen> createState() => _LoginPageState();
}

class _LoginPageState extends BaseScreen<LoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _loginButtonController;
  final TextEditingController username = TextEditingController();
  final TextEditingController password = TextEditingController();
  String selectedCode = '20'; // default value
  final usernameNode = FocusNode();
  final passwordNode = FocusNode();

  late var parentContext;
  bool isLoading = false;
  bool isActiveAudio = false;
  bool isLoginOTP = false;

  @override
  void initState() {
    super.initState();
    _loginButtonController = AnimationController(
        duration: const Duration(milliseconds: 3000), vsync: this);
  }

  @override
  Future<void> afterFirstLayout(BuildContext context) async {

  }

  @override
  void dispose() async {
    _loginButtonController.dispose();
    username.dispose();
    password.dispose();
    usernameNode.dispose();
    passwordNode.dispose();
    super.dispose();
  }

  Future _playAnimation() async {
    try {
      setState(() {
        isLoading = true;
      });
      await _loginButtonController.forward();
    } on TickerCanceled {
      printLog('[_playAnimation] error');
    }
  }

  Future _stopAnimation() async {
    try {
      await _loginButtonController.reverse();
      setState(() {
        isLoading = false;
      });
    } on TickerCanceled {
      printLog('[_stopAnimation] error');
    }
  }

  Future _welcomeMessage() async {
    eventBus.fire(const EventLoggedIn());
    final canPop = ModalRoute.of(context)!.canPop;
    if (canPop) {
      // When not required login
      Navigator.of(context).pop();
    } else {
      // When required login
      await Navigator.of(App.fluxStoreNavigatorKey.currentContext!)
          .pushReplacementNamed(RouteList.dashboard);
    }
  }

  void _failMessage(String message) {
    if (message.isEmpty) return;

    var messageText = message;
    if (kReleaseMode) {
      messageText = S.of(context).UserNameInCorrect;
    }

    FlashHelper.errorMessage(
      context,
      message: S.of(context).warning(messageText),
    );
  }



  @override
  Widget build(BuildContext context) {
    parentContext = context;
    final appModel = Provider.of<AppModel>(context);
    final screenSize = MediaQuery.of(context).size;
    final themeConfig = appModel.themeConfig;
    var forgetPasswordUrl = ServerConfig().forgetPassword;

    Future launchForgetPassworddWebView(String url) async {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              WebView(url: url, title: S.of(context).resetPassword),
          fullscreenDialog: true,
        ),
      );
    }

    void launchForgetPasswordURL(String? url) async {
      if (url != null && url != '') {
        /// show as webview
        await launchForgetPassworddWebView(url);
      } else {
        /// show as native
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ForgotPasswordScreen()),
        );
      }
    }


    void login(context) async {
      if (username.text.isEmpty || password.text.isEmpty) {
        unawaited(
          FlashHelper.errorMessage(context, message: S.of(context).pleaseInput),
        );
      } else {
        await _playAnimation();
        await widget.login(
          username: username.text.trim(),
          password: password.text.trim(),
          success: (user) {
            _stopAnimation();
            _welcomeMessage();
            Provider.of<ProductWishListModel>(context, listen: false).getLocalWishlist();
          },
          fail: (message) {
            _stopAnimation();
            _failMessage(message);
          },
        );
      }
    }

    void loginSMS(context) {
      if (widget.loginSms != null) {
        widget.loginSms!();
        return;
      }
      final supportedPlatforms = [
        'wcfm',
        'dokan',
        'delivery',
        'vendorAdmin',
        'woo',
        'wordpress'
      ].contains(ServerConfig().typeName);
      Navigator.of(context).pushNamed(RouteList.digitsMobileLogin);
    }

    void loginGoogle(context) async {
      await _playAnimation();
      await widget.loginGoogle(
          success: (user) {
            //hideLoading();
            _stopAnimation();
            _welcomeMessage();
            Provider.of<ProductWishListModel>(context, listen: false).getLocalWishlist();
          },
          fail: (message) {
            //hideLoading();
            _stopAnimation();
            _failMessage(message);
          },
          context: context);
    }

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        //backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: Theme.of(context).colorScheme.secondary,
              size: 24,
            ),
            onPressed: () {
              // If there is a previous page, return to it. Otherwise (login was
              // opened as the root route, e.g. from onboarding via
              // pushReplacement) go to the dashboard instead of leaving a blank
              // white screen.
              if (ModalRoute.of(context)!.canPop) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(App.fluxStoreNavigatorKey.currentContext!)
                    .pushReplacementNamed(RouteList.dashboard);
              }
            },
          ),
          elevation: 0.0,
          // Close (X) removed per QA: the back arrow already returns the user
          // to the previous page (or the dashboard when login is the root),
          // so the extra dismiss icon is redundant.
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                AutoHideKeyboard(
                  child: Center(
                    child:
                        Consumer<UserModel>(builder: (context, model, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        alignment: Alignment.center,
                        width: screenSize.width /
                            (2 / (screenSize.height / screenSize.width)),
                        constraints: const BoxConstraints(maxWidth: 700),
                        child: AutofillGroup(
                          child: Column(
                            children: <Widget>[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  _buildButton(S.of(context).login, 0),
                                  const SizedBox(width: 16),
                                  _buildButton(S.of(context).newAccount, 1),
                                ],
                              ),
                              const SizedBox(height: 30),
                              // Column(
                              //   children: [
                              //     const SizedBox(height: 50.0),
                              //     Text(
                              //       S.of(context).loginMessage,
                              //       textAlign: TextAlign.center,
                              //     ),
                              //   ],
                              // ),
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Container(
                                    //   padding: EdgeInsets.all(10.0),
                                    //   child: ToggleButton(
                                    //     width: MediaQuery.of(context).size.width,
                                    //     height: 70.0,
                                    //     toggleBackgroundColor: Theme.of(context).primaryColor,
                                    //     toggleBorderColor: (Colors.grey[350])!,
                                    //     toggleColor: Theme.of(context).primaryColor,
                                    //     activeTextColor: AppColors.textColor(context),
                                    //     inactiveTextColor: Colors.grey,
                                    //     leftDescription: S.of(parentContext).loginWithOTP,
                                    //     rightDescription: S.of(parentContext).loginWithPassword,
                                    //     onLeftToggleActive: () {
                                    //       setState(() {
                                    //         isLoginOTP = true;
                                    //         username.text = "";
                                    //       });
                                    //     },
                                    //     onRightToggleActive: () {
                                    //       setState(() {
                                    //         isLoginOTP = false;
                                    //         username.text = "";
                                    //       });
                                    //     },
                                    //   ),
                                    // ),
                                    const SizedBox(height: 20.0),
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
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                                LengthLimitingTextInputFormatter(
                                                    10),
                                              ],
                                              controller: username,
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                    if(!isLoginOTP)
                                    CustomTextField(
                                      key: const Key('loginEmailField'),
                                      controller: username,
                                      autofillHints: const [
                                        AutofillHints.email
                                      ],
                                      showCancelIcon: true,
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      textInputAction: TextInputAction.next,
                                      keyboardType: TextInputType.emailAddress,
                                      nextNode: passwordNode,
                                      decoration: InputDecoration(
                                        labelText: S.of(parentContext).username,
                                        hintText: S
                                            .of(parentContext)
                                            .enterYourEmailOrUsername,
                                      ),
                                    ),
                                    if(!isLoginOTP)
                                    const SizedBox(height: 10),
                                    if(!isLoginOTP)
                                    CustomTextField(
                                      key: const Key('loginPasswordField'),
                                      autofillHints: const [
                                        AutofillHints.password
                                      ],
                                      obscureText: true,
                                      showEyeIcon: true,
                                      textInputAction: TextInputAction.done,
                                      controller: password,
                                      focusNode: passwordNode,
                                      decoration: InputDecoration(
                                        labelText: S.of(parentContext).password,
                                        hintText: S
                                            .of(parentContext)
                                            .enterYourPassword,
                                      ),
                                    ),
                                   // if (!kLoginSetting.isResetPasswordSupported)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12.0),
                                        child: GestureDetector(
                                          onTap: () {
                                           // launchForgetPasswordURL(forgetPasswordUrl);
                                            launchForgetPasswordURL('');
                                          },
                                          behavior: HitTestBehavior.opaque,
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Text(
                                              S.of(context).resetPassword,
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .primaryColor,
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (!kLoginSetting.isResetPasswordSupported)
                                      const SizedBox(height: 50.0),
                                    StaggerAnimation(
                                      key: const Key('loginSubmitButton'),
                                      titleButton:
                                      isLoginOTP ?  S.of(context).sendSMSCode:S.of(context).signInWithEmail,
                                      buttonController: _loginButtonController
                                          .view as AnimationController,
                                      onTap: () async {
                                        if (!isLoading) {
                                          if(isLoginOTP){
                                            if(username.text.trim().isEmpty){
                                              unawaited(
                                                FlashHelper.errorMessage(context, message: S.of(context).enterMobile),
                                              );
                                            }else if(username.text.trim().startsWith("0")){
                                              unawaited(
                                                FlashHelper.errorMessage(context, message: S.of(context).validMobileWithout0),
                                              );
                                            }else if(username.text.trim().length != 10){
                                              unawaited(
                                                FlashHelper.errorMessage(context, message: S.of(context).validMobile),
                                              );
                                            }else{
                                              _playAnimation();
                                              // Only send the OTP if a customer is registered with this
                                              // number. wapplogin/customer/login returns a token for
                                              // registered numbers and errors otherwise.
                                              try {
                                                await Services().api.loginMobile(
                                                    mobile:
                                                        "$selectedCode${username.text.trim()}");
                                              } catch (_) {
                                                _stopAnimation();
                                                unawaited(
                                                  FlashHelper.errorMessage(context,
                                                      message: S
                                                          .of(context)
                                                          .noCustomerWithMobile),
                                                );
                                                return;
                                              }
                                              String currentOtp = OtpDialog.generateOtp();
                                              final json = await Services().api.mobileSendOtp("$selectedCode${username.text.trim()}",currentOtp);
                                              _stopAnimation();
                                              final message = json?['error']?['message'] ?? '';
                                              if(message.isEmpty){
                                                OtpDialog.showOtpDialog(context, "$selectedCode${username.text.trim()}",currentOtp,((otpCode,actionFrom) async {
                                                  if(actionFrom == "resend"){
                                                    Services().api.mobileSendOtp("$selectedCode${username.text.trim()}",currentOtp);
                                                  }else if(actionFrom == "verify"){
                                                    await _playAnimation();
                                                    await widget.loginMobile(
                                                      mobile: "$selectedCode${username.text.trim()}",
                                                      success: (user) {
                                                        _stopAnimation();
                                                        _welcomeMessage();
                                                        Provider.of<ProductWishListModel>(context, listen: false).getLocalWishlist();
                                                      },
                                                      fail: (message) {
                                                        _stopAnimation();
                                                        _failMessage(message);
                                                      },
                                                    );
                                                  }
                                                }));
                                              }else{
                                                unawaited(
                                                  FlashHelper.errorMessage(context, message:message),
                                                );
                                              }
                                            }
                                          }else{
                                            login(context);
                                          }
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 10.0),
                                    GestureDetector(
                                      onTap: (){
                                        setState(() {
                                          isLoginOTP = !isLoginOTP;
                                          // The email login field and the OTP
                                          // phone field share `username`;
                                          // clear it on toggle so a typed email
                                          // doesn't carry over into the phone
                                          // field (and vice-versa).
                                          username.clear();
                                        });
                                      },
                                      child: Container(
                                        width: 320.0,
                                        height: 50,
                                        alignment: FractionalOffset.center,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).primaryColor,
                                          borderRadius: const BorderRadius.all(Radius.circular(4.0)),
                                        ),
                                        child: Text(
                                          !isLoginOTP ? S.of(context).loginWithOTP:S.of(context).loginWithPassword,
                                          style: TextStyle(
                                            color: AppColors.textColor(context),
                                            fontSize: 16.0,
                                            fontWeight: FontWeight.w300,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),

                              const SizedBox(height: 30.0),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
            child: Container(
          padding: const EdgeInsets.all(50.0),
          child: kLoadingWidget(context),
        ));
      },
    );
  }


  void hideLoading() {
    Navigator.of(context).pop();
  }
  Widget _buildButton(String title, int index) {
    final bool isSelected = 0 == index;

    return TextButton(
      onPressed: () {
        if(index == 1){
          // Replace (not stack) so toggling Login <-> New Account stays one
          // screen deep and Back returns to wherever the user came from.
          NavigateTools.navigateRegister(context, replacement: true);
        }
      },
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: 60,
            color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          ),
        ],
      ),
    );
  }
}