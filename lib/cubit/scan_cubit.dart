import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'package:meta/meta.dart';
import 'package:permission_handler/permission_handler.dart';

part 'scan_state.dart';

/// BLE 검색, 연결, 종료
class ScanCubit extends Cubit<ScanState> {
  final BleManager _bleManager;
  ScanCubit(this._bleManager) : super(BleInitial());

  /// 퍼미션이 허락되었는지?
  bool _isPermissionGranted = false;

  /// BLE Power ON / OFF
  bool _isPowerOn = false;

  /// 스캔이 가능한지 여부
  bool _canScanning = false;

  /// 스캔 중인지 여부
  bool _isScanning = false;

  /// 검색 결과 목록
  List<ScanResult> _scanResults = [];
  List<ScanResult> get scanResults => _scanResults;

  /// 연결 목록
  List<Peripheral> _connectList = [];
  List<Peripheral> get peripherals => _connectList;

  /// 검색 스트림
  StreamSubscription<ScanResult> _scanSubscription;

  /// 초기화
  /// ble 초기화
  /// - 퍼미션 상태에 따른 처리
  /// - BLE 파워 상태에 따른 처리
  /// - 예외 처리
  void init() {
    _scanResults.clear();
    _connectList.clear();

    _bleManager
        .createClient(
            restoreStateIdentifier: 'cubit-ble-2',
            restoreStateAction: (peripherals) {
              peripherals?.forEach((peripheral) {
                print('Restored peripheral: ${peripheral.name}');
              });
            })
        .catchError((e) => print(e.message))
        .then((_) => _checkPermission())
        .catchError((e) => print(e.message))
        .then((_) => _waitForBluetoothPoweredOn());

    // 블루투스 상태 체크
    _bleManager.observeBluetoothState().listen((event) {
      if (event == BluetoothState.POWERED_OFF ||
          event == BluetoothState.POWERED_ON) {
        _isPowerOn = event == BluetoothState.POWERED_ON;
        // 상태 전달
        _updateBleStatus();
      }
    });
  }

  /// 검색 시작
  /// - 검색 중이라면 통과
  /// - 검색 상태로 변경되었음을 알림
  void startScan() {
    if (_isPermissionGranted && _isPowerOn) {
      // 이미 진행중이라면...
      if (_isScanning) return;

      _isScanning = true;
      _updateBleStatus();

      // 기존 디바이스 제거, 목록 업데이트 알림
      _scanResults.clear();
      emit(DeviceListStatus());

      // 스트림 리스너 생성
      _scanSubscription =
          _bleManager.startPeripheralScan().listen((ScanResult scanResult) {
        int idx = _scanResults.indexWhere(
            (d) => d.peripheral.identifier == scanResult.peripheral.identifier);
        if (idx >= 0) {
          _scanResults[idx] = scanResult;
        } else {
          _scanResults.add(scanResult);
        }
        print(scanResult.toString());
        emit(DeviceListStatus());
      });
    } else {
      throw Exception('Can\'t start scan. Check BLE status!');
    }
  }

  /// 스캔 멈춤
  Future<void> stopScan() async {
    _isScanning = false;
    _updateBleStatus();

    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  /// 연결 - 연결할 디바이스
  Future<void> connect(String role, Peripheral peripheral) async {
    if (await peripheral.isConnected()) {
      // 이미 연결된 디바이스라면...
      _addPeripheral(role, peripheral);
      emit(ConnectionStatus(
          peripheral: peripheral, status: PeripheralConnectionState.connected));
    } else {
      try {
        // 디바이스 연결 상태 감시
        peripheral
            .observeConnectionState(
                emitCurrentValue: false, completeOnDisconnect: true)
            .listen(
          (connectionState) {
            print('connectionState: $connectionState');
            if (connectionState == PeripheralConnectionState.connected) {
              _addPeripheral(role, peripheral);
            } else if (connectionState ==
                PeripheralConnectionState.disconnected) {
              _removePeripheral(peripheral);
              emit(ScanMessageStatus(
                  'Disconnected: ${peripheral.identifier.toString()}'));
            }
            // 연결상태 업데이트
            emit(ConnectionStatus(
              peripheral: peripheral,
              status: connectionState,
            ));
          },
        );

        // 디바이스 연결 시도
        await peripheral.connect(
          requestMtu: 512,
          timeout: Duration(seconds: 5),
        );
      } catch (e) {
        print(e.message);
      }
    }
  }

  /// 연결 끊기
  Future<void> disconnect(Peripheral peripheral) async {
    await peripheral.disconnectOrCancelConnection();
  }

  /// 모든 연결 끊기
  Future<void> disconnectAll() async {
    for (int i = _connectList.length - 1; i >= 0; i--) {
      _connectList[i].disconnectOrCancelConnection();
    }
  }

  /// 안드로이드 퍼미션 관리
  Future<void> _checkPermission() async {
    print('Check permission');
    if (Platform.isAndroid) {
      await Permission.contacts.request();
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
      ].request();

      print(statuses[Permission.location]);
      _isPermissionGranted =
          statuses[Permission.location] == PermissionStatus.granted;
      _canScanning = true;
      // 상태 전달
      _updateBleStatus();
    }
  }

  /// BLE 파워 상태 변환 체크
  Future<void> _waitForBluetoothPoweredOn() async {
    Completer completer = Completer();
    StreamSubscription<BluetoothState> subscription;
    subscription = _bleManager
        .observeBluetoothState(emitCurrentValue: true)
        .listen((bluetoothState) async {
      if (bluetoothState == BluetoothState.POWERED_ON &&
          !completer.isCompleted) {
        _isPowerOn = true;
        await subscription.cancel();
        completer.complete();
        // 상태 전달
        _updateBleStatus();
      }
    });
    return completer.future;
  }

  /// 연결된 목록 추가
  void _addPeripheral(String role, Peripheral peripheral) {
    // 동일한 디바이스가 없으면 추가
    for (var v in _connectList) {
      if (v.identifier == peripheral.identifier) {
        return;
      }
    }
    _connectList.add(peripheral);
  }

  /// 끊긴 목록 삭제
  void _removePeripheral(Peripheral peripheral) {
    // 동일한 디바이스가 있으면 삭제
    for (var v in _connectList) {
      if (v.identifier == peripheral.identifier) {
        _connectList.remove(v);
        print('Remove List, length: ${_connectList.length}');
        return;
      }
    }
  }

  /// BLE 상태 업데이트 메시지 생성
  void _updateBleStatus() {
    emit(BleStatus(
      isPermissionGranted: _isPermissionGranted,
      isPowerOn: _isPowerOn,
      canScanning: _canScanning,
      isScanning: _isScanning,
    ));
  }
}
