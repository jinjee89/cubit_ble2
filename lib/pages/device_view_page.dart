import 'package:cubit_ble2/cubit/scan_cubit.dart';
import 'package:cubit_ble2/pages/views/char_view.dart';
import 'package:cubit_ble2/pages/views/ota_view.dart';
import 'package:cubit_ble2/pages/views/qc_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:toast/toast.dart';

/// UI - Scaffold 사용
/// 탭사용
/// - 여러개를 연결했을 때 디바이스간 이동을 위해서
/// - 탭은 DefaultTabController를 사용했으며 flutter 예제를 따라 했음
class DeviceViewPage extends StatelessWidget {
  final String role;
  const DeviceViewPage({@required this.role});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ScanCubit, ScanState>(
      listenWhen: (previous, current) => current is ConnectionStatus,
      listener: (context, state) async {
        // BLE 연결이 끊기면 페이지 삭제, 모든 연결이 끊기면 이전 페이지로 돌아가기
        if (state is ConnectionStatus) {
          if (state.status == PeripheralConnectionState.disconnected) {
            Toast.show(
                "Device(${state.peripheral.name != null ? state.peripheral.name : state.peripheral.identifier.toString()}) was disconnected!",
                context,
                duration: Toast.LENGTH_LONG,
                gravity: Toast.BOTTOM);
          }
          // 연결된 디바이스가 없다면 이전 페이지로 돌아감
          if (context.bloc<ScanCubit>().peripherals.length == 0) {
            print('Navigator.pop');
            Navigator.pop(context);
          }
        }
      },
      buildWhen: (previous, current) => current is ConnectionStatus,
      builder: (context, state) {
        return ViewPages(role: role);
      },
    );
  }
}

class ViewPages extends StatelessWidget {
  final String role;
  const ViewPages({@required this.role});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        length: context.bloc<ScanCubit>().peripherals.length,
        child: Scaffold(
          appBar: AppBar(
            title: Text('$role'),
            // 탭 사용시 TabBar와 TabBarView가 쌍으로 동작한다.(예제에 따름)
            // 탭바는 앱바에 위치해야만 하는지는 모름.
            // 각 탭은 타이틀과 닫기 버튼으로 생성함
            // 닫기 버튼을 클릭하면 BLE 연결을 끊는다.
            bottom: TabBar(
                tabs: context.bloc<ScanCubit>().peripherals.map(
              (peripheral) {
                return Row(
                  children: [
                    ButtonTheme(
                      minWidth: 30,
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: FlatButton(
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                        ),
                        onPressed: () async {
                          // 블루투스 연결 끊기
                          // 연결이 끊기면 이 페이지를 다시 생성하면서 탭이 사라진다.
                          await peripheral.disconnectOrCancelConnection();
                        },
                      ),
                    ),
                    Text(
                      '${peripheral.name != null ? peripheral.name : peripheral.identifier.toString()}',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                );
              },
            ).toList()),
          ),
          // 각 롤에 맞게 바디를 생성한다.
          body: TabBarView(
            children: context.bloc<ScanCubit>().peripherals.map((peripheral) {
              if (role == 'CHAR') {
                return CharView(peripheral: peripheral);
              } else if (role == 'QC') {
                return QCView(peripheral: peripheral);
              } else if (role == 'OTA') {
                return OTAView(peripheral: peripheral);
              }
              return Center(child: Text('Unknown Role'));
            }).toList(),
          ),
        ));
  }
}
