import 'dart:core';
import 'dart:math';
import 'dart:typed_data';

class ArrayUtils {
  ///
  /// 바이트 배열의 특정 위치부터 Byte로 변환
  /// @param aData - 배열 데이터
  /// @param aPos - 변환 시작 위치
  /// @return - 변환 결과
  ///
  int get8(Uint8List aData, int aPos) {
    return ByteData.view(aData.buffer).getInt8(aPos);
  }

  void set8(Uint8List aData, int aPos, int aValue) {
    aData[aPos] = aValue;
  }

  ///
  /// 바이트 배열의 특정 위치부터 Short로 변환
  /// @param aData - 배열 데이터
  /// @param aPos - 변환 시작 위치
  /// @return - 변환 결과
  ///
  int get16(Uint8List aData, int aPos, [Endian endian = Endian.little]) {
    return ByteData.view(aData.buffer).getInt16(aPos, endian);
  }

  void set16(Uint8List aData, int aPos, int aValue,
      [Endian endian = Endian.little]) {
    if (endian == Endian.little) {
      aData[aPos++] = aValue;
      aData[aPos++] = aValue ~/ 0x100;
    } else {
      aData[aPos++] = aValue ~/ 0x100;
      aData[aPos++] = aValue;
    }
  }

  ///
  /// 바이트 배열의 특정 위치부터 24로 변환
  /// @param aData - 배열 데이터
  /// @param aPos - 변환 시작 위치
  /// @return - 변환 결과
  ///
  int get24(Uint8List aData, int aPos, [Endian endian = Endian.little]) {
    return aData[aPos++] + (aData[aPos++] << 8) + (aData[aPos++] << 16);
  }

  void set24(Uint8List aData, int aPos, int aValue,
      [Endian endian = Endian.little]) {
    if (endian == Endian.little) {
      aData[aPos++] = aValue;
      aData[aPos++] = aValue ~/ 0x100;
      aData[aPos++] = aValue ~/ 0x10000;
    } else {
      aData[aPos++] = aValue ~/ 0x10000;
      aData[aPos++] = aValue ~/ 0x100;
      aData[aPos++] = aValue;
    }
  }

  ///
  /// 바이트 배열의 특정 위치부터 Int로 변환
  /// @param aData - 배열 데이터
  /// @param aPos - 변환 시작 위치
  /// @return - 변환 결과
  ///
  int get32(Uint8List aData, int aPos, [Endian endian = Endian.little]) {
    return ByteData.view(aData.buffer).getInt32(aPos, endian);
  }

  void set32(Uint8List aData, int aPos, int aValue,
      [Endian endian = Endian.little]) {
    if (endian == Endian.little) {
      aData[aPos++] = aValue;
      aData[aPos++] = aValue ~/ 0x100;
      aData[aPos++] = aValue ~/ 0x10000;
      aData[aPos++] = aValue ~/ 0x1000000;
    } else {
      aData[aPos++] = aValue ~/ 0x1000000;
      aData[aPos++] = aValue ~/ 0x10000;
      aData[aPos++] = aValue ~/ 0x100;
      aData[aPos++] = aValue;
    }
  }

  ///
  /// 바이트 배열의 특정 위치부터 long으로 변환
  /// @param aData - 배열 데이터
  /// @param aPos - 변환 시작 위치
  /// @return - 변환 결과
  ///
  int get64(Uint8List aData, int aPos, [Endian endian = Endian.little]) {
    return ByteData.view(aData.buffer).getInt64(aPos, endian);
  }

  void set64(Uint8List aData, int aPos, int aValue,
      [Endian endian = Endian.little]) {
    if (endian == Endian.little) {
      aData[aPos++] = aValue;
      aData[aPos++] = aValue ~/ 0x100;
      aData[aPos++] = aValue ~/ 0x10000;
      aData[aPos++] = aValue ~/ 0x1000000;
      aData[aPos++] = aValue ~/ 0x100000000;
      aData[aPos++] = aValue ~/ 0x10000000000;
      aData[aPos++] = aValue ~/ 0x1000000000000;
      aData[aPos++] = aValue ~/ 0x100000000000000;
    } else {
      aData[aPos++] = aValue ~/ 0x100000000000000;
      aData[aPos++] = aValue ~/ 0x1000000000000;
      aData[aPos++] = aValue ~/ 0x10000000000;
      aData[aPos++] = aValue ~/ 0x100000000;
      aData[aPos++] = aValue ~/ 0x1000000;
      aData[aPos++] = aValue ~/ 0x10000;
      aData[aPos++] = aValue ~/ 0x100;
      aData[aPos++] = aValue;
    }
  }

  ///
  /// 바이트 배열의 특정 부분을 카피
  /// @param aData - 바이트 배열
  /// @param aPos - 복사 시작 위치
  /// @param aLen - 복사할 길이
  /// @return - 복사한 배열
  ///
  Uint8List getA(Uint8List aData, int aPos, int aLen) {
    Uint8List aCopy = Uint8List(aLen);
    for (int i = 0; i < aLen; i++) {
      aCopy[i] = aData[aPos + i];
    }
    return aCopy;
  }

  ///
  /// 바이트 배열의 특정 부분을 문자열로 변환(ASCII 만 가능)
  /// @param aData - 바이트 배열
  /// @param aPos - 복사 시작 위치
  /// @param aLen - 복사할 길이
  /// @return - 복사한 배열
  ///
  String getS(Uint8List aData, int aPos, int aLen) {
    String str = '';
    for (int i = 0; i < aLen; i++) {
      str += String.fromCharCode(aData[aPos + i]);
    }
    return str;
  }

  /// 1. 정수를 문자열로 변경시
  ///   - value: 정수 값
  ///   - len: 몇 자리로 표현할 것인가?
  /// 2. 배열을 문자열로 변경시
  ///   - array: 배열
  ///   - len: 배열의 몇 번째 인덱스까지 표현할 것인가?
  String toHexString({int value, Uint8List array, int len = 8}) {
    if (value != null) {
      return value.toRadixString(16).padLeft(len, '0').toUpperCase();
    } else if (array != null) {
      String str = '';
      if (array != null) {
        for (int i = 0; i < min(len, array.length); i++) {
          str += '${array[i].toRadixString(16).padLeft(2, '0')} ';
        }
        return '$str${array.length > len ? '...' : ''}';
      }
    }
    return '';
  }

  /// 핵사 문자열을 바이트 어레이로 변환
  Uint8List toArray(String hexString, [String seperator = ' ']) {
    List<int> value = [];
    for (var h in hexString.split(seperator)) {
      try {
        int v = int.parse(h, radix: 16);
        value.add(v);
      } catch (e) {}
    }
    return Uint8List.fromList(value);
  }
}
