import 'dart:typed_data';

import 'package:cubit_ble2/utils/array_utils.dart';
import 'package:flutter/foundation.dart';

class OtaDeviceHeader extends ArrayUtils {
  final Uint8List data;
  OtaDeviceHeader({@required this.data});

  String get imageIdentifier => data != null
      ? get16(data, 1).toRadixString(16).padLeft(4, '0').toUpperCase()
      : '';
  String get buildVersion => data != null
      ? get24(data, 3).toRadixString(16).padLeft(6, '0').toUpperCase()
      : '';
  String get stackVersion => data != null
      ? get8(data, 6).toRadixString(16).padLeft(2, '0').toUpperCase()
      : '';
  String get hardwareVersion => data != null
      ? get24(data, 7).toRadixString(16).padLeft(6, '0').toUpperCase()
      : '';
  String get manufacturerIdentifier => data != null
      ? get8(data, 10).toRadixString(16).padLeft(2, '0').toUpperCase()
      : '';
}
