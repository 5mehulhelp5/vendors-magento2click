import 'dart:convert';

import 'package:flutter/material.dart';
import 'widgets/animated_spinner.dart';

import '../common/tools.dart';
import '../modules/dynamic_layout/index.dart';
import '../services/services.dart';
import 'config/configuration_utils.dart';
import 'config/models/address_field_config.dart';
import 'config/models/index.dart';
import 'config/models/vendor_config.dart';

part 'config/advertise.dart';
part 'config/configurations.dart';
part 'config/data_mapping.dart';
part 'config/default_env.dart';
part 'config/general.dart';
part 'config/languages.dart';
part 'config/loading.dart';
part 'config/onboarding.dart';
part 'config/payments.dart';
part 'config/products.dart';
part 'config/smartchat.dart';
part 'config/vendor.dart';

Map get serverConfig => Configurations.serverConfig;
