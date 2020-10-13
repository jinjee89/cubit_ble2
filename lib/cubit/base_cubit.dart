import 'dart:typed_data';

import 'package:cubit_ble2/cubit/qc_cubit.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';

class BaseCubit {
  ///
  /// FITSIG의 경우 링크 명령을 보내지 않으면 일정시간 후에 파워 오프하기 때문에
  /// 연결을 유지하기 위해서 링크 명령을 보낸다.
  ///
  Future<void> linkCommand(Characteristic characteristic) async {
    Uint8List data = Uint8List(20);
    data[0] = 0xD0;
    data[1] = 1;
    data[2] = 0;
    data[3] = 0;
    data[4] = 0;
    data[5] = 0;
    data[6] = 0;
    data[7] = QcDevice.DefaultCalibrationValue; // 캘리브레이션 디폴트 값
    data[8] = 0;
    data[9] = 0xE0;

    characteristic.write(data, true).catchError(
      (e) {
        print(e.message);
      },
    );
  }
}
