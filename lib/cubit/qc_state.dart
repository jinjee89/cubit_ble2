part of 'qc_cubit.dart';

@immutable
abstract class QcState {
  const QcState();
}

/// 초기화 상태
class QcInitial extends QcState {
  const QcInitial();
}

/// 서비스 디스커버 알림
class QcDiscoverStatus extends QcState {
  final String identifier;
  const QcDiscoverStatus({@required this.identifier});
}

/// 커맨드 전송 알림
class CommandStatus extends QcState {
  final String identifier;
  const CommandStatus({@required this.identifier});
}

/// QC 데이터 알림
class QcStatus extends QcState with ArrayUtils {
  final String identifier;
  final Uint8List data;
  const QcStatus({@required this.identifier, @required this.data});

  String get productID =>
      toHexString(value: get16(data, 8, Endian.big), len: 4);
  String get qnFwVersion =>
      toHexString(value: get32(data, 10, Endian.big), len: 8);
  String get hwVersion =>
      toHexString(value: get24(data, 14, Endian.big), len: 6);
  String get mspFwVersion =>
      toHexString(value: get16(data, 17, Endian.big), len: 4);
  String get batteryVoltage =>
      (get16(data, 19, Endian.big) / 1000.0).toString();
  String get usbVoltage => (get16(data, 21, Endian.big) / 1000.0).toString();
  String get waterVoltage => (get16(data, 23, Endian.big) / 1000.0).toString();
  String get temperature => get8(data, 25).toString();
  String get mspStatus => _toMspStatus(data[26]);
  String get errorCode => _toErrorCode(data[27]);
  String get batteryStatus => _toBatteryStatus(data[28]);
  String get batteryCapacity => get8(data, 29).toString();
  String get rssi => get8(data, 30).toString();
  String get bps => get32(data, 31, Endian.big).toString();
  String get sentPackets => get16(data, 35, Endian.big).toString();
  String get failPackets => get16(data, 37, Endian.big).toString();
  String get skipPackets => get16(data, 39, Endian.big).toString();
  String get macAddress => _toMacAddress(data, 41).toUpperCase();
  String get bootCount => get32(data, 47, Endian.big).toString();

  String _toMspStatus(int v) {
    String str = "";
    str += ((v & 0x40) == 0 ? "충전금지" : "충전허용") + " / ";
    str += ((v & 0x20) == 0 ? "버튼터치 OFF" : "버튼터치 ON") + " / ";
    str += ((v & 0x10) == 0 ? "비 충전" : "충전 중") + " / ";
    str += ((v & 0x08) == 0
            ? ((v & 0x04) == 0 ? "Can't detect" : "Low power")
            : ((v & 0x04) == 0)
                ? "Normal"
                : "Full") +
        " / ";
    str += ((v & 0x02) == 0 ? "물 없음" : "물 묻음 감지") + " / ";
    str += ((v & 0x01) == 0 ? "USB 케이블 없음" : "USB 케이블 연결");
    return str;
  }

  String _toErrorCode(int v) {
    switch (v) {
      case 0:
        return "에러 없음";
      case 1:
        return "보드 레벨 에러";
      case 2:
        return "온도 초과 : 45도 이상";
      case 3:
        return "물기 감지되어 충전 안되는 상황";
      default:
        return "Unknown";
    }
  }

  String _toBatteryStatus(int v) {
    switch (v) {
      case 0:
        return "battery full";
      case 1:
        return "battery normal";
      case 2:
        return "battery low";
      case 3:
        return "battery very low";
      case 4:
        return "battery power off level";
      default:
        return "Unknown";
    }
  }

  String _toMacAddress(Uint8List v, int pos) {
    String str = '';
    for (int i = 5; i >= 0; i--) {
      str += v[i + pos].toRadixString(16).padLeft(2, '0') + '-';
    }
    return str.substring(0, str.length - 1);
  }
}
