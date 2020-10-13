part of 'char_cubit.dart';

@immutable
abstract class CharState {
  const CharState();
}

class CharInitial extends CharState {
  const CharInitial();
}

/// 서비스 선택 변경 알림
class ServiceStatus extends CharState {
  final String identifier;
  const ServiceStatus({@required this.identifier});
}

/// 캐릭터리스틱 선택 변경 알림
class CharacteristicStatus extends CharState {
  final String identifier;
  const CharacteristicStatus({@required this.identifier});
}

/// 노티파이 변경 알림
class NotifyStatus extends CharState {
  final String identifier;
  final Characteristic characteristic;
  final Uint8List data;

  NotifyStatus({
    @required this.identifier,
    @required this.characteristic,
    @required this.data,
  });
}

/// Bps 변경 알림
class BpsStatus extends CharState {
  final String identifier;
  final double bps;
  const BpsStatus({@required this.identifier, this.bps});
}

/// 화면에 메시지 출력이 필요할 때
class CharMessageStatus extends CharState {
  final String identifier;
  final String message;
  const CharMessageStatus({@required this.identifier, this.message});
}
