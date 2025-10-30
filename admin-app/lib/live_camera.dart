import 'package:flutter/material.dart';
import 'ui/design_system.dart'; // Ensure this path is correct
import 'camera_view_page.dart'; // Page where you'll show the camera view

class LiveCameraPage extends StatelessWidget {
  final List<Map<String, String>> cameraDetails = List.generate(20, (index) {
    return {
      'Camera Name': 'Camera ${index + 1}',
      'Location': 'Zone ${index + 1}',
      'Status': index % 2 == 0 ? 'Online' : 'Offline',
      'Bus Number': 'Bus ${index + 1}',
    };
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Live Cameras'),
        backgroundColor: Color(0xFF03B0C1),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Color(0xFF03B0C1), size: 30),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          if (MediaQuery.of(context).size.width >= 600)
            ModernSidebar(currentRoute: '/camera'),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Live Cameras',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF03B0C1),
                      ),
                    ),
                    SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        int crossAxisCount = constraints.maxWidth < 600
                            ? 1
                            : constraints.maxWidth < 900
                                ? 2
                                : 3;

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            childAspectRatio: 2.5,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: cameraDetails.length,
                          itemBuilder: (context, index) {
                            final camera = cameraDetails[index];
                            return _buildCameraCard(
                              context: context,
                              cameraName: camera['Camera Name']!,
                              location: camera['Location']!,
                              status: camera['Status']!,
                              busNumber: camera['Bus Number']!,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CameraViewPage(
                                      cameraName: camera['Camera Name']!,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraCard({
    required BuildContext context,
    required String cameraName,
    required String location,
    required String status,
    required String busNumber,
    required VoidCallback onPressed,
  }) {
    Color statusColor = status == 'Online' ? Colors.green : Colors.red;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFF03B0C1), width: 2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                cameraName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF03B0C1),
                ),
              ),
              Text(
                'Location: $location',
                style: TextStyle(fontSize: 14, color: Color(0xFF03B0C1)),
              ),
              Text(
                'Bus Number: $busNumber',
                style: TextStyle(fontSize: 14, color: Color(0xFF03B0C1)),
              ),
              Text(
                'Status: $status',
                style: TextStyle(fontSize: 14, color: statusColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
