import 'dart:typed_data';

import 'package:cubit_ble2/utils/array_utils.dart';
import 'package:flutter/foundation.dart';

class OtaFileHeader extends ArrayUtils {
  final Uint8List data;
  OtaFileHeader({@required this.data});

  String get fileIdeitifier => data != null
      ? get32(data, 0).toRadixString(16).padLeft(8, '0').toUpperCase()
      : '';
  String get headerVersion => data != null
      ? get16(data, 4).toRadixString(16).padLeft(4, '0').toUpperCase()
      : '';
  String get headerLength => data != null ? get16(data, 6).toString() : '';
  String get headerFieldControl => data != null
      ? get16(data, 8).toRadixString(16).padLeft(4, '0').toUpperCase()
      : '';
  String get companyIdentifier => data != null
      ? get16(data, 10).toRadixString(16).padLeft(4, '0').toUpperCase()
      : '';
  String get imageIdentifier => data != null
      ? get16(data, 12).toRadixString(16).padLeft(4, '0').toUpperCase()
      : '';

  String get buildVersion => data != null
      ? get24(data, 14).toRadixString(16).padLeft(6, '0').toUpperCase()
      : '';
  String get stackVersion => data != null
      ? get8(data, 17).toRadixString(16).padLeft(2, '0').toUpperCase()
      : '';
  String get hardwareVersion => data != null
      ? get24(data, 18).toRadixString(16).padLeft(6, '0').toUpperCase()
      : '';
  String get manufacturerIdentifier => data != null
      ? get8(data, 21).toRadixString(16).padLeft(2, '0').toUpperCase()
      : '';
  String get headerString => data != null ? getS(data, 22, 32) : '';
  String get totalImageSize => data != null ? get32(data, 54).toString() : '';

  int get imageIdentifierValue => data != null ? get16(data, 12) : 0;
  int get imageVersion64Value => data != null ? get64(data, 14) : 0;
}
