import 'dart:async';
import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'package:meta/meta.dart';

part 'char_state.dart';

///
/// 여러개의 디바이스를 동시에 관리할 수 있는 형태로 변경
/// CharDevice 클래스에서 각 기능을 담당
///
class CharCubit extends Cubit<CharState> {
  CharCubit() : super(CharInitial());

  // 연결된 디바이스의 데이터 처리를 담당하는 인스턴스 모음
  Map<String, CharDevice> _charDevices = Map();

  // 연결 목록
  List<Peripheral> get connectedDevices =>
      _charDevices.entries.map((entry) => entry.value.peripheral).toList();

  /// 디바이스 얻어오기
  CharDevice getDevice(Peripheral peripheral) {
    if (_charDevices.containsKey(peripheral.identifier)) {
      // 기존 디바이스가 있으면 기존 디바이스 리턴
      return _charDevices[peripheral.identifier];
    } else {
      // 새로운 클래스 생성 후 리턴
      final CharDevice device = CharDevice(peripheral: peripheral, emit: emit);
      _charDevices[peripheral.identifier] = device;

      // 연결이 끊겼을 때 처리
      peripheral.observeConnectionState().listen(
        (event) {
          if (event == PeripheralConnectionState.disconnected) {
            // 열어 놓은 Notify, Indication을 닫는다.
            device.stop();
            _charDevices.remove(peripheral.identifier);
          }
        },
      );

      return device;
    }
  }
}

///
/// 디바이스의 캐릭터리스틱 관련 클래스
///
class CharDevice {
  final Peripheral peripheral;
  final Function emit;
  CharDevice({@required this.peripheral, @required this.emit});

  /// 구분자 - 어떤 뷰를 업데이트 할 것인지 구분하기 위함
  String get identifier => peripheral.identifier;
  String get name => peripheral.name == null ? identifier : peripheral.name;

  /// 서비스가 검색 되었는지 여부
  bool _isServiceDiscovered = false;
  bool get isServiceDiscovered => _isServiceDiscovered;

  // 서비스 리스트
  List<Service> _services = [];
  List<Service> get services => _services;
  // 선택된 서비스의 캐릭터리스틱 리스트
  List<Characteristic> _characteristics = [];
  List<Characteristic> get characteristics => _characteristics;
  // 선택된 캐릭터리스틱의 디스크립터 리스트
  List<Descriptor> _descriptors = [];
  List<Descriptor> get descriptors => _descriptors;

  // 선택된 서비스
  Service _selectedService;
  Service get selectedService => _selectedService;
  set selectedService(value) {
    if (value != _selectedService) {
      _selectedService = value;
      _reloadCharacteristics();
    }
  }

  // 선택된 캐릭터리스틱 인덱스
  Characteristic _selectedCharacteristic;
  Characteristic get selectedCharacteristic => _selectedCharacteristic;
  set selectedCharacteristic(value) {
    if (value != _selectedCharacteristic) {
      _selectedCharacteristic = value;
      _reloadDescriptor();
    }
  }

  // 선택된 디스크립터 인덱스
  Descriptor _selectedDescriptor;
  Descriptor get selectedDescriptor => _selectedDescriptor;
  set selectedDescriptor(value) {
    _selectedDescriptor = value;
    emit(ServiceStatus(identifier: identifier));
  }

  /// 서비스 디스커버리를 수행한다.
  Future<void> discovers() async {
    // 서비스 디스커버
    await peripheral.discoverAllServicesAndCharacteristics();
    _services = await peripheral.services(); //getting all services
    _isServiceDiscovered = true;

    // 디스커버가 완료 되었음을 알림
    emit(ServiceStatus(identifier: identifier));
  }

  /// 선택된 서비스의 캐릭터리스틱을 로드한다.
  Future<void> _reloadCharacteristics() async {
    if (_selectedService != null) {
      _characteristics = await _selectedService.characteristics();
    } else {
      _characteristics.clear();
    }
    _selectedCharacteristic = null;

    _descriptors.clear();
    _selectedDescriptor = null;

    emit(ServiceStatus(identifier: identifier));
  }

  /// 선택된 캐릭터리스틱의 디스크립터를 로드한다.
  Future<void> _reloadDescriptor() async {
    if (_selectedCharacteristic != null) {
      _descriptors = await _selectedCharacteristic.descriptors();
    } else {
      _descriptors.clear();
    }
    _selectedDescriptor = null;
    emit(ServiceStatus(identifier: identifier));
  }

  // 마지막 데이터를 저장 - 페이지 복귀시 이전과 동일한 상태 유지를 위함
  Uint8List readData;

  /// 캐릭터리스틱 읽기
  Future<void> read(Characteristic characteristic) async {
    try {
      readData = await characteristic.read();
      emit(CharacteristicStatus(identifier: identifier));
    } on BleError catch (e) {
      emit(CharMessageStatus(identifier: identifier, message: e.reason));
    }
  }

  // 마지막 데이터를 저장 - 페이지 복귀시 이전과 동일한 상태 유지를 위함
  Uint8List writeData;

  /// 캐릭터리스틱 쓰기
  Future<void> write(Characteristic characteristic, Uint8List data) async {
    try {
      await characteristic.write(data, characteristic.isWritableWithResponse);
      writeData = data;
      emit(CharacteristicStatus(identifier: identifier));
    } on BleError catch (e) {
      emit(CharMessageStatus(identifier: identifier, message: e.reason));
    }
  }

  // 노티피케이션을 활성화(monitor) 했을 때, 각 subscription을 저장하기 위한 내부 변수
  Map<Characteristic, StreamSubscription<Uint8List>> _subscriptions = Map();
  // BPS 측정용 타이머
  Map<Characteristic, Timer> _timerBPS = Map();

  /// 모니터링 중인지 여부
  bool isMonitoring(Characteristic characteristic) {
    return _subscriptions[characteristic] != null;
  }

  /// 노티피케이션 캐릭터리스틱 모니터
  /// 노티피케이션을 취소할 때 subscription이 필요하기 때문에 맵에 저장한다.
  /// BPS 측정용 타이머 또한 저장하여 취소가 가능하게 함
  void startMonitoring(Characteristic characteristic) async {
    if (!_subscriptions.containsKey(characteristic)) {
      int receivedBytes = 0;
      if (characteristic != null) {
        var subs = characteristic.monitor().listen((data) {
          emit(
            NotifyStatus(
              identifier: identifier,
              characteristic: characteristic,
              data: data,
            ),
          );
          // bps 측정용
          receivedBytes += data.length;
        });
        _subscriptions[characteristic] = subs;

        Timer timer = Timer.periodic(Duration(seconds: 5), (tick) {
          // BPS 측정용
          emit(BpsStatus(
            identifier: identifier,
            bps: receivedBytes * 8 / 5.0,
          ));
          receivedBytes = 0;
        });
        _timerBPS[characteristic] = timer;
      }
    }
  }

  /// 모니터링 중지
  void stopMonitoring(Characteristic characteristic) async {
    if (_subscriptions[characteristic] != null) {
      await _subscriptions[characteristic].cancel();
      _subscriptions.remove(characteristic);
    }

    if (_timerBPS[characteristic] != null) {
      _timerBPS[characteristic].cancel();
      _timerBPS.remove(characteristic);
    }
  }

  /// 모든 모니터링 중지
  void stop() {
    for (var v in _subscriptions.values) {
      v.cancel();
    }
    _subscriptions.clear();
    for (var v in _timerBPS.values) {
      v.cancel();
    }
    _timerBPS.clear();
  }
}
