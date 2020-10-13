import 'package:cubit_ble2/cubit/char_cubit.dart';
import 'package:cubit_ble2/cubit/cubit_global.dart';
import 'package:cubit_ble2/cubit/ota_cubit.dart';
import 'package:cubit_ble2/cubit/qc_cubit.dart';
import 'package:cubit_ble2/cubit/scan_cubit.dart';
import 'package:cubit_ble2/pages/device_scan_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// BlocProvider를 다른 페이지에서도 사용하려면 아래와 같이 MaterialApp 보다
/// 상위에서 생성해야 한다.
/// 앱 전반에서 사용할 모든 큐빗 생성 및 프로바이딩 제공
void main() {
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<ScanCubit>(create: (context) => CubitGlobal.scanCubit),
        BlocProvider<CharCubit>(create: (context) => CubitGlobal.charCubit),
        BlocProvider<QcCubit>(create: (context) => CubitGlobal.qcCubit),
        BlocProvider<OtaCubit>(create: (context) => CubitGlobal.otaCubit),
      ],
      child: MyApp(),
    ),
  );
}

/// CUBIT 패턴으로 구현
/// 사용한 패키지
///   flutter_bloc: ^6.0.5 - bloc provider 사용을 위한 패키지
///   bloc: ^6.0.3 - bloc cubit(?) 사용을 위한 패키지
///   flutter_ble_lib: ^2.3.0 - 블루투스 라이브러리
///   permission_handler: ^5.0.1+1 - 퍼미션 지원 라이브러리
/// Cubit - 3개의 Cubit으로 구성
/// 1. ScanCubit - 디바이스 검색과 선택된 디바이스 연결 담당
/// 2. CharCubit - 연결된 디바이스의 서비스 발견과 각 캐릭터리스틱의 통신 담당
///    QcCubit, OtaCubit
///
/// Cubit 패턴 간략 설명
/// Cubit은 2개의 클래스로 구성 됨 - Cubit과 State
/// Cubit 클래스는 로직 담당 - 데이터 생성 및 저장역할
/// State 클래스는 UI에게 어떤 데이터가 변경되었는지 구분 및 전달하는 역할
/// Cubit을 사용하기
/// BlocProvider 현재 위젯의 가장 상위에서(반드시는 아님) 생성하여 하위 위젯들이
/// 접근할 수 있도록 하는 Provider 생성하는 것이 목적임
/// BlocProvider는 로직을 담당하는 Cubit 클랫를 생성한다.
///
/// 프로바이더를 사용할 때에는
/// BlocBuilder와 BlocComsumer를 통해 사용할 수 있다.
/// BlocBuilder는 반드시 위젯을 리턴해야 하는 상황에서 사용
/// BlocConsumer는 listener를 통해 위젯을 생성하지 않는(예를 들어 Toast와 같이
/// 메시지를 출력할 때 등) 상황에서 사용할 수 있는 차이점이 있다.
/// BlocBuilder와 BlocConsumer는 When이라는 조건문을 사용할 수 있는데(Initialize는
/// 조건문에 상관 없이 통과된다. 이점 주의 할 것)
/// 위 조건에 따라 필터링 할 수 있으므로 상황에 따라 위젯을 잘 분리하면 불필요한
/// 위젯 빌드를 막을 수 있다.
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoEm BLE-2',
      home: SelectRoleWidget(),
    );
  }
}

/// 목적에 맞는 선택 페이지
/// SCAN - 서비스, 캐릭터리스틱 목록. 각 캐릭터리스틱의 통신 수행
/// QC   - 내부 생산용 목적
/// OTA  - FW 업데이트 목적
class SelectRoleWidget extends StatelessWidget {
  // 검색 페이지로 이동
  void gotoDeviceScanPage(context, role) {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => DeviceScanPage(role: role)));
  }

  // Scaffold 페이지와
  // 중앙에 3개의 버튼을 생성한다.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('RoEm BLE-2')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MyRoundButton(
            title: 'CHAR',
            onPressed: () => gotoDeviceScanPage(context, 'CHAR'),
          ),
          SizedBox(height: 20.0),
          MyRoundButton(
            title: 'QC',
            onPressed: () => gotoDeviceScanPage(context, 'QC'),
          ),
          SizedBox(height: 20.0),
          MyRoundButton(
            title: 'OTA',
            onPressed: () => gotoDeviceScanPage(context, 'OTA'),
          ),
        ],
      ),
    );
  }
}

/// 선택 버튼 외형 - 라운드 형태의 버튼
class MyRoundButton extends StatelessWidget {
  final title;
  final onPressed;
  const MyRoundButton({
    @required this.title,
    @required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
            minWidth: double.infinity, maxHeight: 56.0, minHeight: 56.0),
        child: FlatButton(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            side: BorderSide(color: Colors.grey),
          ),
          color: Colors.grey[200],
          child: Text(
            title,
            textScaleFactor: 1.2,
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
