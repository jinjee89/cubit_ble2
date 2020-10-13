part of 'scan_cubit.dart';

@immutable
abstract class ScanState {
  const ScanState();
}

class BleInitial extends ScanState {
  const BleInitial();
}

/// BLE 상태 전송용 클래스
/// - isPermissionGranted 퍼미션이 허락되었는지?
/// - isPowerOn BLE 기능이 켜 있는지?
/// - canScanning 스캔이 가능한지?
/// - isScanning 스캔 중인지?
class BleStatus extends ScanState {
  final bool isPermissionGranted;
  final bool isPowerOn;
  final bool canScanning;
  final bool isScanning;
  const BleStatus({
    this.isPermissionGranted,
    this.isPowerOn,
    this.canScanning,
    this.isScanning,
  });
}

/// 디바이스가 검색 되었을 때
/// - ScanCubit 클래스의 scanResults에 결과가 담겨 있음
/// - 변경 내용이 있다는 것만 전송 함
class DeviceListStatus extends ScanState {
  const DeviceListStatus();
}

/// 연결 상태 변경
/// - peripheral 디바이스
/// - status 상태
class ConnectionStatus extends ScanState {
  final Peripheral peripheral;
  final PeripheralConnectionState status;
  const ConnectionStatus({this.peripheral, this.status});
}

/// 메시지 전송용
/// - message 전달할 메시지
/// 예외나 기타 화면에 메시지를 출력할 필요가 있을 때 사용
class ScanMessageStatus extends ScanState {
  final String message;
  const ScanMessageStatus(this.message);
}
