import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeData _theme = ThemeData.light();

  ThemeData get theme => _theme;

  set theme(ThemeData theme) {
    _theme = theme;
    notifyListeners();
  }

  void updatePrimaryColor(MaterialColor color) {
    if (theme.brightness == Brightness.light) {
      theme = ThemeData(primarySwatch: color, brightness: theme.brightness);
    } else {
      theme = ThemeData(primarySwatch: color, brightness: theme.brightness);
    }
  }
}
