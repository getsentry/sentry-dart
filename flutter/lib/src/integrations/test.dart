// @dart=2.11
import 'dart:async';

// import 'package:organization_name_app/data/firebase/firebase_manager.dart';
// import 'package:organization_name_app/data/firebase/force_update_info.dart';
// import 'package:organization_name_app/general/global.dart';
// import 'package:organization_name_app/general/operation_mode.dart';
// import 'package:organization_name_app/ui/pages/login_page.dart';
// import 'package:organization_name_app/ui/pages/start_page.dart';
// import 'package:organization_name_app/ui/shared_components/force_update_dialog.dart';
// import 'package:organization_name_app/ui/style/organization_name__color.dart';
// import 'package:organization_name_app/utils/organization_name_date_util.dart';
// import 'package:organization_name_app/utils/translate.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_localizations/flutter_localizations.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:package_info/package_info.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  await mainOperationMode();
}

Future<OperationMode> mainOperationMode() async {
  OperationMode operationMode = await setup();
  await _setupSentry(operationMode);
  return operationMode;
}

Future<OperationMode> setup() async {
  Future<bool> internalModeDetector = runZonedGuarded(_unhandledSetup, (Object error, StackTrace stack) {
    print('Internal mode flag is not present.');
  });

  bool hasInternalModeFlag = await internalModeDetector;

  if (hasInternalModeFlag == null) {
    hasInternalModeFlag = false;
  }

  _setOperationModeGlobal(hasInternalModeFlag);
  return OperationModeDetector(hasInternalModeFlag).mode;
}

String _setOperationModeGlobal(bool hasInternalModeFlag) =>
    Global().operationMode = OperationModeDetector(hasInternalModeFlag).mode.toString().split(".").last.toLowerCase();

Future<bool> _unhandledSetup() async {
  WidgetsFlutterBinding.ensureInitialized();
  return OperationModeDetector.isInternalMode();
}

Future _setupSentry(OperationMode operationMode) async {
  if (operationMode == OperationMode.PRODUCTION) {
    print("> App will start with Sentry Error Reporting");
    await SentryFlutter.init(
      (options) => options.dsn = 'https://REDACTED@sentry.io/REDACTED',
      appRunner: () => _start(operationMode),
    );
  } else {
    print("> App will start without Sentry Error Reporting when in DEBUG mode");

    await _start(operationMode);
  }
}

Future _start(OperationMode operationMode) async {
  await setupFirebase(operationMode);
  await Global().init();

  await Translate.init();

  PackageInfo packageInfo = await PackageInfo.fromPlatform();

  runApp(
    ProviderScope(
      child: OrganizationNameApp(
        packageInfo: packageInfo,
        operationMode: operationMode,
      ),
    ),
  );
}

Future<void> setupFirebase(OperationMode operationMode) async {
  if (operationMode != OperationMode.IDE) {
    await FirebaseManager.setUpFirebase(operationMode);
  }
}

class OrganizationNameApp extends StatelessWidget {
  PackageInfo packageInfo;
  String versionNumber;
  ForceUpdateInfo forceUpdateInfo;
  OperationMode operationMode;

  OrganizationNameApp({Key key, this.operationMode, this.packageInfo}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    versionNumber = packageInfo.version;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    if (operationMode == OperationMode.IDE) {
      return createMaterialApp(context);
    }

    Widget _onLoad() {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [OrganizationNameColor.dark_blue, OrganizationNameColor.other_blue, OrganizationNameColor.blue],
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseManager.getInstance().collection(FirebaseManager.FORCE_UPDATE_COLLECTION).doc(FirebaseManager.getDocumentToFetch()).snapshots(),
      builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _onLoad();
        }
        if (snapshot.hasData) {
          if (snapshot.connectionState == ConnectionState.active) {
            Map forceUpdateInfoMap = snapshot.data.data();
            if (forceUpdateInfoMap != null) {
              forceUpdateInfo = ForceUpdateInfo(forceUpdateInfoMap);
              if (forceUpdateInfo.usagePrevented(versionNumber)) {
                return ForceUpdateDialog(forceUpdateInfo: forceUpdateInfo);
              }
            }
          }
        }
        return createMaterialApp(context);
      },
    );
  }

  Widget _startPage(BuildContext context) {
    if (Global().getAuthorizationToken() != null) {
      return new StartPage();
    } else {
      return new LoginPage();
    }
  }

  Widget createMaterialApp(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [
        SentryNavigatorObserver(),
      ],
      locale: Translate.getLocale(),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      title: 'Organization Name',
      theme: ThemeData(
        primaryColor: OrganizationNameColor.white,
        primarySwatch: Colors.blue,
        toggleableActiveColor: OrganizationNameColor.green,
        fontFamily: 'SofiaPro',
        dividerTheme: DividerThemeData(
          color: OrganizationNameColor.grey,
          thickness: 1.2,
          space: 1.2,
        ),
        bottomSheetTheme: BottomSheetThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(topLeft: Radius.circular(12.0), topRight: Radius.circular(12.0)),
          ),
        ),
      ),
      home: _startPage(context),
    );
  }
}
