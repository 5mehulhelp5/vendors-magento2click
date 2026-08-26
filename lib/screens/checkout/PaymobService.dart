import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class PaymobService {
  static const String _baseUrl = 'https://accept.paymob.com/api';
  String? _authToken;

  final String apiKey = "ZXlKaGJHY2lPaUpJVXpVeE1pSXNJblI1Y0NJNklrcFhWQ0o5LmV5SmpiR0Z6Y3lJNklrMWxjbU5vWVc1MElpd2ljSEp2Wm1sc1pWOXdheUk2TVRBMU9ETTRNeXdpYm1GdFpTSTZJbWx1YVhScFlXd2lmUS5DYmdSVU9MVXVnWHJJaTljaEFHZ1plUGxEUHFjZmUtZmU4WWJKUmc3UllTUTVFRGRWNEw4SGVKcmVBdndYbHM5RnlMRUIzdWtIMGpjRks3aDVReHh1QQ==";

  PaymobService();

  // Step 1: Authentication
  Future<String?> _authenticate() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/tokens'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'api_key': apiKey}),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        _authToken = data['token'];
        return _authToken;
      } else {
        throw Exception('Authentication failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Authentication error: $e');
    }
  }

  // Step 2: Order Registration
  Future<String> _registerOrder({
    required int amountCents,
    required String currency,
    Map<String, dynamic>? billingData,
  }) async {
    if (_authToken == null) {
      await _authenticate();
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/ecommerce/orders'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_authToken'
      },
      body: json.encode({
        'auth_token': _authToken,
        'delivery_needed': 'false',
        'amount_cents': amountCents.toString(),
        'currency': currency,
        'items': [],
        'shipping_data': billingData ?? {},
        'billing_data': billingData ?? {},
      }),
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      return data['id'].toString();
    } else {
      throw Exception('Order registration failed: ${response.statusCode}');
    }
  }

  // Step 3: Payment Key Request
  Future<String> _getPaymentKey({
    required int amountCents,
    required String currency,
    required String orderId,
    required int integrationId,
    Map<String, dynamic>? billingData,
  }) async {
    if (_authToken == null) {
      await _authenticate();
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/acceptance/payment_keys'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_authToken'
      },
      body: json.encode({
        'auth_token': _authToken,
        'amount_cents': amountCents.toString(),
        'expiration': 3600,
        'order_id': orderId,
        'billing_data': billingData ?? {
          "apartment": "NA",
          "email": "customer@example.com",
          "floor": "NA",
          "first_name": "Customer",
          "street": "NA",
          "building": "NA",
          "phone_number": "+201234567890",
          "shipping_method": "NA",
          "postal_code": "NA",
          "city": "Cairo",
          "country": "Egypt",
          "last_name": "Test",
          "state": "NA"
        },
        'currency': currency,
        'integration_id': integrationId,
        'lock_order_when_paid': "false"
      }),
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      return data['token'];
    } else {
      throw Exception('Payment key request failed: ${response.statusCode}');
    }
  }

  // Main payment method
  Future<Map<String, dynamic>> initiatePayment({
    required double amount,
    required String currency,
    required String paymentMethod,
    Map<String, dynamic>? billingData,
  }) async {
    try {
      // Convert amount to cents
      final amountCents = (amount * 100).toInt();

      // Get integration ID based on payment method
      final integrationId = _getIntegrationId(paymentMethod);

      // Register order
      final orderId = await _registerOrder(
        amountCents: amountCents,
        currency: currency,
        billingData: billingData,
      );

      // Get payment key
      final paymentKey = await _getPaymentKey(
        amountCents: amountCents,
        currency: currency,
        orderId: orderId,
        integrationId: integrationId,
        billingData: billingData,
      );

      return {
        'success': true,
        'paymentKey': paymentKey,
        'orderId': orderId,
        'integrationId': integrationId,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  int _getIntegrationId(String paymentMethod) {
    return 5177220; //sandbox
    switch (paymentMethod.toLowerCase()) {
      case 'online':
        return 5245496; // Replace with your Valu integration ID
      case 'sympl':
        return 5364612; // Replace with your card integration ID
      case 'aman':
        return 5364611; // Replace with your Sohoula integration ID
      default:
        throw Exception('Unsupported payment method: $paymentMethod');
    }
  }
}

//https://chatgpt.com/c/69140dfd-c484-8321-b2db-2a4ba87f0d67
//https://chat.deepseek.com/a/chat/s/67eab638-2aad-4885-89db-df2621ac3406
//https://accept.paymob.com/portal2/en/login