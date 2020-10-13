import 'package:cubit_ble2/cubit/char_cubit.dart';
import 'package:cubit_ble2/cubit/cubit_global.dart';
import 'package:cubit_ble2/cubit/ota_cubit.dart';
import 'package:cubit_ble2/cubit/qc_cubit.dart';
import 'package:cubit_ble2/cubit/scan_cubit.dart';
import 'package:cubit_ble2/pages/device_view_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:toast/toast.dart';

/// 검색 및 검색 디바이스 목록을 표시
/// UI 설명
/// Scaffold를 사용하였으며
///   AppBar에 App의 타이틀을 표시
///   body에는 검색된 디바이스 목록을 표시
///   floatingActionButton에 검색 기능을 담았다.
/// BlocProvider가 생성한 위치의 Widget과 life cycle을 함께 하기 때문에
/// CharCubit, QcCubit, OtaCubit을 이곳에서 생성해야 한다.
/// - 편의상 main에서 모든 프로바이더를 생성했다.
class DeviceScanPage extends StatelessWidget {
  final String role;
  const DeviceScanPage({@required this.role});

  @override
  Widget build(BuildContext context) {
    print('DeviceScanPage build');
    context.bloc<ScanCubit>().init();
    return WillPopScope(
      child: Scaffold(
        appBar: AppBar(title: Text(role)),

        /// 바디를 Stack으로 감싼 이유?
        /// 디바이스를 탭하면 연결을 시도 함
        /// 연결 중임을 표시하기 위해 회전 써클을 화면 중앙에 표시하기 위함
        body: Stack(
          alignment: Alignment.center,
          children: [
            ScanListView(role: role), // 검색된 목룍 표시
            ConnectCircleWidget(role: role), // 연결 중일 때 써클 표시
          ],
        ),
        // 스캔 시작 및 멈춤 버튼
        floatingActionButton: ScanButtonWidget(),
      ),
      onWillPop: () async {
        // 페이지를 벗어날 때 스캔 멈춤 - 연결된 모든 링크를 끊는다.
        await context.bloc<ScanCubit>().stopScan();
        await context.bloc<ScanCubit>().disconnectAll();
        return true;
      },
    );
  }
}

/// 연결 중 표시 써클 및 연결되었을 때 다음 페이지로 이동
/// BLE 상태가 connecting 일때 화면에 표시한다.
/// 상태가 connected로 변하면 DeviceServicePage로 이동한다.
/// 연결 실패시 화면에 Disconnected를 표시한다.
class ConnectCircleWidget extends StatelessWidget {
  final String role;
  const ConnectCircleWidget({@required this.role});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ScanCubit, ScanState>(
      listenWhen: (before, current) => (current is ConnectionStatus),
      listener: (context, state) {
        if (state is ConnectionStatus) {
          if (state.status == PeripheralConnectionState.connected) {
            // 페이지 이동
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DeviceViewPage(role: role),
              ),
            );
          }
        }
      },
      buildWhen: (before, current) => (current is ConnectionStatus),
      builder: (context, state) {
        print('scan_page, waitingCircleView: $state');
        if (state is ConnectionStatus) {
          if (state.status == PeripheralConnectionState.connecting) {
            return CircularProgressIndicator();
          }
        }
        return Container();
      },
    );
  }
}

/// 스캔 버튼 위젯
/// 스캔 버튼은 BLE 상태에 따라 각각 다르게 동작한다.
/// BLE 파워가 오프되어 있거나, 퍼미션이 없을 때에는 스캔 버튼을 표시하지 않음
/// 스캔 가능할 때에는 - 스캔 아이콘
/// 스캔 중일 때에는 - 멈춤 아이콘
class ScanButtonWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ScanCubit, ScanState>(
      buildWhen: (before, current) {
        // 처음 한 번은 조건에 상관없이 수행한다.
        // 따라서 이 부분을 신경써서 코딩해야 한다.
        return (current is BleStatus);
      },
      builder: (context, state) {
        print('scan_page, scanButton: $state');
        if (state is BleStatus) {
          if (state.isPermissionGranted && state.isPowerOn) {
            return FloatingActionButton(
              child: Icon(
                  state.isScanning ? Icons.stop : Icons.bluetooth_searching),
              onPressed: () {
                if (state.isScanning)
                  context.bloc<ScanCubit>().stopScan();
                else
                  context.bloc<ScanCubit>().startScan();
              },
            );
          } else {
            return Container();
          }
        } else {
          return Container();
        }
      },
    );
  }
}

/// 검색 목록을 표시하는 위젯
/// - 연결된 목록을 먼저 표시하고
/// - 검색된 목록을 뒤에 표시한다.
class ScanListView extends StatelessWidget {
  final String role;
  ScanListView({this.role}) {
    print('ScanListView Create');
  }

  @override
  Widget build(BuildContext context) {
    print('ScanListView build');
    // 내부 사용 변수
    // - 페이지로 진입 헀을 때만 스캔하기 위해서
    // - CHAR, QC, OTA 페이지에서 돌아왔을 때에는 자동 스캔을 하지 않기 위함
    int buildCount = 0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: BlocConsumer<ScanCubit, ScanState>(
        listener: (context, state) {
          if (state is BleStatus) {
            if (state.canScanning && buildCount++ == 0) {
              // 스캔이 가능하다고 판단되면 스캔 시작
              context.bloc<ScanCubit>().startScan();
            }
          } else if (state is ScanMessageStatus) {
            Toast.show(
              '${state.message}',
              context,
              duration: Toast.LENGTH_LONG,
              gravity: Toast.BOTTOM,
            );
          } else if (state is ConnectionStatus) {
            if (state.status == PeripheralConnectionState.connected) {
              // 새로운 디바이스가 연결 되었다면. 롤에 맞게 Cubit 추가
              if (role == 'CHAR') {
                CubitGlobal.charCubit.getDevice(state.peripheral);
              } else if (role == 'QC') {
                CubitGlobal.qcCubit.getDevice(state.peripheral);
              } else if (role == 'OTA') {
                CubitGlobal.otaCubit.getDevice(state.peripheral);
              }
            }
          }
        },
        buildWhen: (before, current) =>
            (current is DeviceListStatus || current is ConnectionStatus),
        builder: (context, state) {
          // 화면에 표시할 목록
          List<ShowList> list = [];

          bool isConnected(Peripheral peripheral) {
            for (var v in context.bloc<ScanCubit>().peripherals) {
              if (v.identifier == peripheral.identifier) return true;
            }
            return false;
          }

          bool isExists(Peripheral peripheral) {
            for (var v in list) {
              if (v.peripheral.identifier == peripheral.identifier) return true;
            }
            return false;
          }

          List<Peripheral> connectedDevices = (role == 'CHAR')
              ? context.bloc<CharCubit>().connectedDevices
              : (role == 'QC')
                  ? context.bloc<QcCubit>().connectedDevices
                  : context.bloc<OtaCubit>().connectedDevices;
          List<ScanResult> scanResults = context.bloc<ScanCubit>().scanResults;

          // 연결된 목록
          for (var v in connectedDevices) {
            list.add(ShowList(v, '-'));
          }
          // 검색된 목록
          for (var v in scanResults) {
            if (!isExists(v.peripheral))
              list.add(ShowList(v.peripheral, v.rssi.toString()));
          }

          // 화면에 표시할 목록 수
          print('ScanListView length: ${list.length}');

          return ListView.builder(
            itemBuilder: (context, index) {
              return ListTile(
                leading: Icon(Icons.bluetooth,
                    color: isConnected(list[index].peripheral)
                        ? Colors.blueAccent
                        : Colors.grey),
                title: Text(list[index].peripheral.name == null
                    ? 'No name'
                    : list[index].peripheral.name),
                subtitle: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${list[index].peripheral.identifier}'),
                    Text('${list[index].rssi} RSSI'),
                  ],
                ),
                onTap: () async {
                  // 스캔 멈춤
                  await context.bloc<ScanCubit>().stopScan();
                  // 연결
                  if (isConnected(list[index].peripheral)) {
                    // 이미 연결되었으므로 페이지 이동
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DeviceViewPage(role: role),
                      ),
                    );
                  } else {
                    // 연결
                    await context.bloc<ScanCubit>().connect(
                          role,
                          list[index].peripheral,
                        );
                  }
                },
              );
            },
            itemCount: list.length,
          );
        },
      ),
    );
  }
}

/// 화면 표시 리스트를 만들기위한 기본 클래스
class ShowList {
  final Peripheral peripheral;
  final String rssi;
  ShowList(this.peripheral, this.rssi);
}
