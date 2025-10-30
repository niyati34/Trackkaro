import 'package:flutter/material.dart';

class CameraViewPage extends StatelessWidget {
  final String cameraName;

  const CameraViewPage({Key? key, required this.cameraName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$cameraName - Live View'),
        backgroundColor: Color(0xFF03B0C1),
      ),
      body: Center(
        child: Text(
          'Live camera feed for $cameraName will be displayed here.',
          style: TextStyle(fontSize: 18, color: Color(0xFF03B0C1)),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
