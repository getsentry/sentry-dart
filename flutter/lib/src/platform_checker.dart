import 'dart:io';

/// verify if the platform is iOS
/// used to run loadContextsIntegration only on iOS
bool isIOS() => Platform.isIOS;

/// verify if the platform is Android
bool isAndroid() => Platform.isAndroid;
