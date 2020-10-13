import 'package:cubit_ble2/cubit/char_cubit.dart';
import 'package:cubit_ble2/utils/array_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:toast/toast.dart';

/// 연결된 디바이스의 서비스, 캐릭터리스틱, 디스크립터를 확인할 수 있는 뷰
/// 3개의 선택 콤보박스를 통해, 서비스, 캐릭터리스틱, 디스크립터를 선택할 수 있다.
/// 선택된 캐릭터리스틱은 읽기/쓰기/노티/ 정보에 따라 버튼이 활성화된다.
class CharView extends StatelessWidget {
  final Peripheral peripheral;
  const CharView({@required this.peripheral});

  @override
  Widget build(BuildContext context) {
    // 페이지 생성시
    // 연결된 디바이스 획득 및 디스커버링
    CharDevice charDevice = context.bloc<CharCubit>().getDevice(peripheral);
    charDevice.discovers();

    // 스크롤이 되는지 모르겠다.
    // 내 예상은 키보드가 올라왔을 때 스크롤바가 생겨서 밀려 올라가는 것이었는데
    // 예상과는 다르게 스크롤이 생기지 않았다.
    return BlocConsumer<CharCubit, CharState>(
      listener: (context, state) {
        if (state is CharMessageStatus &&
            state.identifier == charDevice.identifier) {
          Toast.show(
            '${state.message}',
            context,
            duration: Toast.LENGTH_LONG,
            gravity: Toast.BOTTOM,
          );
        }
      },
      buildWhen: (previous, current) => (current is ServiceStatus &&
          current.identifier == charDevice.identifier),
      builder: (context, state) {
        // 연결된 디바이스 획득 및 디스커버링
        CharDevice charDevice = context.bloc<CharCubit>().getDevice(peripheral);

        // 컬럼과 같이 가변 길이를 가지는 뷰에서 스크롤이 생성되도록 하기위해
        // SingleChildScrollView를 사용한다.
        return SingleChildScrollView(
          padding: EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 서비스 콤보 박스
              MakeDropdownButton(
                title: 'Services',
                value: charDevice.selectedService,
                list: charDevice.services,
                onChanged: (c) => charDevice.selectedService = c,
              ),
              // 캐릭터리스틱스 콤보 박스
              MakeDropdownButton(
                title: 'Characteristics',
                value: charDevice.selectedCharacteristic,
                list: charDevice.characteristics,
                onChanged: (c) => charDevice.selectedCharacteristic = c,
              ),
              // 디스크립터 콤보 박스
              MakeDropdownButton(
                title: 'Descriptors',
                value: charDevice.selectedDescriptor,
                list: charDevice.descriptors,
                onChanged: (c) => charDevice.selectedDescriptor = c,
              ),
              SizedBox(height: 20.0),
              // 캐릭터리스틱 읽기/쓰기
              MakeCharateristicProperty(
                charDevice: charDevice,
                characteristic: charDevice.selectedCharacteristic,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 콤보 박스 생성
/// 서비스, 캐릭터리스틱, 디스크립터 3종 지원
class MakeDropdownButton extends StatelessWidget {
  final String title;
  final dynamic value;
  final List<dynamic> list;
  final Function onChanged;

  MakeDropdownButton({
    @required this.title,
    @required this.value,
    @required this.list,
    @required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kMinInteractiveDimension,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
            ),
            flex: 1,
          ),
          Expanded(
            flex: 2,
            child: DropdownButton(
              isExpanded: true,
              items: list.map((item) {
                return DropdownMenuItem<dynamic>(
                  value: item,
                  child: Text(item is Service
                      ? item.uuid.toString()
                      : item is Characteristic
                          ? item.uuid.toString()
                          : item is Descriptor
                              ? item.uuid.toString()
                              : ''),
                );
              }).toList(),
              value: value,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// 캐릭터 리스틱의 읽기/쓰기/노티를 지원하기 위한 UI
class MakeCharateristicProperty extends StatelessWidget with ArrayUtils {
  final CharDevice charDevice;
  final Characteristic characteristic;
  const MakeCharateristicProperty({
    @required this.charDevice,
    @required this.characteristic,
  });

  @override
  Widget build(BuildContext context) {
    TextEditingController _text1 = TextEditingController(
        text: toHexString(array: charDevice.readData, len: 20));
    TextEditingController _text2 = TextEditingController(
        text: toHexString(array: charDevice.writeData, len: 20));
    TextEditingController _text3 = TextEditingController();

    return BlocConsumer<CharCubit, CharState>(
      listener: (context, state) {
        if (state is CharacteristicStatus &&
            state.identifier == charDevice.identifier) {
          _text1.text = toHexString(array: charDevice.readData, len: 20);
          _text2.text = toHexString(array: charDevice.writeData, len: 20);
        } else if (state is NotifyStatus &&
            state.identifier == charDevice.identifier) {
          _text3.text = toHexString(array: state.data, len: 20);
        }
      },
      buildWhen: (previous, current) => (current is ServiceStatus &&
          current.identifier == charDevice.identifier),
      builder: (context, state) {
        return Column(
          children: [
            // READ
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text1,
                    readOnly: true,
                  ),
                ),
                SizedBox(width: 10.0),
                RaisedButton(
                  child: Text('READ'),
                  onPressed: characteristic != null && characteristic.isReadable
                      ? () => charDevice.read(characteristic)
                      : null,
                ),
              ],
            ),
            // WRITE
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text2,
                  ),
                ),
                SizedBox(width: 10.0),
                RaisedButton(
                  child: Text('WRITE'),
                  onPressed: characteristic != null &&
                          (characteristic.isWritableWithResponse ||
                              characteristic.isWritableWithoutResponse)
                      ? () {
                          charDevice.write(
                              characteristic, toArray(_text2.text));
                          FocusScope.of(context).unfocus();
                        }
                      : null,
                ),
              ],
            ),
            // NOTIFY
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text3,
                    readOnly: true,
                  ),
                  flex: 4,
                ),
                SizedBox(width: 10.0),
                Expanded(
                  child: BpsWidget(
                    identifier: charDevice.identifier,
                  ),
                  flex: 1,
                ),
                SizedBox(width: 10.0),
                RaisedButton(
                  child: Text('NOTIFY'),
                  onPressed: characteristic != null &&
                          (characteristic.isNotifiable ||
                              characteristic.isIndicatable)
                      ? () {
                          charDevice.isMonitoring(characteristic)
                              ? charDevice.stopMonitoring(characteristic)
                              : charDevice.startMonitoring(characteristic);
                        }
                      : null,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// BPS 표시 위젯
class BpsWidget extends StatelessWidget {
  final String identifier;
  const BpsWidget({@required this.identifier});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CharCubit, CharState>(
      buildWhen: (previous, current) =>
          (current is BpsStatus && current.identifier == identifier),
      builder: (context, state) {
        if (state is BpsStatus) {
          return Text('BPS: ${state.bps}');
        }
        return Text('BPS:');
      },
    );
  }
}
