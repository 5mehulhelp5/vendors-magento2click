import 'package:firebase_auth/firebase_auth.dart' as firebase;

import '../../../../../models/entities/user.dart';

class UserAuthAdaptiveFirebase extends User {
  final firebase.User userFirebase;

  UserAuthAdaptiveFirebase(this.userFirebase)
      : super.init(
          id: userFirebase.uid,
          email: userFirebase.email,
          nicename: userFirebase.displayName,
          userUrl: userFirebase.photoURL,
          phoneNumber: userFirebase.phoneNumber,
          picture: userFirebase.photoURL,
        );

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async {
    //return userFirebase.getIdToken(forceRefresh);
    final token = await userFirebase.getIdToken(forceRefresh);
    return token ??
        ''; // Replace null value with an empty string or handle it differently based on your use case.
  }
}
