import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class MapPickerPage extends StatelessWidget {
  final LatLng? initialPosition;
  const MapPickerPage({Key? key, this.initialPosition}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    LatLng _picked = initialPosition ?? LatLng(22.3072, 73.1812);

    return Scaffold(
      appBar: AppBar(title: Text('Pick Location')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: _picked, zoom: 15),
        onTap: (pos) => _onTap(context, pos),
        markers: initialPosition != null
            ? {Marker(markerId: MarkerId('init'), position: initialPosition!)}
            : {},
      ),
    );
  }

  void _onTap(BuildContext ctx, LatLng pos) async {
    // Reverse-geocode
    final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
    final placemark = placemarks.first;
    final address =
        "${placemark.street}, ${placemark.locality}, ${placemark.administrativeArea}, ${placemark.country}";
    Navigator.pop(ctx, {'latLng': pos, 'address': address});
  }
}
