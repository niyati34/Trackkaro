import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class SelectLocationPage extends StatefulWidget {
  final Function(LatLng, String) onLocationSelected;
  const SelectLocationPage({Key? key, required this.onLocationSelected}) : super(key: key);

  @override
  State<SelectLocationPage> createState() => _SelectLocationPageState();
}

class _SelectLocationPageState extends State<SelectLocationPage> {
  LatLng? selectedPoint;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location on Map'),
        backgroundColor: const Color(0xFF03B0C1),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              if (selectedPoint != null) {
                widget.onLocationSelected(
                  selectedPoint!,
                  'Lat: ${selectedPoint!.latitude}, Lng: ${selectedPoint!.longitude}',
                );
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          center: LatLng(22.7196, 75.8577), // default center
          zoom: 13.0,
          onTap: (tapPosition, latlng) {
            setState(() {
              selectedPoint = latlng;
            });
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app',
          ),
          if (selectedPoint != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: selectedPoint!,
                  width: 40,
                  height: 40,
                  builder: (ctx) => const Icon(Icons.location_on, color: Colors.red, size: 30),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
