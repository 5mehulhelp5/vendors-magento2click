import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _keyLastInitTime = 'keyLastInitTime';
const _keyHttpClientResult = 'keyHttpClientResult';

const _storage = FlutterSecureStorage();

Future<int> getLastInitTime() async {
  final result = await _storage.read(key: _keyLastInitTime);
  return int.tryParse('$result') ?? 0;
}

Future<void> setLastInitTime(int value) async {
  await _storage.write(key: _keyLastInitTime, value: '$value');
}

Future<String> getHttpClientResult() async {
  final lastInitTime = await getLastInitTime();
  if (lastInitTime != 0) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastInitTime > 7 * 24 * 60 * 60 * 1000) {
      await setHttpClientResult('');
      await setLastInitTime(0);
      return '';
    }
  }
  final result = await _storage.read(key: _keyHttpClientResult);
  return result ?? '';
}

Future<void> setHttpClientResult(String value) async {
  await _storage.write(key: _keyHttpClientResult, value: value);
}
