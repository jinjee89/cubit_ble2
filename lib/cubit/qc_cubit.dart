import 'dart:async';
import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:cubit_ble2/utils/array_utils.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'package:meta/meta.dart';

part 'qc_state.dart';

///
/// 여러개의 디바이스를 동시에 관리할 수 있는 형태로 변경
/// QcDevice 클래스에서 각 기능을 담당
///
class QcCubit extends Cubit<QcState> {
  QcCubit() : super(QcInitial());

  // 연결된 디바이스의 데이터 처리를 담당하는 인스턴스 모음
  Map<String, QcDevice> _qcDevices = Map();

  // 연결 목록
  List<Peripheral> get connectedDevices =>
      _qcDevices.entries.map((entry) => entry.value.peripheral).toList();

  /// 디바이스 얻어오기
  QcDevice getDevice(Peripheral peripheral) {
    if (_qcDevices.containsKey(peripheral.identifier)) {
      // 기존 디바이스가 있으면 기존 디바이스 리턴
      return _qcDevices[peripheral.identifier];
    } else {
      // 새로운 클래스 생성 후 리턴
      final QcDevice device = QcDevice(peripheral: peripheral, emit: emit);
      _qcDevices[peripheral.identifier] = device;

      // 연결이 끊겼을 때 처리
      peripheral.observeConnectionState().listen(
        (event) {
          if (event == PeripheralConnectionState.disconnected) {
            // 열어 놓은 Notify, Indication을 닫는다.
            device.stopMonitoring();
            _qcDevices.remove(peripheral.identifier);
          }
        },
      );

      return device;
    }
  }
}

///
/// QC 관련 클래스
///
class QcDevice {
  static const int DefaultCalibrationValue = 10;
  static String roEmService = 'f3c7622a-5a97-4d98-5347-060069ef22f1';
  static String roEmRW = '443476c9-88fe-56b6-e746-20d80ac00900';
  static String roEmNotify = '443476c9-88fe-56b6-e746-20d80ac00901';

  final Peripheral peripheral;
  final Function emit;
  QcDevice({@required this.peripheral, @required this.emit});

  /// 구분자 - 어떤 뷰를 업데이트 할 것인지 구분하기 위함
  String get identifier => peripheral.identifier;

  /// 서비스가 검색 되었는지 여부
  bool _isServiceDiscovered = false;
  bool get isServiceDiscovered => _isServiceDiscovered;

  /// 로임 서비스가 존재하는지 여부
  bool _isRoEmServiceExists = false;
  bool get isRoEmServiceExists => _isRoEmServiceExists;

  /// 링크 변경시
  int _linkIndex = 1;
  int get linkIndex => _linkIndex;
  set linkIndex(value) {
    _linkIndex = value;
    _autoSendCommand
        ? sendCommand()
        : emit(CommandStatus(identifier: identifier));
  }

  /// 디바이스 장착 레벨 변경시
  int _deviceAttachLevel = 0;
  int get deviceAttachLevel => _deviceAttachLevel;
  set deviceAttachLevel(value) {
    _deviceAttachLevel = value;
    _autoSendCommand
        ? sendCommand()
        : emit(CommandStatus(identifier: identifier));
  }

  /// 파워 변경시
  int _powerLevel = 0;
  int get powerLevel => _powerLevel;
  set powerLevel(value) {
    _powerLevel = value;
    _autoSendCommand
        ? sendCommand()
        : emit(CommandStatus(identifier: identifier));
  }

  /// 터치 캘리브레이션 값 변경 시
  int _touchCalibration = DefaultCalibrationValue;
  int get touchCalibration => _touchCalibration;
  set touchCalibration(value) {
    _touchCalibration = value;
    _autoSendCommand
        ? sendCommand()
        : emit(CommandStatus(identifier: identifier));
  }

  /// 저장 상태 변경시
  bool _recordState = false;
  bool get recordState => _recordState;
  set recordState(value) {
    _recordState = value;
    _autoSendCommand
        ? sendCommand()
        : emit(CommandStatus(identifier: identifier));
  }

  /// 리셋 변경시
  bool _brownReset = false;
  bool get brownReset => _brownReset;
  set brownReset(value) {
    _brownReset = value;
    _autoSendCommand
        ? sendCommand()
        : emit(CommandStatus(identifier: identifier));
  }

  /// 디버그 출력 변경시
  bool _debugPrint = false;
  bool get debugPrint => _debugPrint;
  set debugPrint(value) {
    _debugPrint = value;
    _autoSendCommand
        ? sendCommand()
        : emit(CommandStatus(identifier: identifier));
  }

  /// 자동 메시지 전송 변경시
  bool _autoSendCommand = true;
  bool get autoSendCommand => _autoSendCommand;
  set autoSendCommand(value) {
    _autoSendCommand = value;
    emit(CommandStatus(identifier: identifier));
  }

  /// 커맨드 전송 카운트
  int _commandCount = 0;
  int get commandCount => _commandCount;

  // 노티피케이션을 활성화(monitor) 했을 때, 각 subscription을 저장하기 위한 내부 변수
  StreamSubscription<Uint8List> _qcSubscription;

  Characteristic _commandChar; // RoEm RW
  Characteristic _qcChar; // RoEm Notify

  /// 서비스 디스커버리를 수행한다.
  Future<void> discovers() async {
    // 서비스 디스커버
    if (!_isServiceDiscovered) {
      await peripheral.discoverAllServicesAndCharacteristics();
      var _services = await peripheral.services(); //getting all services
      _isServiceDiscovered = true;

      // RoEmServic가 존재하는지 확인한다.
      for (int i = 0; i < _services.length; i++) {
        if (_services[i].uuid.toString() == roEmService) {
          var chars = await _services[i].characteristics();
          _commandChar = chars[0];
          _qcChar = chars[1];
          _isRoEmServiceExists = true;
        }
      }

      // 연결 명령 전송
      await sendCommand();

      // 디스커버링 상태 업데이트
      emit(QcDiscoverStatus(identifier: identifier));
    }
  }

  /// 제어 명령 전송
  Future<void> sendCommand() async {
    Uint8List data = Uint8List(20);
    data[0] = 0xD0;
    data[1] = _linkIndex;
    data[2] = _deviceAttachLevel;
    data[3] = _powerLevel;
    data[4] = 0;
    data[5] = (_recordState ? 1 : 0);
    data[6] = 0;
    data[7] = _touchCalibration;
    data[8] = (_brownReset ? 0xEF : 0x00);
    data[9] = (_debugPrint ? 0xE1 : 0xE0);

    _commandChar.write(data, true).catchError(
      (e) {
        print(e.message);
      },
    );
    _commandCount++;

    print('emit CommandStatus');
    emit(CommandStatus(identifier: identifier));
  }

  Uint8List _lastQcData;

  /// 모니터링 시작
  Future<void> startMonitoring() async {
    if (_qcChar != null && _qcSubscription == null) {
      print('Start QC Monitoring');
      _qcSubscription = _qcChar.monitor().listen(
        (data) {
          if (data != null && data.length > 20 && data[4] == 0xFC) {
            _lastQcData = data;
            emit(QcStatus(identifier: identifier, data: data));
            print('QcStatus');
          }
        },
      );
    }

    // 다른 화면에 갔다 왔을 때 빠른 UI 갱신을 위해서
    if (_lastQcData == null) {
      Uint8List empty = Uint8List(80);
      emit(QcStatus(identifier: identifier, data: empty));
    } else {
      emit(QcStatus(identifier: identifier, data: _lastQcData));
    }
  }

  /// 모니터링 멈춤
  void stopMonitoring() {
    if (_qcSubscription != null) {
      _qcSubscription.cancel();
      _qcSubscription = null;
    }
  }
}
