import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<Element> pumpTestElement(WidgetTester tester,
    {List<Widget>? children}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SentryWidget(
        child: SingleChildScrollView(
          child: Visibility(
            visible: true,
            child: Opacity(
              opacity: 0.5,
              child: Column(
                children: children ??
                    <Widget>[
                      newImage(),
                      const Padding(
                        padding: EdgeInsets.all(15),
                        child: Center(child: Text('Centered text')),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        child: Text('Button title'),
                      ),
                      newCustomImage(),
                      // Invisible widgets won't be obscured.
                      Visibility(visible: false, child: Text('Invisible text')),
                      Visibility(visible: false, child: newImage()),
                      Opacity(opacity: 0, child: Text('Invisible text')),
                      Opacity(opacity: 0, child: newImage()),
                      Offstage(offstage: true, child: Text('Offstage text')),
                      Offstage(offstage: true, child: newImage()),
                      Text(dummyText),
                      Material(child: TextFormField()),
                      Material(child: TextField()),
                      SizedBox(
                          width: 100,
                          height: 20,
                          child: Stack(children: [
                            Positioned(
                                top: 0,
                                left: 0,
                                width: 50,
                                child: Text(dummyText)),
                            Positioned(
                                top: 0,
                                left: 0,
                                width: 50,
                                child: newImage(width: 500, height: 500)),
                          ]))
                    ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return find.byType(SentryScreenshotWidget).evaluate().first;
}

final testImageData = Uint8List.fromList([
  66, 77, 142, 0, 0, 0, 0, 0, 0, 0, 138, 0, 0, 0, 124, 0, 0, 0, 1, 0,
  0, 0, 255, 255, 255, 255, 1, 0, 32, 0, 3, 0, 0, 0, 4, 0, 0, 0, 19,
  11, 0, 0, 19, 11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 0, 0,
  255, 0, 0, 255, 0, 0, 0, 0, 0, 0, 255, 66, 71, 82, 115, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 135, 135, 135, 255,
  // This comment prevents dartfmt reformatting this to single-item lines.
]);

Image newImage({double width = 1, double height = 1}) => Image.memory(
      testImageData,
      width: width,
      height: height,
    );

CustomImageWidget newCustomImage({double width = 1, double height = 1}) =>
    CustomImageWidget.memory(
      testImageData,
      width: width,
      height: height,
    );

const dummyText = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.';

class CustomImageWidget extends Image {
  CustomImageWidget.memory(super.bytes, {super.key, super.width, super.height})
      : super.memory();
}
