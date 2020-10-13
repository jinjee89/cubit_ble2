import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:cubit_ble2/cubit/base_cubit.dart';
import 'package:cubit_ble2/utils/array_utils.dart';
import 'package:cubit_ble2/cubit/ota/ota_command.dart';
import 'package:cubit_ble2/cubit/ota/ota_device_header.dart';
import 'package:cubit_ble2/cubit/ota/ota_file.dart';
import 'package:cubit_ble2/cubit/ota/ota_file_header.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'package:meta/meta.dart';

part 'ota_state.dart';

///
/// 여러개의 디바이스를 동시에 관리할 수 있는 형태로 변경
/// OtaDevice 클래스에서 각 기능을 담당
///
class OtaCubit extends Cubit<OtaState> {
  OtaCubit() : super(OtaInitial());

  // 연결된 디바이스의 데이터 처리를 담당하는 인스턴스 모음
  Map<String, OtaDevice> _otaDevices = Map();

  // 연결 목록
  List<Peripheral> get connectedDevices =>
      _otaDevices.entries.map((entry) => entry.value.peripheral).toList();

  /// 디바이스 얻어오기
  OtaDevice getDevice(Peripheral peripheral) {
    if (_otaDevices.containsKey(peripheral.identifier)) {
      // 기존 디바이스가 있으면 기존 디바이스 리턴
      return _otaDevices[peripheral.identifier];
    } else {
      // 새로운 클래스 생성 후 리턴
      final OtaDevice device = OtaDevice(peripheral: peripheral, emit: emit);
      _otaDevices[peripheral.identifier] = device;

      // 연결이 끊겼을 때 처리
      peripheral.observeConnectionState().listen(
        (event) {
          if (event == PeripheralConnectionState.disconnected) {
            // 열어 놓은 Notify, Indication을 닫는다.
            device.stop();
            _otaDevices.remove(peripheral.identifier);
          }
        },
      );

      return device;
    }
  }
}

///
/// 각 디바이스와 실제 통신을 담당하는 클래스
///
class OtaDevice with ArrayUtils, BaseCubit {
  static String roEmService = 'f3c7622a-5a97-4d98-5347-060069ef22f1';
  static String roEmRW = '443476c9-88fe-56b6-e746-20d80ac00900';
  static String roEmNotify = '443476c9-88fe-56b6-e746-20d80ac00901';
  static String otaService = '01ff5550-ba5e-f4ee-5ca1-eb1e5e4b1ce0';
  static String otaControl = '01ff5551-ba5e-f4ee-5ca1-eb1e5e4b1ce0';
  static String otaData = '01ff5552-ba5e-f4ee-5ca1-eb1e5e4b1ce0';

  // 내부 변수
  OtaFile _otaFile; // OTA 파일 클래스
  OtaStep _mOtaStep = OtaStep.OTA_NONE; // OTA 스텝
  OtaDeviceHeader _otaDeviceHeader; // 디바이스의 OTA 버전 정보
  bool _isServiceDiscovered = false; // 서비스 디스커버리 완료?
  bool _isRoEmServiceExists = false; // RoEm Service가 있는지?
  bool _isOTAServiceExists = false; // OTA Service가 있는지?
  int _batteryLevel = 0; // 배터리 레벨(30% 이상일 때 업데이트 가능) - 충전 중일때?
  bool _isCharging = false; // 충전중일 때 업데이트 가능

  // 노티피케이션을 활성화(monitor) 했을 때, 각 subscription을 저장하기 위한 내부 변수
  StreamSubscription<Uint8List> _otaSubs; // OTA Indication 스트림
  Characteristic _otaNotify; // Ota Notify
  Characteristic _otaControl; // Ota Control
  // _otaNotify를 연결했을 때 디바이스 버전 정보를 수신한 데이터, 업데이트를 시작할 때 필요
  Uint8List _otaVersionData;
  StreamSubscription<Uint8List> _qcSubs; // 배터리 정보, 충전 정보를 얻기 위해 RoEm Notify 동작

  /// 생성자
  final Peripheral peripheral;
  final Function emit;
  OtaDevice({@required this.peripheral, @required this.emit});

  // GET
  String get identifier => peripheral.identifier;
  bool get isServiceDiscovered => _isServiceDiscovered;
  bool get isRoEmServiceExists => _isRoEmServiceExists;
  bool get isOTAServiceExists => _isOTAServiceExists;

  // 업데이트 상태
  OtaUpdatingState _updateState = OtaUpdatingState.None;
  OtaUpdatingState get updateState => _updateState;
  set updateState(value) {
    if (_updateState != value) {
      _updateState = value;
      emit(OtaUpdateStatus(
        identifier: identifier,
        state: _updateState,
      ));
      emit(OtaUpdatableStatus(identifier: identifier));
    }
  }

  // 업데이트 진행율
  double _updateProgress = 0.0;
  double get updateProgress => _updateProgress;
  set updateProgress(double value) {
    if (_updateProgress != value) {
      _updateProgress = value;
      emit(OtaProgressStatus(
        identifier: identifier,
        progress: _updateProgress,
      ));
    }
  }

  /// 업데이트 가능 조건
  /// Manufacturer Id -> 동일
  /// Hardware Id -> 동일
  /// Build Version 이 커야 함
  bool get isUpdatable =>
      _isServiceDiscovered &&
      _isRoEmServiceExists &&
      _isOTAServiceExists &&
      _otaDeviceHeader != null &&
      _otaFile != null &&
      _otaFile.otaHeader != null &&
      _otaDeviceHeader.hardwareVersion == _otaFile.otaHeader.hardwareVersion &&
      isNewerVersion &&
      (_batteryLevel >= 30 || _isCharging) &&
      updateState != OtaUpdatingState.Updating;

  int get batteryLevel => _batteryLevel;

  bool get isNewerVersion =>
      _otaDeviceHeader != null &&
      _otaFile != null &&
      _otaFile.otaHeader != null &&
      (_otaDeviceHeader.buildVersion
              .compareTo(_otaFile.otaHeader.buildVersion) <=
          0);

  bool get updateFileSelected => _otaFile != null;

  /// 서비스 디스커버링
  /// - 서비스 중에 RoEmService가 있으면 링크 커맨드를 전송하여 파워오프 방지
  /// - 배터리 상태를 읽기 위해서 RoEm Notify를 monitor 한다.
  /// - 서비스 중에 OtaService가 있는지 확인
  /// - 디스커버링 상태 전송
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
          _isRoEmServiceExists = true;

          // RoEm Service가 있으면 연결 명령 전송
          linkCommand(chars[0]);

          // 배터리 모니터링을 위해서
          _qcSubs = chars[1].monitor().listen(
            (data) {
              if (data != null && data.length > 20 && data[4] == 0xFC) {
                // batteryCapacity => data[29].toString();
                _batteryLevel = data[29];
                _isCharging = (data[26] & 0x10) != 0;
                emit(OtaBatteryStatus(
                    identifier: identifier,
                    batteryLevel: _batteryLevel,
                    isCharging: _isCharging));
                print('Battery Monitoring');
              }
            },
          );
        } else if (_services[i].uuid.toString() == otaService) {
          var chars = await _services[i].characteristics();
          _otaNotify = chars[0];
          _otaControl = chars[1];
          _isOTAServiceExists = true;
        }
      }

      // 디스커버링 상태 업데이트
      emit(OtaDiscoverStatus(identifier: identifier));
    }
  }

  /// 디바이스 정보 얻기
  /// 인디케이션을 연결하면 디바이스에서 자신의 버전 정보를 전송한다.
  /// 이 정보를 _otaVersionData 담아 둔다.
  /// 업데이트를 계속하려면 이에 대한 응답을 보내면 되지만 사용자의 시작 명령에
  /// 반응하기 위해서 다음 메시지를 보내지 않는다.
  /// 계속하기 위한 메시지 전송은 updateDevice()에서 담당한다.
  /// 다만 Indication에 대한 메시지 처리는 이 함수 내에서 한다.
  Future<void> getDeviceVersion() async {
    if (_otaNotify != null) {
      _otaSubs = _otaNotify.monitor().listen(
        (data) async {
          // 첫번 데이터(디바이스 버전 정보)
          if (data[0] == CmdId.OTA_CMD_NewImageRequest.value) {
            // 02 0000 010000 41 111111 01 - 명령어 형태
            // 02 - 커맨트 ID
            // 0000 - 자신이 가지고 있는 이미지 Id
            // 010000 - 빌드 버전
            // 41 - 스택 버전
            // 111111 - HW Id
            // 01 - 제조사 Id의 마지막 8bit
            _otaVersionData = data;
            _otaDeviceHeader = OtaDeviceHeader(data: _otaVersionData);
            emit(OtaDeviceVersionStatus(
                identifier: identifier, otaDeviceHeader: _otaDeviceHeader));
          } else {
            // 이 패킷
            _checkClientCommand(data);
          }
        },
      );
    }
  }

  /// 선택한 OTA 파일의 버전을 획득한다.
  /// - 버전 상태 전송
  Future<void> getFileVersion(String path) async {
    _otaFile = OtaFile(path);
    await _otaFile.init();
    emit(OtaFileVersionStatus(
        identifier: identifier, header: _otaFile.otaHeader));
    emit(OtaUpdatableStatus(identifier: identifier));
  }

  /// 디바이스 업데이트
  /// 시퀀스 설명
  /// - Indication 연결을 하면 디바이스는 자신의 버전 정보를 전송한다(_otaVersionData)
  /// - 업데이트를 진행하기 위해서 앱(서버)는 NewImageInfoResponseCommand를 보낸다.
  /// - 이후 서로 데이터요청과 데이터 전송을 진행한다.
  /// 이 함수는 getDeviceVersion() 함수에서 받아 둔 _otaVersionData에 대한 응답을 보내면서
  /// 멈추어 둔 업데이트를 진핸한다.
  void updateDevice() {
    // 다음 단계로 진행을 위해서
    _checkClientCommand(_otaVersionData);
    updateState = OtaUpdatingState.Updating;
  }

  /// 모든 모니터링 중지
  void stop() {
    if (_qcSubs != null) {
      _qcSubs.cancel();
      _qcSubs = null;
    }
    if (_otaSubs != null) {
      _otaSubs.cancel();
      _otaSubs = null;
    }
  }

  void _checkClientCommand(Uint8List cmdData) async {
    if (cmdData[0] == CmdId.OTA_CMD_NewImageRequest.value) {
      // 0x02
      // Notification이 활성화되면 디바이스에서 이 패킷을 전송해 준다.
      // 02 0000 010000 41 111111 01 - 명령어 형태
      // 02 - 커맨트 ID
      // 0000 - 자신이 가지고 있는 이미지 Id
      // 010000 - 빌드 버전
      // 41 - 스택 버전
      // 111111 - HW Id
      // 01 - 제조사 Id의 마지막 8bit

      // 연속 진행을 위해서 앱은 NewImageInfoResponseCommand 패킷을 발송한다.
      _mOtaStep = OtaStep.OTA_NEW_IMAGE_INFO_REQUEST;

      // 내가 가지고 있는 버전과 디바이스 펌웨어 버전을 확인 한다.
      // FW 버전은 이곳으로 오기 전에 확인 후 호출 한다.

      // 응답 발송
      NewImageInfoResponseCommand bCmd = NewImageInfoResponseCommand(_otaFile);
      await _otaNotify.write(bCmd.data, true).catchError((e) {
        updateState = OtaUpdatingState.Cancel;
        emit(OtaMessage(
            identifier: identifier,
            message: 'OTA_NEW_IMAGE_INFO_RESPONSE_FAILURE'));
        print('OtaError.OTA_NEW_IMAGE_INFO_RESPONSE_FAILURE');
      }).whenComplete(() {
        _mOtaStep = OtaStep.OTA_NEW_IMAGE_INFO_RESPONSE;
      });
    } else if (cmdData[0] == CmdId.OTA_CMD_ImageBlockRequest.value) {
      // 0x04
      // 04 0100 00000000 00F20000 F200 00 0400
      // 04 - 커맨트 ID
      // 0100 - 전송 받을 이미지 Id
      // 00000000 - 이미지 파일 시작 위치
      // 00F20000 - 블럭 사이즈
      // F200 - 청크 사이즈
      // 00 - 전송 방식 00 - ATT
      // 0400 - L2capChannelIOrPsm 0x004 - ATT

      final ImageBlockRequestCommand aCmd =
          new ImageBlockRequestCommand(cmdData);

      _mOtaStep = OtaStep.OTA_NEW_IMAGE_BLOCK_REQUEST;
      updateProgress = _otaFile.sendLength / _otaFile.data.length;

      // 응답 발송
      // 05 XX(SN) DDDDDD... 데이터
      // 05 - 커맨드 ID
      // XX - 시리얼 넘버
      // DDDDDD.... - 데이터
      int nBlockSize = aCmd.blockSize;
      int nSN = 0;

      _mOtaStep = OtaStep.OTA_NEW_IMAGE_CHUNK;

      while (nBlockSize > 0) {
        ImageChunkCommand bCmd = new ImageChunkCommand(
            _otaFile, aCmd.startPosition, nSN++, aCmd.chunkSize);
        await _otaControl.write(bCmd.data, false).catchError((e) {
          updateState = OtaUpdatingState.Cancel;
          print('WB-');
          emit(OtaMessage(
              identifier: identifier,
              message: 'OTA_NEW_IMAGE_INFO_RESPONSE_FAILURE'));
          print('OtaError.OTA_NEW_IMAGE_INFO_RESPONSE_FAILURE');
        });

        print('WB+');

        nBlockSize -= aCmd.chunkSize;
        _otaFile.sendLength += aCmd.chunkSize;
        print(
            'OTA size: ${_otaFile.data.length}, Send size: ${_otaFile.sendLength}, Block size: $nBlockSize, Chunk size: ${aCmd.chunkSize}');

        updateProgress = _otaFile.sendLength / _otaFile.data.length;

        if (updateState != OtaUpdatingState.Updating) break;
      }
      sleep(const Duration(microseconds: 100));
      print('Out block');
    } else if (cmdData[0] == CmdId.OTA_CMD_ImageTransferComplete.value) {
      // 0x06
      // 06 0100 00
      // 06 - 커맨드 ID
      // 0100 - Image Id
      // 00 - Status(000 - success)
      _mOtaStep = OtaStep.OTA_NEW_IMAGE_TRANSFER_COMPLETED;
      updateState = OtaUpdatingState.Cancel;
      emit(OtaMessage(identifier: identifier, message: '업데이트가 완료되었습니다.'));
    } else if (cmdData[0] == CmdId.OTA_CMD_ErrorNotification.value) {
      // 0x07
      // 07 0100 XX
      // 07 - 커맨드 ID
      // 0100 - Image Id
      // XX - Error Status

      // FW Source Code 참조
      // #define gOtapStatusSuccess_c                        0x00U /*!< The operation was successful. */
      // #define gOtapStatusImageDataNotExpected_c           0x01U /*!< The OTAP Server tried to send an image data chunk to the OTAP Client but the Client was not expecting it. */
      // #define gOtapStatusUnexpectedTransferMethod_c       0x02U /*!< The OTAP Server tried to send an image data chunk using a transfer method the OTAP Client does not support/expect. */
      // #define gOtapStatusUnexpectedCmdOnDataChannel_c     0x03U /*!< The OTAP Server tried to send an unexpected command (different from a data chunk) on a data Channel (ATT or CoC) */
      // #define gOtapStatusUnexpectedL2capChannelOrPsm_c    0x04U /*!< The selected channel or PSM is not valid for the selected transfer method (ATT or CoC). */
      // #define gOtapStatusUnexpectedOtapPeer_c             0x05U /*!< A command was received from an unexpected OTAP Server or Client device. */
      // #define gOtapStatusUnexpectedCommand_c              0x06U /*!< The command sent from the OTAP peer device is not expected in the current state. */
      // #define gOtapStatusUnknownCommand_c                 0x07U /*!< The command sent from the OTAP peer device is not known. */
      // #define gOtapStatusInvalidCommandLength_c           0x08U /*!< Invalid command length. */
      // #define gOtapStatusInvalidCommandParameter_c        0x09U /*!< A parameter of the command was not valid. */
      // #define gOtapStatusFailedImageIntegrityCheck_c      0x0AU /*!< The image integrity check has failed. */
      // #define gOtapStatusUnexpectedSequenceNumber_c       0x0BU /*!< A chunk with an unexpected sequence number has been received. */
      // #define gOtapStatusImageSizeTooLarge_c              0x0CU /*!< The upgrade image size is too large for the OTAP Client. */
      // #define gOtapStatusUnexpectedDataLength_c           0x0DU /*!< The length of a Data Chunk was not expected. */
      // #define gOtapStatusUnknownFileIdentifier_c          0x0EU /*!< The image file identifier is not recognized. */
      // #define gOtapStatusUnknownHeaderVersion_c           0x0FU /*!< The image file header version is not recognized. */
      // #define gOtapStatusUnexpectedHeaderLength_c         0x10U /*!< The image file header length is not expected for the current header version. */
      // #define gOtapStatusUnexpectedHeaderFieldControl_c   0x11U /*!< The image file header field control is not expected for the current header version. */
      // #define gOtapStatusUnknownCompanyId_c               0x12U /*!< The image file header company identifier is not recognized. */
      // #define gOtapStatusUnexpectedImageId_c              0x13U /*!< The image file header image identifier is not as expected. */
      // #define gOtapStatusUnexpectedImageVersion_c         0x14U /*!< The image file header image version is not as expected. */
      // #define gOtapStatusUnexpectedImageFileSize_c        0x15U /*!< The image file header image file size is not as expected. */
      // #define gOtapStatusInvalidSubElementLength_c        0x16U /*!< One of the sub-elements has an invalid length. */
      // #define gOtapStatusImageStorageError_c              0x17U /*!< An image storage error has occurred. */
      // #define gOtapStatusInvalidImageCrc_c                0x18U /*!< The computed CRC does not match the received CRC. */
      // #define gOtapStatusInvalidImageFileSize_c           0x19U /*!< The image file size is not valid. */
      // #define gOtapStatusInvalidL2capPsm_c                0x1AU /*!< A block transfer request has been made via the L2CAP CoC method but the specified Psm is not known. */
      // #define gOtapStatusNoL2capPsmConnection_c           0x1BU /*!< A block transfer request has been made via the L2CAP CoC method but there is no valid PSM connection. */
      // #define gOtapNumberOfStatuses_c                     0x1CU

      String msg = '';
      switch (cmdData[3]) {
        case 0x00:
          msg = "The operation was successful.";
          break;
        case 0x01:
          msg =
              "The OTAP Server tried to send an image data chunk to the OTAP Client but the Client was not expecting it.";
          break;
        case 0x02:
          msg =
              "The OTAP Server tried to send an image data chunk using a transfer method the OTAP Client does not support/expect.";
          break;
        case 0x03:
          msg =
              "The OTAP Server tried to send an unexpected command (different from a data chunk) on a data Channel (ATT or CoC)";
          break;
        case 0x04:
          msg =
              "The selected channel or PSM is not valid for the selected transfer method (ATT or CoC).";
          break;
        case 0x05:
          msg =
              "A command was received from an unexpected OTAP Server or Client device.";
          break;
        case 0x06:
          msg =
              "The command sent from the OTAP peer device is not expected in the current state.";
          break;
        case 0x07:
          msg = "The command sent from the OTAP peer device is not known.";
          break;
        case 0x08:
          msg = "Invalid command length.";
          break;
        case 0x09:
          msg = "A parameter of the command was not valid.";
          break;
        case 0x0A:
          msg = "The image integrity check has failed.";
          break;
        case 0x0B:
          msg = "A chunk with an unexpected sequence number has been received.";
          break;
        case 0x0C:
          msg = "The upgrade image size is too large for the OTAP Client.";
          break;
        case 0x0D:
          msg = "The length of a Data Chunk was not expected.";
          break;
        case 0x0E:
          msg = "The image file identifier is not recognized.";
          break;
        case 0x0F:
          msg = "The image file header version is not recognized.";
          break;
        case 0x10:
          msg =
              "The image file header length is not expected for the current header version.";
          break;
        case 0x11:
          msg =
              "The image file header field control is not expected for the current header version.";
          break;
        case 0x12:
          msg = "The image file header company identifier is not recognized.";
          break;
        case 0x13:
          msg = "The image file header image identifier is not as expected.";
          break;
        case 0x14:
          msg = "The image file header image version is not as expected.";
          break;
        case 0x15:
          msg = "The image file header image file size is not as expected.";
          break;
        case 0x16:
          msg = "One of the sub-elements has an invalid length.";
          break;
        case 0x17:
          msg = "An image storage error has occurred.";
          break;
        case 0x18:
          msg = "The computed CRC does not match the received CRC.";
          break;
        case 0x19:
          msg = "The image file size is not valid.";
          break;
        case 0x1A:
          msg =
              "A block transfer request has been made via the L2CAP CoC method but the specified Psm is not known.";
          break;
        case 0x1B:
          msg =
              "A block transfer request has been made via the L2CAP CoC method but there is no valid PSM connection.";
          break;
        case 0x1C:
          msg = "";
          break;
      }
      emit(OtaMessage(identifier: identifier, message: msg));
    } else if (cmdData[0] == CmdId.OTA_CMD_StopImageTransfer.value) {
      // 0x08
      // 08 0100
      // 08 - 커맨드 ID
      // 0100 - Image Id
      updateState = OtaUpdatingState.Cancel;
      emit(OtaMessage(
          identifier: identifier, message: 'OTA_DEVICE_STOP_COMMAND'));
    } else {
      // Unknown command
      updateState = OtaUpdatingState.Cancel;
      emit(OtaMessage(
          identifier: identifier, message: 'OTA_DEVICE_UNKNOWN_COMMAND'));
    }
  }
}
