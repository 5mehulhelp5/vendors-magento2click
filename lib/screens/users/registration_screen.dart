



import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:inspireui/extensions/string_extension.dart';
import 'package:magentoegypt/app.dart';
import 'package:magentoegypt/common/events.dart';
import 'package:magentoegypt/screens/users/login_screen.dart';
import 'package:provider/provider.dart';

import '../../common/config.dart';
import '../../common/constants.dart';
import '../../common/tools.dart';
import '../../common/tools/flash.dart';
import '../../core/colors.dart';
import '../../generated/l10n.dart';
import '../../models/index.dart'
    show AppModel, CartModel, PointModel, User, UserModel;
import '../../modules/vendor_on_boarding/screen_index.dart';
import '../../routes/flux_navigate.dart';
import '../../services/service_config.dart';
import '../../services/services.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/flux_image.dart';
import '../home/privacy_term_screen.dart';
import 'otp_dialog.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({
    required this.loginFB,
    //  required this.loginApple,
    required this.loginGoogle,
  });

  final LoginSocialFunction loginFB;
  // final LoginSocialFunction loginApple;
  final LoginSocialFunction loginGoogle;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  // final _auth = firebase_auth.FirebaseAuth.instance;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
  GlobalKey<ScaffoldMessengerState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  String? firstName, lastName, emailAddress, phoneNumber, password;
  String selectedCode = '20'; // default value
  bool isPickerEnabled = true;
  bool? isVendor = false;
  bool isChecked = true;

  /// True while an OTP send request is in flight — disables the Generate OTP
  /// button and shows a spinner so it can't be double-tapped (which would fire
  /// several OTP SMS and stack dialogs).
  bool _isSendingOtp = false;

  final bool showPhoneNumberWhenRegister =
      kLoginSetting.showPhoneNumberWhenRegister;
  final bool requirePhoneNumberWhenRegister =
      kLoginSetting.requirePhoneNumberWhenRegister;

  final firstNameNode = FocusNode();
  final lastNameNode = FocusNode();
  final phoneNumberNode = FocusNode();
  final emailNode = FocusNode();
  final passwordNode = FocusNode();
  final confirmpasswordNode = FocusNode();

  void _welcomeDiaLog(User user) {
    Provider.of<CartModel>(context, listen: false).setUser(user);
    Provider.of<PointModel>(context, listen: false).getMyPoint(user.cookie);
    final model = Provider.of<UserModel>(context, listen: false);

    /// Show VendorOnBoarding.
    if (kVendorConfig.vendorRegister &&
        Provider.of<AppModel>(context, listen: false).isMultivendor &&
        user.isVender) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (ctx) => VendorOnBoarding(
            user: user,
            onFinish: () {
              model.getUser();
              var email = user.email;
              _showMessage(
                '${S.of(ctx).welcome} $email!',
                isError: false,
              );
              var routeFound = false;
              var routeNames = [RouteList.dashboard, RouteList.productDetail];
              Navigator.popUntil(ctx, (route) {
                if (routeNames.any((element) =>
                route.settings.name?.contains(element) ?? false)) {
                  routeFound = true;
                }
                return routeFound || route.isFirst;
              });

              if (!routeFound) {
                Navigator.of(ctx).pushReplacementNamed(RouteList.dashboard);
              }
            },
          ),
        ),
      );
      return;
    }

    var email = user.email;
    _showMessage(
      '${S.of(context).welcome} $email!',
      isError: false,
    );
    // Navigate to the dashboard on the ROOT navigator and clear the whole stack
    // so a single, fresh MainTabs is shown. The registration screen may be
    // pushed inside a tab's nested navigator; using the local Navigator here
    // would push a MainTabs *inside* that tab, rendering the tab bar/footer
    // twice right after account creation (later logins go through the root
    // navigator, which is why they are unaffected).
    Navigator.of(App.fluxStoreNavigatorKey.currentContext!)
        .pushNamedAndRemoveUntil(RouteList.dashboard, (route) => false);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _confirmPasswordController.dispose();
    firstNameNode.dispose();
    lastNameNode.dispose();
    emailNode.dispose();
    passwordNode.dispose();
    confirmpasswordNode.dispose();
    phoneNumberNode.dispose();
    super.dispose();
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

  Future<void> _submitRegister({
    String? firstName,
    String? lastName,
    required String phoneNumber,
    String? emailAddress,
    String? password,
    bool? isVendor,
  }) async {
    if(isPickerEnabled){
      _showMessage("Please verify mobil number first.");
    }else if (firstName == null ||
        lastName == null ||
        emailAddress == null ||
        password == null ||
        (showPhoneNumberWhenRegister &&
            requirePhoneNumberWhenRegister &&
            phoneNumber == null)) {
      _showMessage(S.of(context).pleaseInputFillAllFields);
    } else if (isChecked == false) {
      _showMessage(S.of(context).pleaseAgreeTerms);
    } else {
      if (!emailAddress.validateEmail()) {
        _showMessage(S.of(context).errorEmailFormat);
        return;
      }
      if (password.length < 8) {
        _showMessage(S.of(context).errorPasswordFormat);
        return;
      }
      if(password != _confirmPasswordController.text){
        _showMessage(S.of(context).passwordNotMatch);
        return;
      }
      int requiredClasses = 3;
      bool isValid = validatePassword(password, minClasses: requiredClasses);
      if (!isValid) {
        _showMessage("Password should contain Lower Case, Digits, Special Characters.");
        return;
      }
      await Provider.of<UserModel>(context, listen: false).createUser(
        username: emailAddress,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: "$selectedCode${(phoneNumber).trim()}",
        success: _welcomeDiaLog,
        fail: _showMessage,
        isVendor: isVendor,
      );
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


  void loginGoogle(context) async {
    await widget.loginGoogle(
        success: (user) {
          //hideLoading();

          _welcomeMessage();
        },
        fail: (message) {
          //hideLoading();

          _failMessage(message);
        },
        context: context);
  }

  @override
  Widget build(BuildContext context) {
    final appModel = Provider.of<AppModel>(context, listen: true);
    final themeConfig = appModel.themeConfig;

    return WillPopScope(
      onWillPop: _handleWillPop,
      child: ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Scaffold(
          //backgroundColor: Theme.of(context).colorScheme.background,
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios,
                color: Theme.of(context).colorScheme.secondary,
                size: 24,
              ),
              onPressed: _handleBackButton,
            ),
            backgroundColor: Colors.transparent,
            elevation: 0.0,
          ),
          body: SafeArea(
            child: GestureDetector(
              onTap: () => Tools.hideKeyboard(context),
              child: ListenableProvider.value(
                value: Provider.of<UserModel>(context),
                child: Consumer<UserModel>(
                  builder: (context, value, child) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30.0),
                      child: AutofillGroup(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildButton(S.of(context).login, 0),
                                  const SizedBox(width: 16),
                                  _buildButton(S.of(context).newAccount, 1),
                                ],
                              ),
                              const SizedBox(height: 30),
                              CustomTextField(
                                key: const Key('registerFirstNameField'),
                                autofillHints: const [AutofillHints.givenName],
                                onChanged: (value) => firstName = value,
                                textCapitalization: TextCapitalization.words,
                                nextNode: lastNameNode,
                                showCancelIcon: true,
                                decoration: InputDecoration(
                                  labelText: S.of(context).firstName,
                                  hintText: S.of(context).firstName,
                                ),
                              ),
                              const SizedBox(height: 20.0),
                              CustomTextField(
                                key: const Key('registerLastNameField'),
                                autofillHints: const [AutofillHints.familyName],
                                focusNode: lastNameNode,
                                nextNode: showPhoneNumberWhenRegister
                                    ? phoneNumberNode
                                    : emailNode,
                                showCancelIcon: true,
                                textCapitalization: TextCapitalization.words,
                                onChanged: (value) => lastName = value,
                                decoration: InputDecoration(
                                  labelText: S.of(context).lastName,
                                  hintText: S.of(context).lastName,
                                ),
                              ),
                              if (showPhoneNumberWhenRegister)
                                const SizedBox(height: 20.0),
                              if (showPhoneNumberWhenRegister)
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: IgnorePointer(
                                      ignoring: !isPickerEnabled, // true = disable
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
                                            child:  CustomTextField(
                                              key: const Key('registerPhoneField'),
                                              focusNode: phoneNumberNode,
                                              autofillHints: const [
                                                AutofillHints.telephoneNumber
                                              ],
                                              nextNode: emailNode,
                                              showCancelIcon: true,
                                              onChanged: (value) => phoneNumber = value,
                                              decoration: InputDecoration(
                                                labelText: S.of(context).phoneNumber,
                                                hintText:
                                                S.of(context).enterYourPhoneNumber,
                                              ),
                                              keyboardType: TextInputType.phone,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                                LengthLimitingTextInputFormatter(
                                                    10),
                                              ],
                                            ),
                                          )
                                        ],
                                      )
                                  ),
                                ),
                              const SizedBox(height: 5.0),
                              if (isPickerEnabled) ...[
                                Align(
                                  alignment: Alignment.topRight,
                                  child: Wrap(
                                    children: [
                                      Material(
                                        color: Theme.of(context).primaryColor,
                                        borderRadius: const BorderRadius.all(Radius.circular(12.0)),
                                        elevation: 0,
                                        child: MaterialButton(
                                          onPressed: (!isPickerEnabled || _isSendingOtp) ? null:() async {
                                            final phone = (phoneNumber ?? "").trim();
                                            if(phone.isEmpty){
                                              _showMessage(S.of(context).enterMobile);
                                            }else if(phone.startsWith("0")){
                                              _showMessage(S.of(context).validMobileWithout0);
                                            }else if(phone.length != 10){
                                              _showMessage(S.of(context).validMobile);
                                            }else{
                                              // Disable + show spinner so a second tap can't fire another send.
                                              setState(() => _isSendingOtp = true);
                                              final fullPhone = "$selectedCode$phone";
                                              final currentOtp = OtpDialog.generateOtp();
                                              try {
                                                // One phone ↔ one account: bail out before sending an OTP if
                                                // this number is already tied to an account, and tell the user
                                                // to sign in. The backend rule (MagentoEgypt_CustomerPhoneUnique)
                                                // is still the authoritative guard; this is just a friendlier,
                                                // earlier check so the user isn't asked to fill out a form the
                                                // server will reject.
                                                if (await Services().api.isPhoneRegistered(fullPhone)) {
                                                  if (mounted) {
                                                    _showMessage(S.of(context).phoneAlreadyRegistered);
                                                  }
                                                  return;
                                                }
                                                final json = await Services().api.mobileSendOtp(fullPhone, currentOtp);
                                                if (!mounted) return;
                                                final message = json?['error']?['message'] ?? '';
                                                if(message.isEmpty){
                                                  OtpDialog.showOtpDialog(context, fullPhone, currentOtp,((otpCode,actionFrom) async {
                                                    if(actionFrom == "resend"){
                                                      Services().api.mobileSendOtp(fullPhone, currentOtp);
                                                    }else{
                                                      if(actionFrom == "verify"){
                                                        setState(() {
                                                          isPickerEnabled = false;
                                                          emailNode.requestFocus();
                                                        });
                                                      }
                                                    }
                                                  }));
                                                }else{
                                                  _showMessage(json?["message"]);
                                                }
                                              } catch (_) {
                                                if (mounted) _showMessage(S.of(context).somethingWrong);
                                              } finally {
                                                if (mounted) setState(() => _isSendingOtp = false);
                                              }
                                            }
                                          },
                                          elevation: 0.0,
                                          highlightElevation: 0.0,
                                          height: 44.0,
                                          minWidth: 150.0,
                                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12.0),
                                          ),
                                          child: _isSendingOtp
                                              ? SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor: AlwaysStoppedAnimation<Color>(
                                                      AppColors.textColor(context),
                                                    ),
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    SvgPicture.asset(
                                                      'assets/icons/brands/whatsapp.svg',
                                                      height: 18,
                                                      width: 18,
                                                      colorFilter: const ColorFilter.mode(
                                                        Color(0xFF25D366),
                                                        BlendMode.srcIn,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      S.of(context).generateOtp,
                                                      style: TextStyle(
                                                        color: AppColors.textColor(context),
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20.0),
                              ],
                              CustomTextField(
                                key: const Key('registerEmailField'),
                                focusNode: emailNode,
                                autofillHints: const [AutofillHints.email],
                                nextNode: passwordNode,
                                controller: _emailController,
                                onChanged: (value) => emailAddress = value,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                    labelText: S.of(context).username),
                                hintText: S.of(context).enterYourEmail,
                              ),
                              const SizedBox(height: 20.0),
                              CustomTextField(
                                key: const Key('registerPasswordField'),
                                focusNode: passwordNode,
                                nextNode: confirmpasswordNode,
                                autofillHints: const [AutofillHints.password],
                                showEyeIcon: true,
                                obscureText: true,
                                onChanged: (value) => password = value,
                                decoration: InputDecoration(
                                  labelText: S.of(context).enterYourPassword,
                                  hintText: S.of(context).enterYourPassword,
                                ),
                              ),
                              const SizedBox(height: 20.0),
                              CustomTextField(
                                key: const Key('registerConfirmPasswordField'),
                                focusNode: confirmpasswordNode,
                                autofillHints: const [AutofillHints.password],
                                showEyeIcon: true,
                                obscureText: true,
                                controller: _confirmPasswordController,
                                decoration: InputDecoration(
                                  labelText: S.of(context).enterYourConfirmPassword,
                                  hintText: S.of(context).enterYourConfirmPassword,
                                ),
                              ),
                              const SizedBox(height: 20.0),
                              if (kVendorConfig.vendorRegister &&
                                  (appModel.isMultivendor ||
                                      ServerConfig().isListeoType))
                                Row(
                                  children: <Widget>[
                                    Checkbox(
                                      value: isVendor,
                                      activeColor:
                                      Theme.of(context).primaryColor,
                                      checkColor: AppColors.textColor(context),
                                      onChanged: (value) {
                                        setState(() {
                                          isVendor = value;
                                        });
                                      },
                                    ),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          isVendor = !isVendor!;
                                          setState(() {});
                                        },
                                        child: Text(
                                          S.of(context).registerAsVendor,
                                          maxLines: 2,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              RichText(
                                maxLines: 2,
                                text: TextSpan(
                                  text: S.current.bySignup,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                  children: <TextSpan>[
                                    TextSpan(
                                      text: S.of(context).agreeWithPrivacy,
                                      style: TextStyle(
                                          color: Theme.of(context).primaryColor,
                                          decoration: TextDecoration.underline),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () => FluxNavigate.push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                            const PrivacyTermScreen(
                                              showAgreeButton: false,
                                            ),
                                          ),
                                          forceRootNavigator: true,
                                        ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10.0),
                              Padding(
                                padding:
                                const EdgeInsets.symmetric(vertical: 16.0),
                                child: Material(
                                  color: Theme.of(context).primaryColor,
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(5.0)),
                                  elevation: 0,
                                  child: MaterialButton(
                                    key: const Key('registerSubmitButton'),
                                    onPressed: value.loading == true
                                        ? null
                                        : () async {
                                      await _submitRegister(
                                        firstName: firstName,
                                        lastName: lastName,
                                        phoneNumber: phoneNumber ?? "",
                                        emailAddress: emailAddress,
                                        password: password,
                                        isVendor: isVendor,
                                      );
                                    },
                                    minWidth: 200.0,
                                    elevation: 0.0,
                                    height: 42.0,
                                    child: Text(
                                      value.loading == true
                                          ? S.of(context).loading
                                          : S.of(context).createAnAccount,
                                      style:  TextStyle(
                                          color: AppColors.textColor(context),
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30.0),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ));
  }

  /// Register can be the root route — it is opened from the welcome/onboarding
  /// screen via pushReplacement, which removes the welcome screen from the
  /// stack. An unconditional pop then empties the navigator and shows a blank
  /// white screen. So when there is nothing to pop, go to the dashboard
  /// instead, mirroring the login screen's back button.
  ///
  /// [_handleWillPop] covers the system/gesture back; [_handleBackButton]
  /// covers the AppBar back arrow.
  Future<bool> _handleWillPop() async {
    if (ModalRoute.of(context)?.canPop ?? false) {
      return true;
    }
    Navigator.of(App.fluxStoreNavigatorKey.currentContext!)
        .pushReplacementNamed(RouteList.dashboard);
    return false;
  }

  void _handleBackButton() {
    if (ModalRoute.of(context)?.canPop ?? false) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(App.fluxStoreNavigatorKey.currentContext!)
          .pushReplacementNamed(RouteList.dashboard);
    }
  }

  Widget _buildButton(String title, int index) {
    final bool isSelected = 1 == index;

    return TextButton(
      onPressed: () {
        if(index == 0){
          // Show the Login screen. Register may have been opened from Home
          // (not from Login), so popping would wrongly land on Home. Replace
          // the current (Register) route with Login instead.
          Navigator.of(context).pushReplacementNamed(RouteList.login);
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
  bool validatePassword(String password, {int minClasses = 3}) {
    bool hasLower = password.contains(RegExp(r'[a-z]'));
   // bool hasUpper = password.contains(RegExp(r'[A-Z]'));
    bool hasDigit = password.contains(RegExp(r'\d'));
    bool hasSpecial = password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=~`\\/\[\];]'));

    int classCount = [
      hasLower,
     // hasUpper,
      hasDigit,
      hasSpecial,
    ].where((element) => element).length;

    return classCount >= minClasses;
  }
}

