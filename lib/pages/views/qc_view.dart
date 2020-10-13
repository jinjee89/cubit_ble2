import 'package:cubit_ble2/cubit/qc_cubit.dart';
import 'package:cubit_ble2/pages/ui/common_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// QCView 위젯
/// UI 구성
/// - 디바이스에서 전송 받은 정보 표시
/// - 디바이스로 보낼 커맨드 설정 표시
/// 서비스 디스커버 중에는 웨이트 써클 표시
/// 서비스 디스커버 완료 후 메인 뷰 호출
class QCView extends StatelessWidget {
  final Peripheral peripheral;
  const QCView({this.peripheral});

  @override
  Widget build(BuildContext context) {
    // 연결된 디바이스 획득 및 디스커버링
    QcDevice qcDevice = context.bloc<QcCubit>().getDevice(peripheral);
    qcDevice.discovers();

    return BlocBuilder<QcCubit, QcState>(
      buildWhen: (previous, current) {
        print('QCView current: $current');
        return (current is QcDiscoverStatus &&
            current.identifier == qcDevice.identifier);
      },
      builder: (context, state) {
        if (!qcDevice.isServiceDiscovered) {
          return Center(child: CircularProgressIndicator());
        } else if (!qcDevice.isRoEmServiceExists) {
          return Center(child: Text('RoEm Service is not supported.'));
        } else {
          print('QCView startMonitoring');
          qcDevice.startMonitoring();
          return ViewDetail(qcDevice: qcDevice);
        }
      },
    );
  }
}

/// 메인 뷰 클래스
class ViewDetail extends StatelessWidget {
  final QcDevice qcDevice;
  const ViewDetail({@required this.qcDevice});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 20),
          QCBlock(identifier: qcDevice.identifier),
          SizedBox(height: 20),
          CommandBlock(qcDevice: qcDevice),
        ],
      ),
    );
  }
}

/// 디바이스에서 전송 받은 데이터 표시
class QCBlock extends StatelessWidget {
  final String identifier;
  const QCBlock({@required this.identifier});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QcCubit, QcState>(
      buildWhen: (previous, current) =>
          (current is QcStatus && current.identifier == identifier),
      builder: (context, state) {
        if (state is QcStatus) {
          print('QCBlock build: ${state.toString()}');
          return Column(
            children: [
              Field(
                  label: 'Product ID', value: (state).productID, rightFlex: 3),
              Field(
                  label: 'QN FW version',
                  value: (state).qnFwVersion,
                  rightFlex: 3),
              Field(
                  label: 'HW version', value: (state).hwVersion, rightFlex: 3),
              Field(
                  label: 'MSP FW version',
                  value: (state).mspFwVersion,
                  rightFlex: 3),
              Field(
                  label: 'Battery voltage',
                  value: (state).batteryVoltage,
                  rightFlex: 3),
              Field(
                  label: 'USB voltage',
                  value: (state).usbVoltage,
                  rightFlex: 3),
              Field(
                  label: 'Water voltage',
                  value: (state).waterVoltage,
                  rightFlex: 3),
              Field(label: '온도', value: (state).temperature, rightFlex: 3),
              Field(label: 'MSP 상태', value: (state).mspStatus, rightFlex: 3),
              Field(label: '에러 코드', value: (state).errorCode, rightFlex: 3),
              Field(
                  label: 'Battery 상태',
                  value: (state).batteryStatus,
                  rightFlex: 3),
              Field(
                  label: 'Battery 용량',
                  value: (state).batteryCapacity,
                  rightFlex: 3),
              Field(label: 'RSSI', value: (state).rssi, rightFlex: 3),
              Field(label: 'BPS', value: (state).bps, rightFlex: 3),
              Field(
                  label: 'Sent packets',
                  value: (state).sentPackets,
                  rightFlex: 3),
              Field(
                  label: 'Fail packets',
                  value: (state).failPackets,
                  rightFlex: 3),
              Field(
                  label: 'Skip packets',
                  value: (state).skipPackets,
                  rightFlex: 3),
              Field(
                  label: 'Mac address',
                  value: (state).macAddress,
                  rightFlex: 3),
              Field(
                  label: 'Boot count', value: (state).bootCount, rightFlex: 3),
            ],
          );
        }
        return Container();
      },
    );
  }
}

/// 제어 명령 설정 및 전송 버튼 표시
class CommandBlock extends StatelessWidget {
  final QcDevice qcDevice;
  const CommandBlock({@required this.qcDevice});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QcCubit, QcState>(
      buildWhen: (previous, current) => (current is CommandStatus &&
          current.identifier == qcDevice.identifier),
      builder: (context, state) {
        // 이곳에 조건문을 걸면 null을 전송하는 경우가 발생하여 UI가 화면에서
        // 사라지는 현상이 나타날 수 있다.
        return Column(
          children: [
            Wrap(
              direction: Axis.horizontal,
              alignment: WrapAlignment.center,
              spacing: 18.0, // gap between adjacent chips
              runSpacing: 4.0, // gap between lines
              children: [
                DropDownButton(
                  label: '링크 번호',
                  value: qcDevice.linkIndex,
                  maxValue: 2,
                  onChanged: (value) => qcDevice.linkIndex = value,
                ),
                DropDownButton(
                  label: '장비 부착 여부',
                  value: qcDevice.deviceAttachLevel,
                  maxValue: 2,
                  onChanged: (value) => qcDevice.deviceAttachLevel = value,
                ),
                DropDownButton(
                  label: '근파워 레벨',
                  value: qcDevice.powerLevel,
                  maxValue: 10,
                  onChanged: (value) => qcDevice.powerLevel = value,
                ),
                TextInput(
                  label: '터치 보정',
                  value: qcDevice.touchCalibration,
                  onChanged: (value) =>
                      qcDevice.touchCalibration = int.parse(value),
                ),
              ],
            ),
            Wrap(
              direction: Axis.horizontal,
              alignment: WrapAlignment.center,
              spacing: 18.0, // gap between adjacent chips
              runSpacing: 4.0, // gap between lines
              children: [
                SwitchWidget(
                  label: '레코딩 상태',
                  value: qcDevice.recordState,
                  onChanged: (value) => qcDevice.recordState = value,
                ),
                SwitchWidget(
                  label: 'Brown Reset',
                  value: qcDevice.brownReset,
                  onChanged: (value) => qcDevice.brownReset = value,
                ),
                SwitchWidget(
                  label: '디버그 출력',
                  value: qcDevice.debugPrint,
                  onChanged: (value) => qcDevice.debugPrint = value,
                ),
                SwitchWidget(
                  label: '명령 자동 전송',
                  value: qcDevice.autoSendCommand,
                  onChanged: (value) => qcDevice.autoSendCommand = value,
                ),
              ],
            ),
            // 커맨드
            CommandWidget(
              count: qcDevice.commandCount,
              onPressed: () => qcDevice.sendCommand(),
            ),
          ],
        );
      },
    );
  }
}

/// 드롭다운 콤보박스 생성 위젯
class DropDownButton extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;
  final Function onChanged;
  const DropDownButton({this.label, this.value, this.maxValue, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      child: Row(
        children: [
          Text(label),
          Expanded(
            child: ButtonTheme(
              alignedDropdown: true,
              child: DropdownButton(
                isExpanded: true,
                value: value,
                items: List<int>.generate(maxValue + 1, (i) => i)
                    .map<DropdownMenuItem<int>>((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        value.toString(),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 입력 테스트 위젯
class TextInput extends StatefulWidget {
  final String label;
  final int value;
  final Function onChanged;
  const TextInput({this.value, this.label, this.onChanged});

  @override
  _TextInputState createState() => _TextInputState();
}

class _TextInputState extends State<TextInput> {
  TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      child: Row(
        children: [
          Text(widget.label),
          Expanded(
            child: TextField(
              keyboardType: TextInputType.number,
              textAlign: TextAlign.end,
              controller: _controller,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '보정값 입력',
              ),
              onChanged: (value) {
                widget.onChanged(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 라벨을 포함한 스위치 위젯
class SwitchWidget extends StatelessWidget {
  final String label;
  final bool value;
  final Function onChanged;
  const SwitchWidget({this.label, this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// 커맨드 버튼 및 커맨드 전송 회수 표시 위젯
class CommandWidget extends StatelessWidget {
  final int count;
  final Function onPressed;
  const CommandWidget({this.count, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RaisedButton(
          child: Text('명령 전송'),
          onPressed: onPressed,
        ),
        SizedBox(width: 20),
        TextLabel(
          label: '명령 전송 카운트',
          count: count,
        ),
      ],
    );
  }
}

/// 텍스트 라벨 위젯 - 커맨드 위젯에서 사용
class TextLabel extends StatelessWidget {
  final String label;
  final int count;
  const TextLabel({this.label, this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      child: Row(
        children: [
          Text(label),
          Expanded(
            child: Text(
              count.toString(),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
