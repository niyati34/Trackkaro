import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/routes_api.dart';

class AddBusPage extends StatefulWidget {
  @override
  _AddBusPageState createState() => _AddBusPageState();
}

class _AddBusPageState extends State<AddBusPage> {
  final _formKey = GlobalKey<FormState>();

  // Fixed: Added separate controller for bus number
  final _busNumberController = TextEditingController();
  final _busSeatsController = TextEditingController();
  final _registrationPlateController = TextEditingController();

  String _busRoute = 'Route 1';
  String _status = 'Activate';
  String _shift = 'Shift 1';
  String _time = 'Morning';

  List<String> busRoutes = [
    'Route 1',
    'Route 2',
    'Route 3',
    'Route 4',
    'Route 5'
  ]; // initial placeholder; will be replaced by backend fetch
  Map<String, int> _routeLabelToId = {
    'Route 1': 1,
    'Route 2': 2,
    'Route 3': 3,
    'Route 4': 4,
    'Route 5': 5
  }; // fallback mapping, will be replaced by backend data
  bool _isLoadingRoutes = false;
  DateTime? _lastRouteFetch;
  String? _token; // Organization token
  // Cached existing buses for preflight duplicate detection
  List<Map<String, dynamic>> _existingBuses = [];
  List<Map<String, dynamic>> _busAssignments = []; // Store bus assignments data
  bool _isLoadingBuses = false;
  DateTime? _lastBusFetch;

  // Simple UUID generator instance
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    // Debug environment setup
    print('=== BUS PAGE ENVIRONMENT ===');
    print('BACKEND_API: ${dotenv.env['BACKEND_API']}');
    print('Environment loaded: ${dotenv.env.isNotEmpty}');
    print('============================');
    _fetchBusesWithAssignments(); // Use enhanced bus fetching
    _fetchRoutes();
  }

  // (Reset form method removed as unused to reduce lint noise)

  Future<void> _fetchBuses() async {
    // Avoid spamming backend; refetch if stale (>60s) or first time
    if (_isLoadingBuses) return;
    if (_lastBusFetch != null &&
        DateTime.now().difference(_lastBusFetch!) <
            const Duration(seconds: 60)) {
      return; // Recently fetched
    }
    final backend = dotenv.env['BACKEND_API'];
    if (backend == null || backend.isEmpty) return;

    setState(() {
      _isLoadingBuses = true;
    });

    try {
      final started = DateTime.now();
      http.Response? resp;

      // Strategy 1: Standard GET with proper headers
      try {
        final url = Uri.parse('$backend/get-all-bus');
        resp =
            await http.get(url, headers: {'Content-Type': 'application/json'});
        final dur = DateTime.now().difference(started).inMilliseconds;
        print(
            '=== FETCH BUSES (GET with headers) === status=${resp.statusCode} ms=$dur');

        if (resp.statusCode == 200) {
          await _processBusesResponse(resp.body);
          return;
        } else if (resp.statusCode != 400 && resp.statusCode != 405) {
          // Non-400/405 means different error, don't try other strategies
          print('Failed to fetch buses (GET): ${resp.statusCode} ${resp.body}');
          return;
        }
      } catch (e) {
        print('GET strategy failed: $e');
      }

      // Strategy 2: GET with query parameter
      try {
        final url = Uri.parse('$backend/get-all-bus?organization_id=1');
        resp =
            await http.get(url, headers: {'Content-Type': 'application/json'});
        final dur = DateTime.now().difference(started).inMilliseconds;
        print(
            '=== FETCH BUSES (GET query) === status=${resp.statusCode} ms=$dur');

        if (resp.statusCode == 200) {
          await _processBusesResponse(resp.body);
          return;
        } else if (resp.statusCode != 400 && resp.statusCode != 405) {
          print(
              'Failed to fetch buses (GET query): ${resp.statusCode} ${resp.body}');
          return;
        }
      } catch (e) {
        print('GET query strategy failed: $e');
      }

      // Strategy 3: POST with JSON body (desktop app compatibility)
      try {
        final url = Uri.parse('$backend/get-all-bus');
        resp = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'organization_id': 1}),
        );
        final dur = DateTime.now().difference(started).inMilliseconds;
        print(
            '=== FETCH BUSES (POST body) === status=${resp.statusCode} ms=$dur');

        if (resp.statusCode == 200) {
          await _processBusesResponse(resp.body);
          return;
        } else {
          print(
              'Failed to fetch buses (POST): ${resp.statusCode} ${resp.body}');
        }
      } catch (e) {
        print('POST strategy failed: $e');
      }

      print('All bus fetch strategies failed');
    } finally {
      if (mounted)
        setState(() {
          _isLoadingBuses = false;
        });
    }
  }

  Future<void> _processBusesResponse(String responseBody) async {
    try {
      final decoded = json.decode(responseBody);
      if (decoded is List) {
        // Normalize each element into map with bus_number and register_numberplate if present
        _existingBuses =
            decoded.whereType<Map>().map<Map<String, dynamic>>((e) {
          final m = <String, dynamic>{};
          if (e.containsKey('bus_number')) m['bus_number'] = e['bus_number'];
          if (e.containsKey('register_numberplate'))
            m['register_numberplate'] = e['register_numberplate'];
          if (e.containsKey('time')) m['time'] = e['time'];
          if (e.containsKey('shift')) m['shift'] = e['shift'];
          return m;
        }).toList();
        print('Fetched ${_existingBuses.length} buses for duplicate check');
        _lastBusFetch = DateTime.now();
      } else {
        print('Unexpected buses payload structure: $responseBody');
      }
    } catch (e) {
      print('Error processing buses response: $e');
    }
  }

  Future<void> _fetchBusesWithAssignments() async {
    // Avoid spamming backend; refetch if stale (>60s) or first time
    if (_isLoadingBuses) return;
    if (_lastBusFetch != null &&
        DateTime.now().difference(_lastBusFetch!) <
            const Duration(seconds: 60)) {
      return; // Recently fetched
    }
    final backend = dotenv.env['BACKEND_API'];
    if (backend == null || backend.isEmpty) return;

    setState(() {
      _isLoadingBuses = true;
    });

    try {
      // First fetch bus assignments to get route, time, shift data
      await _fetchBusAssignments();

      // Then fetch basic bus data and merge with assignments
      await _fetchBuses();

      // Merge bus data with assignment data
      _mergeBusesWithAssignments();
    } catch (e) {
      print('❌ Error fetching buses with assignments: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBuses = false;
        });
      }
    }
  }

  Future<void> _fetchBusAssignments() async {
    final backend = dotenv.env['BACKEND_API'];
    if (backend == null || backend.isEmpty) return;

    try {
      final started = DateTime.now();
      http.Response? resp;

      // Try different strategies for bus assignments
      final strategies = [
        () async {
          final url = Uri.parse('$backend/get-all-bus-assignments');
          return await http
              .get(url, headers: {'Content-Type': 'application/json'});
        },
        () async {
          final url =
              Uri.parse('$backend/get-all-bus-assignments?organization_id=1');
          return await http
              .get(url, headers: {'Content-Type': 'application/json'});
        },
        () async {
          final url = Uri.parse('$backend/get-all-bus-assignments');
          return await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'organization_id': 1}),
          );
        },
      ];

      for (int i = 0; i < strategies.length; i++) {
        try {
          resp = await strategies[i]();
          final dur = DateTime.now().difference(started).inMilliseconds;
          final strategyName = ['GET', 'GET query', 'POST'][i];
          print(
              '=== FETCH BUS ASSIGNMENTS ($strategyName) === status=${resp.statusCode} ms=$dur');

          if (resp.statusCode == 200) {
            await _processBusAssignmentsResponse(resp.body);
            return;
          } else if (resp.statusCode != 400 && resp.statusCode != 405) {
            print(
                'Failed to fetch bus assignments ($strategyName): ${resp.statusCode} ${resp.body}');
            break;
          }
        } catch (e) {
          print('Bus assignments strategy $i failed: $e');
        }
      }

      print('All bus assignment fetch strategies failed');
    } catch (e) {
      print('Exception while fetching bus assignments: $e');
    }
  }

  Future<void> _processBusAssignmentsResponse(String responseBody) async {
    try {
      final decoded = json.decode(responseBody);
      if (decoded is List) {
        _busAssignments = decoded.whereType<Map<String, dynamic>>().toList();
        print('Fetched ${_busAssignments.length} bus assignments');
      } else {
        print('Unexpected bus assignments payload structure: $responseBody');
      }
    } catch (e) {
      print('Error processing bus assignments response: $e');
    }
  }

  void _mergeBusesWithAssignments() {
    if (_busAssignments.isEmpty) {
      print('No bus assignments to merge');
      return;
    }

    // Create enhanced bus list with route/time/shift information
    for (var bus in _existingBuses) {
      final busId = bus['id'] ?? bus['bus_id'];
      if (busId != null) {
        // Find all assignments for this bus
        final assignments = _busAssignments
            .where((assignment) =>
                assignment['bus_id'].toString() == busId.toString())
            .toList();

        if (assignments.isNotEmpty) {
          // Add route/time/shift data from assignments
          final assignment =
              assignments.first; // Use first assignment as primary
          bus['route_id'] = assignment['route_id'];
          bus['time'] = assignment['time'];
          bus['shift'] = assignment['shift'];
          bus['assignments'] = assignments; // Store all assignments
        }
      }
    }

    print('Merged ${_existingBuses.length} buses with assignment data');
    _lastBusFetch = DateTime.now();
  }

  Future<void> _getOrganizationToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token') ?? '1'; // Default to '1' if not found
  }

  Future<void> _fetchRoutes() async {
    if (_isLoadingRoutes) return;
    if (_lastRouteFetch != null &&
        DateTime.now().difference(_lastRouteFetch!) <
            const Duration(minutes: 2)) {
      return; // recent cache
    }

    setState(() {
      _isLoadingRoutes = true;
    });

    try {
      // Get the organization token
      await _getOrganizationToken();

      print('=== FETCH ROUTES (using RoutesApiService) ===');
      final api = RoutesApiService();
      final routes = await api.getAllRoutes(_token ?? '1');

      print('Fetched ${routes.length} routes from API service');

      _routeLabelToId.clear();
      final labels = <String>[];

      for (final route in routes) {
        final routeName =
            route.routeName.isNotEmpty ? route.routeName : 'Route ${route.id}';
        final routeId = int.tryParse(route.id) ?? 0;
        if (routeId > 0) {
          labels.add(routeName);
          _routeLabelToId[routeName] = routeId;
        }
      }

      if (labels.isNotEmpty) {
        setState(() {
          busRoutes = labels;
          if (!busRoutes.contains(_busRoute)) {
            _busRoute = busRoutes.first;
          }
        });
        print(
            'Successfully updated route dropdown with ${busRoutes.length} routes');
        print('Available routes: $labels');
        print('Route mapping: $_routeLabelToId');
      } else {
        print('No routes found in API response');
      }

      _lastRouteFetch = DateTime.now();
    } catch (e) {
      print('❌ Error fetching routes: $e');
      print(
          '📋 Using fallback routes. Please contact backend team to fix route API.');
      print('Available fallback routes: $busRoutes');
      print('Fallback route mapping: $_routeLabelToId');

      // Show user-friendly message about using fallback routes
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Using default routes. Backend API needs fixing.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRoutes = false;
        });
      }
    }
  }

  String? _preflightValidate(
      {required String busNumber,
      required String regPlate,
      required String time,
      required String shift}) {
    // Local duplicate detection. Compare normalized forms.
    final normBus = busNumber.trim();
    final normPlate = regPlate.trim().toLowerCase();
    final apiTime = _convertTimeToApiFormat(time);
    final apiShift = _convertShiftToApiFormat(shift);
    for (final b in _existingBuses) {
      final existingNum = (b['bus_number'] ?? '').toString().trim();
      final existingPlate =
          (b['register_numberplate'] ?? '').toString().trim().toLowerCase();
      final existingTime = (b['time'] ?? '').toString();
      final existingShift = (b['shift'] ?? '').toString();
      if (existingNum == normBus && existingPlate == normPlate) {
        return 'A bus with this number and registration already exists.';
      }
      // Optional narrower constraint guess
      if (existingNum == normBus &&
          existingTime == apiTime &&
          existingShift == apiShift) {
        return 'Bus number+time+shift already present.';
      }
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      print('❌ Bus form validation failed (field validators)');
      return;
    }
    await _fetchBusesWithAssignments(); // ensure we have a recent snapshot with route data
    await _fetchRoutes(); // ensure latest routes

    // Validate we have routes loaded
    if (_routeLabelToId.isEmpty) {
      final msg = 'No routes available. Please refresh routes and try again.';
      print('❌ $msg');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        action: SnackBarAction(
          label: 'Refresh',
          onPressed: () => _fetchRoutes(),
        ),
      ));
      return;
    }

    // Validate selected route exists
    if (!_routeLabelToId.containsKey(_busRoute)) {
      final msg =
          'Selected route "$_busRoute" is not valid. Please select a different route.';
      print('❌ $msg');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    final preflightError = _preflightValidate(
      busNumber: _busNumberController.text,
      regPlate: _registrationPlateController.text,
      time: _time,
      shift: _shift,
    );
    if (preflightError != null) {
      print('❌ Preflight duplicate detected: $preflightError');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(preflightError)),
      );
      return;
    }
    final requestId = _uuid.v4();
    print('>>> SUBMIT BUS START requestId=$requestId');
    await _submitWithRetries(requestId: requestId, maxAttempts: 3);
  }

  Future<void> _submitWithRetries(
      {required String requestId, int maxAttempts = 3}) async {
    int attempt = 0;
    while (attempt < maxAttempts) {
      attempt += 1;
      final success = await sendBusDataToBackend(
        busNumber: _busNumberController.text,
        busSeats: _busSeatsController.text,
        busRoute: _busRoute,
        registerNumberplate: _registrationPlateController.text,
        status: _status == 'Activate',
        shift: _shift,
        time: _time,
        organizationId: '1',
        requestId: requestId,
        attempt: attempt,
      );
      if (success) {
        print('>>> SUBMIT BUS SUCCESS requestId=$requestId attempts=$attempt');
        return;
      }
      if (attempt < maxAttempts) {
        final backoff = 300 * attempt; // simple linear backoff (ms)
        print(
            'Retrying attempt ${attempt + 1} after ${backoff}ms (requestId=$requestId)');
        await Future.delayed(Duration(milliseconds: backoff));
      }
    }
    print(
        '>>> SUBMIT BUS FAILED after $maxAttempts attempts requestId=$requestId');
  }

  String _convertTimeToApiFormat(String time) {
    // Convert "Morning" -> "08:30", "Evening" -> "18:30", etc.
    switch (time.toLowerCase()) {
      case 'morning':
        return '08:30';
      case 'afternoon':
        return '13:30';
      case 'evening':
        return '18:30';
      default:
        return '08:30'; // Default to morning
    }
  }

  String _convertShiftToApiFormat(String shift) {
    // Convert "Shift 1" -> "morning", "Shift 2" -> "afternoon", etc.
    switch (shift.toLowerCase()) {
      case 'shift 1':
        return 'morning';
      case 'shift 2':
        return 'afternoon';
      case 'shift 3':
        return 'evening';
      default:
        return 'morning'; // Default to morning
    }
  }

  Future<bool> sendBusDataToBackend({
    required String busNumber,
    required String busSeats,
    required String busRoute,
    required String registerNumberplate,
    required bool status,
    required String shift,
    required String time,
    required String organizationId,
    required String requestId,
    required int attempt,
  }) async {
    final url = Uri.parse('${dotenv.env['BACKEND_API']}/add-bus');

    // Calculate route_id properly
    final int routeId = _routeLabelToId.isNotEmpty
        ? (_routeLabelToId[busRoute] ?? _routeLabelToId.values.first)
        : int.tryParse(busRoute.replaceAll('Route ', '')) ?? 205;

    final Map<String, dynamic> busData = {
      "bus_number": busNumber,
      "bus_seats": int.tryParse(busSeats) ?? 0,
      "register_numberplate": registerNumberplate,
      "status":
          status, // Boolean: true for active, false for inactive (database expects boolean)
      "organization_id": int.tryParse(organizationId) ?? 0,
      "time": _convertTimeToApiFormat(time), // Convert to API format
      "shift": _convertShiftToApiFormat(shift), // Convert to API format
      "route_id": routeId,
    };

    // Console logging for debugging
    print(
        '=== ADD BUS DEBUG INFO (attempt=$attempt, requestId=$requestId) ===');
    print('URL: $url');
    print('Request Data: $busData');
    print(
        'Raw inputs - busSeats: "$busSeats", organizationId: "$organizationId", busRoute: "$busRoute", status: "$status"');
    print('Original form values - time: "$time", shift: "$shift"');
    print(
        'Converted API values - time: "${_convertTimeToApiFormat(time)}", shift: "${_convertShiftToApiFormat(shift)}"');
    print('Route mapping available: ${_routeLabelToId.isNotEmpty}');
    if (_routeLabelToId.isNotEmpty) {
      print('Available routes: ${_routeLabelToId.keys.toList()}');
      print('Route mapping: $_routeLabelToId');
      print('Selected route: "$busRoute" -> route_id: $routeId');
    } else {
      print('No route mapping available, using fallback calculation: $routeId');
    }
    print(
        'Parsed values - bus_seats: ${int.tryParse(busSeats)}, organization_id: ${int.tryParse(organizationId)}, route_id: $routeId, status: $status (boolean)');
    print('Potential issues to check:');
    print(
        '- Is bus_number "$busNumber" already assigned for time "${_convertTimeToApiFormat(time)}" + shift "${_convertShiftToApiFormat(shift)}"?');
    print('- Does route_id $routeId exist in Routes table?');
    print(
        '- Does organization_id ${int.tryParse(organizationId)} exist in Organizations table?');
    print(
        '- Is there a unique constraint on (bus_number, time, shift) combination?');
    print('==========================');

    try {
      final startTs = DateTime.now();
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(busData),
      );
      final elapsed = DateTime.now().difference(startTs).inMilliseconds;

      print(
          '=== ADD BUS RESPONSE (attempt=$attempt, requestId=$requestId, ${elapsed}ms) ===');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('Response Headers: ${response.headers}');
      print('========================');

      if (response.statusCode == 201) {
        print('✅ Bus added successfully!');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Bus added successfully!')),
        );
        Navigator.pop(context);
        return true;
      } else {
        print('❌ Failed to add bus - Status: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to add bus: ${response.body}')),
        );
        // Retry only on 5xx
        return response.statusCode >= 500 && response.statusCode < 600
            ? false
            : true;
      }
    } catch (e) {
      print('❌ Exception while adding bus: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error occurred: $e')),
      );
      return false; // allow retry on network/exception
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Bus'),
        backgroundColor: Color(0xFF03B0C1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: FlexColumnWidth(1),
                  },
                  children: [
                    TableRow(children: [
                      // Fixed: Using correct controller for bus number
                      _buildTextField(_busNumberController, 'Bus Number',
                          Icons.confirmation_number_outlined),
                      _buildTextField(
                          _busSeatsController, 'Bus Seats', Icons.event_seat),
                    ]),
                    TableRow(children: [
                      Row(children: [
                        Expanded(
                          child: _buildDropdown(
                              _busRoute, 'Bus Route', busRoutes, (newValue) {
                            setState(() {
                              _busRoute = newValue!;
                            });
                          }),
                        ),
                        IconButton(
                          tooltip: 'Refresh routes',
                          onPressed: _isLoadingRoutes
                              ? null
                              : () async {
                                  await _fetchRoutes();
                                },
                          icon: _isLoadingRoutes
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : Icon(Icons.refresh, color: Color(0xFF03B0C1)),
                        )
                      ]),
                      _buildTextField(_registrationPlateController,
                          'Registration Plate', Icons.credit_card),
                    ]),
                    TableRow(children: [
                      _buildDropdown(
                          _status, 'Status', ['Activate', 'Deactivate'],
                          (newValue) {
                        setState(() {
                          _status = newValue!;
                        });
                      }),
                      _buildDropdown(
                          _shift, 'Shift', ['Shift 1', 'Shift 2', 'Shift 3'],
                          (newValue) {
                        setState(() {
                          _shift = newValue!;
                        });
                      }),
                    ]),
                    TableRow(children: [
                      _buildDropdown(
                          _time, 'Time', ['Morning', 'Afternoon', 'Evening'],
                          (newValue) {
                        setState(() {
                          _time = newValue!;
                        });
                      }),
                      Column(
                        children: [
                          SizedBox(),
                          SizedBox(height: 16.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  if (_formKey.currentState!.validate()) {
                                    // Log form values before sending
                                    print('=== BUS FORM VALUES ===');
                                    print(
                                        'Bus Number: "${_busNumberController.text}"');
                                    print(
                                        'Bus Seats: "${_busSeatsController.text}"');
                                    print('Bus Route: "$_busRoute"');
                                    print(
                                        'Registration Plate: "${_registrationPlateController.text}"');
                                    print(
                                        'Status: "$_status" (${_status == 'Activate'})');
                                    print('Shift: "$_shift"');
                                    print('Time: "$_time"');
                                    print('Organization ID: "1"');
                                    print('========================');

                                    _handleSubmit();
                                  } else {
                                    print('❌ Bus form validation failed');
                                  }
                                },
                                child: Text(
                                  'Add Bus',
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF03B0C1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 20),
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
                                  padding: EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 20),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String labelText, IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
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
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter ${labelText.toLowerCase()}';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdown(String value, String labelText, List<String> items,
      ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: DropdownButtonFormField<String>(
        value: value,
        onChanged: onChanged,
        items: items.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: Icon(Icons.arrow_drop_down, color: Color(0xFF03B0C1)),
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
      ),
    );
  }
}
