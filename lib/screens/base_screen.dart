import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common/config.dart';
import '../models/app_model.dart';
import '../services/index.dart';

// This is an abstract class called BaseScreen that extends StatefulWidget.
// It defines common functionality that can be used across multiple screens in a Flutter application.
abstract class BaseScreen<T extends StatefulWidget> extends State<T> {
  // This method is called when the widget is first created.
  @override
  void initState() {
    super.initState();

    // If the app is running on the web, load the app configuration.
    if (kIsWeb) {
      // Execute the following code after the current frame is rendered.
      Future.delayed(Duration.zero, () async {
        var appModel = Provider.of<AppModel>(context, listen: false);
        if (appModel.appConfig == null) {
          // Print a message indicating that the app configuration is being initialized.
          // This is for debugging purposes only.
          print('[BaseScreen] ☪️ Init App Config ☪️ ');

          // Set the server configuration and load the app configuration.
          Services().setAppConfig(serverConfig);
          await appModel.loadAppConfig();
        }
      });
    }

    // Execute the afterFirstLayout method after the current frame is rendered.
    WidgetsBinding.instance.endOfFrame.then(
      (_) {
        if (mounted) afterFirstLayout(context);
      },
    );
  }

  // This method can be overridden in a subclass to execute code after the first layout.
  void afterFirstLayout(BuildContext context) {}

  // This getter returns the size of the screen.
  Size get screenSize => MediaQuery.of(context).size;
}
