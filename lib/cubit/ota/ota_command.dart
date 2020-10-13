import 'dart:typed_data';

import 'package:cubit_ble2/utils/array_utils.dart';
import 'package:cubit_ble2/cubit/ota/ota_file.dart';

enum CmdId {
  OTA_CMD_NewImageNotification,
  OTA_CMD_NewImageRequest,
  OTA_CMD_NewImageInfoResponse,
  OTA_CMD_ImageBlockRequest,
  OTA_CMD_ImageChunk,
  OTA_CMD_ImageTransferComplete,
  OTA_CMD_ErrorNotification,
  OTA_CMD_StopImageTransfer,
  OTA_CMD_Unknown,
}

enum OtaStep {
  OTA_NONE,
  OTA_MTU_SIZE_CHANGED,
  OTA_NEW_IMAGE_INFO_REQUEST,
  OTA_NEW_IMAGE_INFO_RESPONSE,
  OTA_NEW_IMAGE_BLOCK_REQUEST,
  OTA_NEW_IMAGE_CHUNK,
  OTA_NEW_IMAGE_TRANSFER_COMPLETED,
}

enum OtaError {
  OTA_SUCCESS,
  OTA_BLE_NOT_CONNECTED,
  OTA_BLE_NOT_OTAP_SUPPORT,
  OTA_FILE_FAILURE,
  OTA_MTU_SIZE_CHANGE_FAILURE,
  OTA_INDICATION_FAILURE,
  OTA_NEW_IMAGE_INFO_RESPONSE_FAILURE,
  OTA_NEW_IMAGE_CHUNK_FAILURE,
  OTA_DEVICE_ERROR_PACKET,
  OTA_DEVICE_STOP_COMMAND,
  OTA_DEVICE_UNKNOWN_COMMAND,
}

extension CmdIdExt on CmdId {
  int get value {
    switch (this) {
      case CmdId.OTA_CMD_NewImageNotification:
        return 1;
      case CmdId.OTA_CMD_NewImageRequest:
        return 2;
      case CmdId.OTA_CMD_NewImageInfoResponse:
        return 3;
      case CmdId.OTA_CMD_ImageBlockRequest:
        return 4;
      case CmdId.OTA_CMD_ImageChunk:
        return 5;
      case CmdId.OTA_CMD_ImageTransferComplete:
        return 6;
      case CmdId.OTA_CMD_ErrorNotification:
        return 7;
      case CmdId.OTA_CMD_StopImageTransfer:
        return 8;
      case CmdId.OTA_CMD_Unknown:
        return -1;
      default:
        return 0;
    }
  }
}

class OtaCommand extends ArrayUtils {
  Uint8List _data;

  CmdId get cmdId => CmdId.OTA_CMD_Unknown;

  ///
  /// 패킷 리턴
  /// @return - 바이트 어레이
  ///
  Uint8List get data => _data;

  ///
  /// aValue를 mData의 aDestPos 위치에 쓰기
  /// @param aValue - 기록할 값
  /// @param aDestPos - mData의 위치
  /// @param aBytes - 기록할 바이트 수
  ///
  void copyValue(int value, int pos, int copyBytes) {
    for (int i = 0; i < copyBytes; i++) {
      _data[pos++] = value;
      value = value >> 8;
    }
  }

  ///
  /// 어레이를 특정 위치에 쓰기
  /// @param aSorc - 소스 어레이
  /// @param aDestPos - 기록할 위치
  ///
  void copyArray(Uint8List sorc, int sorcStart, Uint8List dest, int destStart,
      int length) {
    if (sorc != null && dest != null) {
      for (int i = 0; i < length; i++) {
        dest[destStart++] = sorc[sorcStart++];
      }
    }
  }
  //void setValue(Uint8List aSorc, int aDestPos) {
  //    System.arraycopy(aSorc, 0, mData, aDestPos, aSorc.length);
  //}
}

///
/// NewImageNotificationCommand에 대한 응답 - Client to Server
/// - 현재 디바이스(클라이언트)에 설치되어 있는 이미지 버전을 돌려준다.
///
class NewImageInfoRequestCommand extends OtaCommand {
  int mCurrImageId;
  int mCurrImageVersion;
  NewImageInfoRequestCommand(Uint8List data) {
    _data = Uint8List(data.length);
    copyArray(data, 0, _data, 0, _data.length);
    _set();
  }

  @override
  CmdId get cmdId => CmdId.OTA_CMD_NewImageRequest;

  ///
  /// 전송된 패킷 데이터 분석
  ///
  void _set() {
    if (_data[0] != CmdId.OTA_CMD_NewImageRequest.value)
      throw new Exception("Is not OTA_CMD_NewImageRequest.");

    mCurrImageId = get16(_data, 1);
    mCurrImageVersion = get64(_data, 3);
  }
}

///
/// NewImageNotificationCommand에 대한 응답 - Server to Client
///
class NewImageInfoResponseCommand extends OtaCommand {
  final OtaFile otaFile;
  NewImageInfoResponseCommand(this.otaFile) {
    _data = new Uint8List(15);
    _set();
  }

  @override
  CmdId get cmdId => CmdId.OTA_CMD_NewImageInfoResponse;

  ///
  /// mOtaFile로부터 데이터를 읽어서 mData를 채움
  ///
  void _set() {
    _data[0] = cmdId.value;
    set16(_data, 1, otaFile.otaHeader.imageIdentifierValue); // 0x0001 보다 커야 함
    set64(_data, 3, otaFile.otaHeader.imageVersion64Value);
    set32(_data, 11, otaFile.data.length);
  }
}

///
/// NewImageInfoResponseCommand에 대한 응답 - Client to Server
/// - 블럭 전송에 관한 데이터를 요청한다.
///
class ImageBlockRequestCommand extends OtaCommand {
  ImageBlockRequestCommand(Uint8List data) {
    _data = Uint8List(data.length);
    copyArray(data, 0, _data, 0, data.length);
    _set();
  }

  // 내부 변수
  int _startPosition;
  int _blockSize;
  int _chunkSize;

  @override
  CmdId get cmdId => CmdId.OTA_CMD_ImageBlockRequest;
  int get startPosition => _startPosition;
  int get blockSize => _blockSize;
  int get chunkSize => _chunkSize;

  ///
  /// 전송된 패킷 데이터 분석
  ///
  void _set() {
    if (_data[0] != CmdId.OTA_CMD_ImageBlockRequest.value)
      throw Exception("Is not OTA_CMD_ImageBlockRequest.");

    //_imageId = get16(_data, 1);
    _startPosition = get32(_data, 3);
    _blockSize = get32(_data, 7);
    _chunkSize = get16(_data, 11);
  }
}

class ImageChunkCommand extends OtaCommand {
  ///
  /// 생성자
  /// - OtaFile로부터 청크를 생성한다.
  /// @param aOtaFile - OtaFile
  /// @param nStartPosition - 시작위치 옵셋
  /// @param nSN - 몇번째 청크인지
  /// @param nChunkSize - 청크 사이즈
  ///
  ImageChunkCommand(OtaFile otaFile, int startPosition, int sn, int chunkSize) {
    _set(otaFile, startPosition, sn, chunkSize);
  }

  @override
  CmdId get cmdId => CmdId.OTA_CMD_ImageChunk;

  void _set(OtaFile otaFile, int startPosition, int sn, int chunkSize) {
    // 끝 부분 처리 필요
    int nPos = startPosition + chunkSize * sn;
    int nEnd = nPos + chunkSize;
    int nLen = chunkSize;
    if (nEnd > otaFile.data.length) {
      nLen = chunkSize - (nEnd - otaFile.data.length);
    }

    _data = Uint8List(nLen + 2);
    _data[0] = CmdId.OTA_CMD_ImageChunk.value;
    _data[1] = sn;
    copyArray(otaFile.data, startPosition + chunkSize * sn, _data, 2, nLen);
  }
}
