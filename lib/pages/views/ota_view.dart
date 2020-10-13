import 'package:cubit_ble2/cubit/ota/ota_device_header.dart';
import 'package:cubit_ble2/cubit/ota/ota_file_header.dart';
import 'package:cubit_ble2/cubit/ota_cubit.dart';
import 'package:cubit_ble2/pages/ui/common_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// OTAView 위젯
/// UI 구성
/// - 좌우 2개의 컬럼으로 구성되며
/// - 좌측: 선택한 OTA 파일 정보
/// - 우측: 연결한 디바이스 정보
/// - 하단: 업데이트 프로그래스바 표시
/// 서비스 디스커버 중에는 웨이트 써클 표시
/// 서비스 디스커버 완료 후 메인 뷰 호출
class OTAView extends StatelessWidget {
  final Peripheral peripheral;
  const OTAView({this.peripheral});

  @override
  Widget build(BuildContext context) {
    // 연결된 디바이스 획득 및 디스커버링
    OtaDevice otaDevice = context.bloc<OtaCubit>().getDevice(peripheral);
    otaDevice.discovers();

    return BlocBuilder<OtaCubit, OtaState>(
      buildWhen: (previous, current) {
        return (current is OtaDiscoverStatus &&
            current.identifier == otaDevice.identifier);
      },
      builder: (context, state) {
        print('OTAView state: $state');
        if (!otaDevice.isServiceDiscovered) {
          return Center(child: CircularProgressIndicator());
        } else if (!otaDevice.isRoEmServiceExists) {
          return Center(child: Text('RoEm Service is not supported.'));
        } else {
          print('OTAView startMonitoring');
          otaDevice.getDeviceVersion();
          return ViewDetail(otaDevice: otaDevice);
        }
      },
    );
  }
}

/// 메인 뷰 클래스
class ViewDetail extends StatelessWidget {
  final OtaDevice otaDevice;
  const ViewDetail({@required this.otaDevice});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 20),
          // 좌우에 파일 버전, 디바이스 버전 정보 표시
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                // 파일 버전
                child: FileBlock(
                    identifier: otaDevice.identifier, otaDevice: otaDevice),
              ),
              Expanded(
                flex: 1,
                // 디바이스 버전
                child: DeviceBlodk(
                    identifier: otaDevice.identifier, otaDevice: otaDevice),
              ),
            ],
          ),
          SizedBox(height: 20),
          // 메시지 텍스트
          MessageText(identifier: otaDevice.identifier, otaDevice: otaDevice),
          SizedBox(height: 20),
          // 프로그래스 바
          ProgressBar(identifier: otaDevice.identifier),
        ],
      ),
    );
  }
}

/// 파일 버전 표시 블럭
class FileBlock extends StatelessWidget {
  final String identifier;
  final OtaDevice otaDevice;
  const FileBlock({@required this.identifier, @required this.otaDevice});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OtaCubit, OtaState>(
      buildWhen: (previous, current) =>
          (current is OtaFileVersionStatus && current.identifier == identifier),
      builder: (context, state) {
        OtaFileVersionStatus status = state is OtaFileVersionStatus
            ? state
            : OtaFileVersionStatus(
                identifier: identifier, header: OtaFileHeader(data: null));
        print('FileBlock build: ${state.toString()}');
        return Column(
          children: [
            SelectButton(identifier: identifier, otaDevice: otaDevice),
            Field(label: 'Image ID', value: status.header.imageIdentifier),
            Field(label: 'Build version', value: status.header.buildVersion),
            Field(label: 'Stack version', value: status.header.stackVersion),
            Field(
                label: 'Hardware version',
                value: status.header.hardwareVersion),
            Field(
                label: 'Manufacturer ID',
                value: status.header.manufacturerIdentifier),
            Field(label: 'File ID', value: status.header.fileIdeitifier),
            Field(label: 'Header version', value: status.header.headerVersion),
            Field(label: 'Header length', value: status.header.headerLength),
            Field(
                label: 'Header field control',
                value: status.header.headerFieldControl),
            Field(label: 'Header string', value: status.header.headerString),
            Field(
                label: 'Total OTA file size',
                value: status.header.totalImageSize),
          ],
        );
      },
    );
  }
}

/// 디바이스 버전 표시 블럭
class DeviceBlodk extends StatelessWidget {
  final String identifier;
  final OtaDevice otaDevice;
  const DeviceBlodk({@required this.identifier, @required this.otaDevice});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OtaCubit, OtaState>(
      buildWhen: (previous, current) => (current is OtaDeviceVersionStatus &&
          current.identifier == identifier),
      builder: (context, state) {
        OtaDeviceVersionStatus status = state is OtaDeviceVersionStatus
            ? state
            : OtaDeviceVersionStatus(
                identifier: identifier,
                otaDeviceHeader: OtaDeviceHeader(data: null));
        print('DeviceBlodk build: ${state.toString()}');
        return Column(
          children: [
            UpdateButton(identifier: identifier, otaDevice: otaDevice),
            Field(
                label: 'Image ID',
                value: status.otaDeviceHeader.imageIdentifier),
            Field(
                label: 'Build version',
                value: status.otaDeviceHeader.buildVersion),
            Field(
                label: 'Stack version',
                value: status.otaDeviceHeader.stackVersion),
            Field(
                label: 'Hardware version',
                value: status.otaDeviceHeader.hardwareVersion),
            Field(
                label: 'Manufacturer ID',
                value: status.otaDeviceHeader.manufacturerIdentifier),
            // 배터리 레벨은 가변하기 때문에 따로 위젯을 만듦
            BatteryLevel(identifier: identifier, otaDevice: otaDevice),
          ],
        );
      },
    );
  }
}

/// OTA 파일 선택 버튼
/// - 이네이블/디세이블을 위해서 따로 위젯을 만듦
/// - 이네이블: 업데이트 중이 아닐 때
class SelectButton extends StatelessWidget {
  final String identifier;
  final OtaDevice otaDevice;
  const SelectButton({@required this.identifier, @required this.otaDevice});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OtaCubit, OtaState>(
      buildWhen: (previous, current) =>
          (current is OtaUpdateStatus && current.identifier == identifier),
      builder: (context, state) {
        return RaisedButton(
          child: Text('OTA FILE SELECT'),
          onPressed: state is OtaUpdateStatus &&
                  state.state == OtaUpdatingState.Updating
              ? null
              : () async {
                  FilePickerResult result =
                      await FilePicker.platform.pickFiles();
                  if (result != null) {
                    otaDevice.getFileVersion(result.files.single.path);
                  }
                },
        );
      },
    );
  }
}

/// 업데이트 버튼
/// - 이네이블/디세이블을 위해서 따로 위젯을 만듦
/// - 이네이블: RoEmService OtaService가 있고, OTA 파일 선택했으며, OTA 파일 버전이
///             디바이스 버전보다 높거나 같을 때, 배터리 충전 레벨이 30이상이거나
///             충전중일 때, 업데이트 중이 아닐 때
class UpdateButton extends StatelessWidget {
  final String identifier;
  final OtaDevice otaDevice;
  const UpdateButton({@required this.identifier, @required this.otaDevice});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OtaCubit, OtaState>(
      buildWhen: (previous, current) =>
          (current is OtaUpdatableStatus && current.identifier == identifier),
      builder: (context, state) {
        return RaisedButton(
          child: Text('UPDATE'),
          onPressed: otaDevice.isUpdatable
              ? () {
                  otaDevice.updateDevice();
                }
              : null,
        );
      },
    );
  }
}

/// 배터리 레벨 표시 위젯
/// - QcView에서처럼 RoEmService를 통해서 일정 시간마다 배터리 및 기타 정보가 송신
///   된다. 그 때마다 배터리 정보를 업데이트 하기 위함
/// - 충전 중일 때에는 레벨 표시가 %로 나오지 않기 때문에 '충전 중'이라 표시 함
class BatteryLevel extends StatelessWidget {
  final String identifier;
  final OtaDevice otaDevice;
  const BatteryLevel({@required this.identifier, @required this.otaDevice});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OtaCubit, OtaState>(
      buildWhen: (previous, current) =>
          (current is OtaBatteryStatus && current.identifier == identifier),
      builder: (context, state) {
        if (state is OtaBatteryStatus) {
          return Field(
            label: 'Battery Level',
            value: state.isCharging
                ? '충전 중'
                : '${state.batteryLevel.toString()} %',
          );
        }
        return Container();
      },
    );
  }
}

/// 메시지 텍스트
/// 각 상황에 맞는 메시지 출력
/// 전송된 메시지 출력
class MessageText extends StatelessWidget {
  final String identifier;
  final OtaDevice otaDevice;
  const MessageText({@required this.identifier, @required this.otaDevice});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OtaCubit, OtaState>(
      builder: (context, state) {
        String str = '';
        if (state is OtaMessage && state.identifier == identifier) {
          str = state.message;
        } else if (state is OtaProgressStatus &&
            state.identifier == identifier) {
          str = '펌웨어 업데이트 진행중입니다.';
        } else {
          if (otaDevice.isUpdatable)
            str = '펌웨어 업데이트가 가능합니다.';
          else if (!otaDevice.isRoEmServiceExists)
            str = '로임시스템 디바이스가 아닙니다.';
          else if (!otaDevice.isOTAServiceExists)
            str = 'OTA 서비스가 없는 디바이스입니다.';
          else if (!otaDevice.updateFileSelected)
            str = '업데이트 파일을 선택해 주십시오.';
          else if (!otaDevice.isNewerVersion)
            str = '선택한 파일 버전이 디바이스에 설치된 것보다 이전 버전입니다.';
          else if (otaDevice.batteryLevel < 30)
            str = '배터리가 30% 이상 충전되어야 합니다.';
          else
            str = '알 수 없는 오류입니다.';
        }

        return Center(child: Text(str));
      },
    );
  }
}

/// 업데이트 진행 바
class ProgressBar extends StatelessWidget {
  final String identifier;
  const ProgressBar({@required this.identifier});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OtaCubit, OtaState>(
      buildWhen: (previous, current) =>
          current is OtaProgressStatus && current.identifier == identifier,
      builder: (context, state) {
        if (state is OtaProgressStatus && state.identifier == identifier) {
          print('Progress: ${state.progress}');
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            child: Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 32.0,
                  child: LinearProgressIndicator(
                    value: state.progress != null ? state.progress : 0.0,
                  ),
                ),
                SizedBox(
                  height: 32.0,
                  child: Center(
                    child: Text(
                      '${state.progress != null ? (state.progress * 100).floor() : 0}%',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Container();
      },
    );
  }
}
