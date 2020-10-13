import 'package:cubit_ble2/cubit/char_cubit.dart';
import 'package:cubit_ble2/cubit/ota_cubit.dart';
import 'package:cubit_ble2/cubit/qc_cubit.dart';
import 'package:cubit_ble2/cubit/scan_cubit.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';

class CubitGlobal {
  static final BleManager bleManager = BleManager();
  static final ScanCubit scanCubit = ScanCubit(bleManager);
  static final CharCubit charCubit = CharCubit();
  static final QcCubit qcCubit = QcCubit();
  static final OtaCubit otaCubit = OtaCubit();
}
