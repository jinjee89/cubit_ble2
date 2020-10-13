import 'dart:io';
import 'dart:typed_data';

import 'package:cubit_ble2/cubit/ota/ota_file_header.dart';

class OtaFile {
  final String otaFilePath;
  Uint8List data;
  int sendLength = 0;

  /// 생성자
  /// otaFilePath - OTA 파일 경로
  OtaFile(this.otaFilePath);

  // 내부 변수
  OtaFileHeader _otaHeader;

  // GET
  OtaFileHeader get otaHeader => _otaHeader;

  Future<void> init() async {
    File file = File(otaFilePath);
    if (await file.length() < 58) {
      throw Exception('This is not an OTA file.');
    }
    data = await file.readAsBytes();
    _otaHeader = OtaFileHeader(data: data);
  }
}
