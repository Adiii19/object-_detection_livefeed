import 'dart:math';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(
        title: 'screen',
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  dynamic controller;
  bool isBusy = false;
  dynamic objectDetector;
  late Size size;

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  //TODO code to initialize the camera feed
  initializeCamera() async {
    //TODO initialize detector
    const mode = DetectionMode.stream;
    // Options to configure the detector while using with base model.
    final options = ObjectDetectorOptions(
        mode: mode, classifyObjects: true, multipleObjects: true);
    objectDetector = ObjectDetector(options: options);

    //TODO initialize controller
    controller = CameraController(cameras[0], ResolutionPreset.high);
    await controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      controller.startImageStream((image) => {
            if (!isBusy)
              {isBusy = true, img = image, doObjectDetectionOnFrame()}
          });
    });
  }

  //close all resources
  @override
  void dispose() {
    controller?.dispose();
    objectDetector.close();
    super.dispose();
  }

  //TODO object detection on a frame
  dynamic _scanResults;
  CameraImage? img;
  doObjectDetectionOnFrame() async {
    // var frameImg = getInputImage();
    // List<DetectedObject> objects = await objectDetector.processImage(frameImg);
    // print("len= ${objects.length}");
    setState(() {
    //  _scanResults = objects;
      isBusy = false;
    });

  }

  InputImage getInputImage() {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in img!.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();
    final Size imageSize = Size(img!.width.toDouble(), img!.height.toDouble());
    final camera = cameras[0];
    final imageRotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation);

    final inputImageFormat =
        InputImageFormatValue.fromRawValue(img!.format.raw);

    final planeData = img!.planes.map(
      (Plane plane) {
        return  InputImageMetadata(
          bytesPerRow: plane.bytesPerRow,
          size: imageSize,
          rotation: imageRotation!,
          format:  InputImageFormat.nv21

        );
      },
    ).toList();

    final inputImageData = InputImageData(
      size: imageSize,
      rotation: imageRotation!,
      inputImageFormat: inputImageFormat!,
      planeData: planeData,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
}

  //Show rectangles around detected objects
  Widget buildResult() {
    if (_scanResults == null ||
        controller == null ||
        !controller.value.isInitialized) {
      return const Text('');
    }

    final Size imageSize = Size(
      controller.value.previewSize!.height,
      controller.value.previewSize!.width,
    );
    CustomPainter painter = ObjectDetectorPainter(imageSize, _scanResults);
    return CustomPaint(
      painter: painter,
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> stackChildren = [];
    size = MediaQuery.of(context).size;
    if (controller != null) {
      stackChildren.add(
        Positioned(
          top: 0.0,
          left: 0.0,
          width: size.width,
          height: size.height,
          child: Container(
            child: (controller.value.isInitialized)
                ? AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: CameraPreview(controller),
                  )
                : Container(),
          ),
        ),
      );

      // stackChildren.add(
      //   Positioned(
      //       top: 0.0,
      //       left: 0.0,
      //       width: size.width,
      //       height: size.height,
      //       child: buildResult()),
      // );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Object detector"),
        backgroundColor: Colors.pinkAccent,
      ),
      backgroundColor: Colors.black,
      body: Container(
          margin: const EdgeInsets.only(top: 0),
          color: Colors.black,
          child: Stack(
            children: stackChildren,
          )),
    );
  }
}

class ObjectDetectorPainter extends CustomPainter {
  ObjectDetectorPainter(this.absoluteImageSize, this.objects);

  final Size absoluteImageSize;
  final List<DetectedObject> objects;

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.pinkAccent;

    for (DetectedObject detectedObject in objects) {
      canvas.drawRect(
        Rect.fromLTRB(
          detectedObject.boundingBox.left * scaleX,
          detectedObject.boundingBox.top * scaleY,
          detectedObject.boundingBox.right * scaleX,
          detectedObject.boundingBox.bottom * scaleY,
        ),
        paint,
      );

      // var list = detectedObject.labels;
      // for (Label label in list) {
      //   print("${label.text}   ${label.confidence.toStringAsFixed(2)}");
      //   TextSpan span = TextSpan(
      //       text: label.text,
      //       style: const TextStyle(fontSize: 25, color: Colors.blue));
      //   TextPainter tp = TextPainter(
      //       text: span,
      //       textAlign: TextAlign.left,
      //       textDirection: TextDirection.ltr);
      //   tp.layout();
      //   tp.paint(
      //       canvas,
      //       Offset(detectedObject.boundingBox.left * scaleX,
      //           detectedObject.boundingBox.top * scaleY));
      //   break;
      // }
    }
  }

  @override
  bool shouldRepaint(ObjectDetectorPainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.objects != objects;
  }
}
