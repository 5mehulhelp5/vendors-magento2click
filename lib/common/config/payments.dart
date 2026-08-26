part of '../config.dart';

PaymentConfig get kPaymentConfig =>
    PaymentConfig.fromJson(Configurations.paymentConfig);

Map get kPayments => Configurations.payments;

Map get kStripeConfig => Configurations.stripeConfig;

Map get kPaypalConfig => Configurations.paypalConfig;

Map get kRazorpayConfig => Configurations.razorpayConfig;

Map get kPayTmConfig => Configurations.payTmConfig;

Map get kPayStackConfig => Configurations.payStackConfig;

Map get kFlutterwaveConfig => Configurations.flutterwaveConfig;

Map get afterShip => Configurations.afterShip;

bool get kEnableCustomerNote => kPaymentConfig.enableCustomerNote;

//const List DefaultCountry = [
//  {
//    "name": "Vietnam",
//    "iosCode": "VN",
//    "icon": "https://cdn.britannica.com/41/4041-004-A06CBD63/Flag-Vietnam.jpg"
//  },
//  {
//    "name": "India",
//    "iosCode": "IN",
//    "icon":
//        "https://upload.wikimedia.org/wikipedia/en/thumb/4/41/Flag_of_India.svg/1200px-Flag_of_India.svg.png"
//  },
//  {"name": "Austria", "iosCode": "AT", "icon": ""},
//];
