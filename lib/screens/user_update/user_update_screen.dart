import 'package:country_code_picker/country_code_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:magentoegypt/ajstoreui/core/app_export.dart';
import 'package:inspireui/inspireui.dart';
import 'package:provider/provider.dart';
import '../../common/config.dart';
import '../../common/tools/flash.dart';
import '../../generated/l10n.dart';
import '../../models/user_model.dart';
import '../../services/index.dart';
import '../../widgets/common/common_safe_area.dart';
import '../../widgets/common/loading_body.dart';
import '../base_screen.dart';
import '../users/otp_dialog.dart';

class UserUpdateScreen extends StatefulWidget {
  const UserUpdateScreen({super.key});

  @override
  BaseScreen<UserUpdateScreen> createState() => _StateUserUpdate();
}

class _StateUserUpdate extends BaseScreen<UserUpdateScreen> {
  TextEditingController? userEmail;
  TextEditingController? userPassword;
  TextEditingController? userDisplayName;
  TextEditingController? userPhone;
  late TextEditingController userNiceName;
  late TextEditingController userUrl;
  TextEditingController? currentPassword;

  TextEditingController? userFirstname;
  TextEditingController? userLastname;
  CountryCode? countryCode;
  String? avatar;
  bool isLoading = false;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  bool isValidPassword() => userPassword!.text.length >= 8;

  bool get hasChangePassword => isValidPassword();

  @override
  void afterFirstLayout(BuildContext context) {
    final user = Provider.of<UserModel>(context, listen: false).user;
    setState(() {
      if (LoginSMSConstants.dialCodeDefault.isNotEmpty ||
          LoginSMSConstants.countryCodeDefault.isNotEmpty ||
          LoginSMSConstants.nameDefault.isNotEmpty) {
        countryCode = CountryCode(
          code: LoginSMSConstants.countryCodeDefault.isNotEmpty
              ? LoginSMSConstants.countryCodeDefault
              : null,
          dialCode: LoginSMSConstants.dialCodeDefault.isNotEmpty
              ? LoginSMSConstants.dialCodeDefault
              : null,
          name: LoginSMSConstants.nameDefault.isNotEmpty
              ? LoginSMSConstants.nameDefault
              : null,
        );
      }
      if ((user?.phoneNumber ?? '').isNotEmpty) {
        final dialCode = countryCode?.dialCode ??
            (LoginSMSConstants.dialCodeDefault.isNotEmpty
                ? LoginSMSConstants.dialCodeDefault
                : '+20');
        final dialDigits = dialCode.replaceAll('+', '');
        var localNumber = (user?.phoneNumber ?? '').trim().replaceFirst('+', '');
        if (dialDigits.isNotEmpty && localNumber.startsWith(dialDigits)) {
          localNumber = localNumber.substring(dialDigits.length);
        }
        userPhone = TextEditingController(text: localNumber);
        countryCode = CountryCode.fromDialCode(dialCode);
      }else{
        userPhone = TextEditingController(text: '');
      }
      userEmail = TextEditingController(text: user!.email);
      userPassword = TextEditingController(text: '');
      currentPassword = TextEditingController(text: '');
      userDisplayName = TextEditingController(text: user.name);
      userNiceName = TextEditingController(text: user.nicename);
      userFirstname = TextEditingController(text: user.firstName);
      userLastname = TextEditingController(text: user.lastName);
      userUrl = TextEditingController(text: user.userUrl);
      avatar = user.picture;
    });
  }

  Future<void> updateUserInfo() async {
    if (userPassword!.text.isNotEmpty && !isValidPassword()) {
      FlashHelper.errorMessage(
        context,
        message: S.of(context).errorPasswordFormat,
      );
      return;
    }else if (!userEmail!.text.toString().validateEmail()) {
      FlashHelper.errorMessage(
        context,
        message: S.of(context).errorEmailFormat,
      );
      return;
    }

    final user = Provider.of<UserModel>(context, listen: false).user;
    String fullphoneNumber = (countryCode?.dialCode ?? "") + (userPhone?.text ?? "");
    String phoneNumber = userPhone?.text ?? "";
    fullphoneNumber = fullphoneNumber.replaceAll("+", "");

    if(fullphoneNumber != user?.phoneNumber){
      if(phoneNumber.trim().isEmpty){
        _scaffoldMessengerKey.currentState
            ?.showSnackBar(SnackBar(content: Text(S.of(context).enterMobile)));
      }else if(phoneNumber.trim().startsWith("0")){
        _scaffoldMessengerKey.currentState
            ?.showSnackBar(SnackBar(content: Text(S.of(context).validMobileWithout0)));
      }else if(phoneNumber.trim().length != 10){
        _scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(S.of(context).validMobile)));
      }else{
        if (currentPassword!.text.isEmpty && !user!.isSocial!) {
          _scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(S.of(context!).currentPasswordrequired)));
          return;
        }
        setState(() {
          isLoading = true;
        });
        String currentOtp = OtpDialog.generateOtp();
        final json = await Services().api.mobileSendOtp(fullphoneNumber.trim(),currentOtp);
        setState(() {
          isLoading = false;
        });
        final message = json?['error']?['message'] ?? '';
        if(message.isEmpty){
          OtpDialog.showOtpDialog(context, fullphoneNumber.trim(),currentOtp,((otpCode,actionFrom) async {
            if(actionFrom == "resend"){
              Services().api.mobileSendOtp(fullphoneNumber.trim(),currentOtp);
            }else{
              setState(() {
                isLoading = true;
              });
              if(actionFrom == "verify"){
                Services().widget.updateUserInfo(
                  loggedInUser: user,
                  onError: (e) {
                    _scaffoldMessengerKey.currentState
                        ?.showSnackBar(SnackBar(content: Text(e)));
                    setState(() {
                      isLoading = false;
                    });
                  },
                  onSuccess: (user) {
                    user?.phoneNumber = fullphoneNumber;
                    Provider.of<UserModel>(context, listen: false).updateUser(user);
                    setState(() {
                      isLoading = false;
                    });

                    /// If update password, need to pop true to force user log-out and
                    /// login again to make effect
                    Navigator.of(context).pop(hasChangePassword);
                  },
                  currentPassword: currentPassword!.text,
                  userDisplayName: userDisplayName!.text,
                  userEmail: userEmail!.text,
                  phoneNumber: fullphoneNumber,
                  userNiceName: userNiceName.text,
                  userUrl: userUrl.text,
                  userPassword: userPassword!.text,
                  userFirstname: userFirstname?.text,
                  userLastname: userLastname?.text,
                );
              }else{
                setState(() {
                  isLoading = false;
                });
              }
            }
          }));
        }else{
          _scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
        }
      }
    }else{
      if (currentPassword!.text.isEmpty && !user!.isSocial!) {
        _scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(S.of(context!).currentPasswordrequired)));
        return;
      }
      setState(() {
        isLoading = true;
      });
      Services().widget.updateUserInfo(
        loggedInUser: user,
        onError: (e) {
          _scaffoldMessengerKey.currentState
              ?.showSnackBar(SnackBar(content: Text(e)));
          setState(() {
            isLoading = false;
          });
        },
        onSuccess: (user) {
          user?.phoneNumber = fullphoneNumber;
          Provider.of<UserModel>(context, listen: false).updateUser(user);
          setState(() {
            isLoading = false;
          });

          /// If update password, need to pop true to force user log-out and
          /// login again to make effect
          Navigator.of(context).pop(hasChangePassword);
        },
        currentPassword: currentPassword!.text,
        userDisplayName: userDisplayName!.text,
        userEmail: userEmail!.text,
        phoneNumber: fullphoneNumber,
        userNiceName: userNiceName.text,
        userUrl: userUrl.text,
        userPassword: userPassword!.text,
        userFirstname: userFirstname?.text,
        userLastname: userLastname?.text,
      );
    }

  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel>(context).user!;

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).colorScheme.secondary,
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          backgroundColor: Colors.white,
          elevation: 2.0,
          title: Text(S.of(context).account),
        ),
        extendBodyBehindAppBar: true,
        body: AutoHideKeyboard(
          child: LoadingBody(
            isLoading: isLoading,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.25,
                  child: Stack(
                    children: <Widget>[
                      Container(
                        // height: MediaQuery.of(context).size.height * 0.20,
                        // width: MediaQuery.of(context).size.width,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.elliptical(100, 10),
                          ),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black12,
                                offset: Offset(0, 2),
                                blurRadius: 8)
                          ],
                        ),
                        child: (avatar?.isNotEmpty ?? false)
                            ? CachedNetworkImage(
                                imageUrl: avatar!,
                                httpHeaders: const {'Accept': 'image/webp'},
                                fit: BoxFit.cover,
                                memCacheWidth: 300,
                                errorWidget: (_, __, ___) => const SizedBox(),
                              )
                            : const SizedBox(),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(150),
                              color: Theme.of(context).primaryColorLight),
                          child: (avatar?.isNotEmpty ?? false)
                              ? CachedNetworkImage(
                                  imageUrl: avatar!,
                                  httpHeaders: const {'Accept': 'image/webp'},
                                  width: 150,
                                  height: 150,
                                  memCacheWidth: 300,
                                  errorWidget: (_, __, ___) => const Icon(
                                    Icons.person,
                                    size: 120,
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 120,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const SizedBox(height: 8),
                              Text(
                                S.of(context).displayName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                decoration: buildDecoration(),
                                controller: userDisplayName,
                                enabled:
                                    ServerConfig().type != ConfigType.magento,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                S.of(context).email,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color:
                                  Theme.of(context).colorScheme.secondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: userEmail,
                                enabled: !user.isSocial!,
                                decoration: buildDecoration(),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                S.of(context).phoneNumber,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color:
                                  Theme.of(context).colorScheme.secondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: <Widget>[
                                       Padding(
                                          padding: const EdgeInsets.only(top: 0.0),
                                          child: CountryCodePicker(
                                            // Initial selection and favorite can be one of code ('IT') OR dial_code('+39')
                                            onChanged: (country) {
                                              setState(() {
                                                countryCode = country;
                                              });
                                            },
                                            // Initial selection and favorite can be one of code ('IT') OR dial_code('+39')
                                            initialSelection: countryCode?.code ?? "eg",

                                            //Get the country information relevant to the initial selection
                                            onInit: (code) {
                                              countryCode = code;
                                            },
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
                                          controller: userPhone,
                                          decoration: buildDecoration(),
                                        ),
                                      )
                                    ],
                                  ),
                              ),

                              // if (!user.isSocial!)
                              // Container(
                              //   decoration: BoxDecoration(border: Border.all()),
                              //   child: Services()
                              //       .widget
                              //       .renderCurrentPassInputforEditProfile(
                              //         context: context,
                              //         currentPasswordController:
                              //             currentPassword,
                              //       ),
                              // ),
                              if (!user.isSocial!)
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      S.of(context).currentPassword,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      obscureText: true,
                                      decoration: buildDecoration(),
                                      controller: currentPassword,
                                    ),
                                  ],
                                ),
                              if (!user.isSocial!)
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      S.of(context).newPassword,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      obscureText: true,
                                      decoration: buildDecoration(),
                                      controller: userPassword,
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 50),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                buildButtonUpdate(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration buildDecoration() {
    return InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          getHorizontalSize(4.00),
        ),
        borderSide: BorderSide(
          color: ColorConstant.black90063,
          width: 1,
        ),
      ),
    );
  }

  List<Widget> buildDisplayName() {
    return [
      Text(S.of(context).displayName,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.secondary,
          )),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: Theme.of(context).primaryColorLight,
            border: Border.all(
                color: Theme.of(context).primaryColorLight, width: 1.5)),
        child: TextField(
            decoration: const InputDecoration(border: InputBorder.none),
            controller: userDisplayName,
            enabled: ServerConfig().type != ConfigType.magento),
      ),
    ];
  }

  List<Widget> buildEnterNameOfUser() {
    return [
      Text(S.of(context).firstName,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.secondary,
          )),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: Theme.of(context).primaryColorLight,
            border: Border.all(
                color: Theme.of(context).primaryColorLight, width: 1.5)),
        child: TextField(
          decoration: const InputDecoration(border: InputBorder.none),
          controller: userFirstname,
        ),
      ),
      Text(S.of(context).lastName,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.secondary,
          )),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: Theme.of(context).primaryColorLight,
            border: Border.all(
                color: Theme.of(context).primaryColorLight, width: 1.5)),
        child: TextField(
          decoration: const InputDecoration(border: InputBorder.none),
          controller: userLastname,
        ),
      )
    ];
  }

  Widget buildButtonUpdate() {
    return CommonSafeArea(
      child: ElevatedButton(
        onPressed: isLoading ? null : updateUserInfo,
        child: Text(
          S.of(context).update,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

}
