import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'map_picker.dart';
import 'models/route_models.dart';
import 'services/routes_api.dart';

class AddRoutePage extends StatefulWidget {
  @override
  _AddRoutePageState createState() => _AddRoutePageState();
}

class _AddRoutePageState extends State<AddRoutePage> {
  // Basic
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _routeNumber = TextEditingController();
  final TextEditingController _routeName = TextEditingController();
  String? _token;
  final _api = RoutesApiService();

  // Source
  final TextEditingController _sourceName = TextEditingController();
  final TextEditingController _sourceLat = TextEditingController();
  final TextEditingController _sourceLng = TextEditingController();

  // Destination
  final TextEditingController _destName = TextEditingController();
  final TextEditingController _destLat = TextEditingController();
  final TextEditingController _destLng = TextEditingController();

  // Stops
  final List<Map<String, TextEditingController>> _stops = [];

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _token = prefs.getString('token') ?? '1';
    });
  }

  @override
  void dispose() {
    _routeNumber.dispose();
    _routeName.dispose();
    _sourceName.dispose();
    _sourceLat.dispose();
    _sourceLng.dispose();
    _destName.dispose();
    _destLat.dispose();
    _destLng.dispose();
    for (final m in _stops) {
      m.values.forEach((c) => c.dispose());
    }
    super.dispose();
  }

  Future<void> _createRoute() async {
    if (!_formKey.currentState!.validate()) return;
    if (_token == null || _token!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Organization not set. Please login again.')),
      );
      return;
    }

    final req = CreateRouteRequest(
      routeNumber: _routeNumber.text,
      routeName: _routeName.text,
      source: RouteLocation(
        locationName: _sourceName.text,
        locationLat: _sourceLat.text,
        locationLng: _sourceLng.text,
      ),
      destination: RouteLocation(
        locationName: _destName.text,
        locationLat: _destLat.text,
        locationLng: _destLng.text,
      ),
      stops: _stops
          .map((m) => RouteLocation(
                locationName: m['name']!.text,
                locationLat: m['lat']!.text,
                locationLng: m['lng']!.text,
              ))
          .where((s) => s.locationName.isNotEmpty)
          .toList(),
      organizationId: _token!,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 10),
            Text('Adding route...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      await _api.addRoute(req);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('✅ Route added successfully!'),
            backgroundColor: Colors.green),
      );
      Navigator.pop(context, {
        'routeNumber': req.routeNumber,
        'routeName': req.routeName,
        'source': req.source.locationName,
        'destination': req.destination.locationName,
        'stops': req.stops.map((s) => s.locationName).toList(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('❌ Failed to add route: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _addStop() {
    setState(() {
      _stops.add({
        'name': TextEditingController(),
        'lat': TextEditingController(),
        'lng': TextEditingController(),
      });
    });
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Color(0xFF03B0C1)),
          filled: true,
          fillColor: Colors.grey[200],
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Color(0xFF03B0C1)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.red),
          ),
        ),
        keyboardType: keyboardType,
        validator: (value) =>
            (value == null || value.isEmpty) ? 'Required' : null,
      ),
    );
  }

  Widget _buildLocationRow({
    required String label,
    required TextEditingController name,
    required TextEditingController lat,
    required TextEditingController lng,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: name,
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: Icon(Icons.place, color: Color(0xFF03B0C1)),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: TextFormField(
              controller: lat,
              decoration: InputDecoration(
                labelText: 'Lat',
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (v) => (v == null || v.isEmpty) ? 'Lat' : null,
            ),
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: TextFormField(
              controller: lng,
              decoration: InputDecoration(
                labelText: 'Lng',
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (v) => (v == null || v.isEmpty) ? 'Lng' : null,
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.map, color: Color(0xFF03B0C1)),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MapPickerPage()),
              );
              if (result != null && result is Map<String, dynamic>) {
                final pos = result['latLng'];
                final address = result['address'];
                setState(() {
                  if (address != null) name.text = address.toString();
                  if (pos != null) {
                    lat.text = pos.latitude.toString();
                    lng.text = pos.longitude.toString();
                  }
                });
              }
            },
          )
        ],
      ),
    );
  }

  Widget _buildStopRow(Map<String, TextEditingController> m) {
    return Row(
      children: [
        Expanded(
            child: _buildTextField(m['name']!, 'Stop Name', Icons.location_on)),
        SizedBox(width: 8),
        SizedBox(
            width: 110,
            child: _buildTextField(m['lat']!, 'Lat', Icons.my_location,
                keyboardType: TextInputType.numberWithOptions(decimal: true))),
        SizedBox(width: 8),
        SizedBox(
            width: 110,
            child: _buildTextField(m['lng']!, 'Lng', Icons.my_location,
                keyboardType: TextInputType.numberWithOptions(decimal: true))),
        IconButton(
          icon: Icon(Icons.map, color: Color(0xFF03B0C1)),
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MapPickerPage()),
            );
            if (result != null && result is Map<String, dynamic>) {
              final pos = result['latLng'];
              final address = result['address'];
              setState(() {
                if (address != null) m['name']!.text = address.toString();
                if (pos != null) {
                  m['lat']!.text = pos.latitude.toString();
                  m['lng']!.text = pos.longitude.toString();
                }
              });
            }
          },
        ),
        IconButton(
          icon: Icon(Icons.delete, color: Colors.red),
          onPressed: () {
            setState(() {
              _stops.remove(m);
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Route"),
        backgroundColor: Color(0xFF03B0C1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              _routeNumber,
                              'Route No.',
                              Icons.format_list_numbered,
                            ),
                          ),
                          Expanded(
                            child: _buildTextField(
                              _routeName,
                              'Route Name',
                              Icons.directions_bus,
                            ),
                          ),
                        ],
                      ),
                      _buildLocationRow(
                        label: 'Source',
                        name: _sourceName,
                        lat: _sourceLat,
                        lng: _sourceLng,
                      ),
                      _buildLocationRow(
                        label: 'Destination',
                        name: _destName,
                        lat: _destLat,
                        lng: _destLng,
                      ),
                      ..._stops.map((m) => _buildStopRow(m)).toList(),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _addStop,
                  child: Text(
                    'Add Stop',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF03B0C1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _createRoute();
                    }
                  },
                  child: Text(
                    'Create',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF03B0C1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF03B0C1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
