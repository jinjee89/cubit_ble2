part of 'ota_cubit.dart';

@immutable
abstract class OtaState {
  const OtaState();
}

class OtaInitial extends OtaState {
  const OtaInitial();
}

/// 서비스 디스커버 알림
class OtaDiscoverStatus extends OtaState {
  final String identifier;
  const OtaDiscoverStatus({@required this.identifier});
}

/// 디바이스 버전 정보 알림
class OtaDeviceVersionStatus extends OtaState with ArrayUtils {
  final String identifier;
  final OtaDeviceHeader otaDeviceHeader;
  const OtaDeviceVersionStatus(
      {@required this.identifier, @required this.otaDeviceHeader});
}

/// 파일 버전 정보 알림
class OtaFileVersionStatus extends OtaState {
  final String identifier;
  final OtaFileHeader header;
  const OtaFileVersionStatus(
      {@required this.identifier, @required this.header});
}

/// 배터리 충전 량 알림
class OtaBatteryStatus extends OtaState {
  final String identifier;
  final int batteryLevel;
  final bool isCharging;
  OtaBatteryStatus(
      {@required this.identifier,
      @required this.batteryLevel,
      this.isCharging = false});
}

/// 업데이트가 가능한지 상태 알림
class OtaUpdatableStatus extends OtaState {
  final String identifier;
  OtaUpdatableStatus({@required this.identifier});
}

/// 업데이트 상태 이넘
enum OtaUpdatingState {
  None,
  Updating,
  Completed,
  Cancel,
}

/// 업데이트 상태 알림
class OtaUpdateStatus extends OtaState {
  final String identifier;
  final OtaUpdatingState state;
  OtaUpdateStatus({
    @required this.identifier,
    @required this.state,
  });
}

/// 업데이트 진행률 알림
class OtaProgressStatus extends OtaState {
  final String identifier;
  final double progress;
  OtaProgressStatus({
    @required this.identifier,
    @required this.progress,
  });
}

/// 화면에 표시할 메시지 알림
class OtaMessage extends OtaState {
  final String identifier;
  final String message;
  OtaMessage({@required this.identifier, this.message});
}
