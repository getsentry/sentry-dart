import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<Element> getTestElement(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SentryWidget(
        child: SingleChildScrollView(
          child: Visibility(
            visible: true,
            child: Opacity(
              opacity: 0.5,
              child: Column(
                children: <Widget>[
                  newImage(),
                  const Padding(
                    padding: EdgeInsets.all(15),
                    child: Center(child: Text('Centered text')),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    child: Text('Button title'),
                  ),
                  newImage(),
                  // Invisible widgets won't be obscured.
                  Visibility(visible: false, child: Text('Invisible text')),
                  Visibility(visible: false, child: newImage()),
                  Opacity(opacity: 0, child: Text('Invisible text')),
                  Opacity(opacity: 0, child: newImage()),
                  Offstage(offstage: true, child: Text('Offstage text')),
                  Offstage(offstage: true, child: newImage()),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return TestWidgetsFlutterBinding.instance.rootElement!;
}

Image newImage() => Image.memory(
      Uint8List.fromList([
        66, 77, 142, 0, 0, 0, 0, 0, 0, 0, 138, 0, 0, 0, 124, 0, 0, 0, 1, 0,
        0, 0, 255, 255, 255, 255, 1, 0, 32, 0, 3, 0, 0, 0, 4, 0, 0, 0, 19,
        11, 0, 0, 19, 11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 0, 0,
        255, 0, 0, 255, 0, 0, 0, 0, 0, 0, 255, 66, 71, 82, 115, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 135, 135, 135, 255,
        // This comment prevents dartfmt reformatting this to single-item lines.
      ]),
      width: 1,
      height: 1,
    );
