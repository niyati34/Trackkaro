import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'login_page.dart';
import 'add_route_page.dart';
import 'services/routes_api.dart';
import 'ui/design_system.dart';

class SetRoutePage extends StatefulWidget {
  @override
  State<SetRoutePage> createState() => _SetRoutePageState();
}

class _SetRoutePageState extends State<SetRoutePage> {
  List<Map<String, dynamic>> routes = [];
  List<Map<String, dynamic>> filteredRoutes = [];
  bool isLoading = true;
  bool isError = false;
  String? _token;

  final TextEditingController _searchController = TextEditingController();
  Set<int> editingRows = {};
  Map<int, Map<String, TextEditingController>> rowControllers = {};

  @override
  void initState() {
    super.initState();
    _fetchRoutes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    rowControllers
        .forEach((_, ctrls) => ctrls.values.forEach((c) => c.dispose()));
    super.dispose();
  }

  Future<void> _getOrganizationToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    if (_token == null && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
        (route) => false,
      );
    }
  }

  Future<void> _fetchRoutes() async {
    await _getOrganizationToken();
    if (_token == null) return; // Exit if no token

    setState(() {
      isLoading = true;
      isError = false;
    });
    try {
      print('Fetching routes with organization token: $_token');
      final api = RoutesApiService();
      final list = await api.getAllRoutes(_token!);
      routes = list
          .map((sr) => {
                'routeNumber': sr.routeNumber,
                'routeName': sr.routeName,
                'sourceName': sr.source.locationName,
                'destinationName': sr.destination.locationName,
                'id': sr.id,
              })
          .toList();
      filteredRoutes = List.from(routes);
      _rebuildControllers();
      setState(() => isLoading = false);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully loaded ${routes.length} routes'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error fetching routes: $e');
      setState(() {
        isError = true;
        isLoading = false;
      });

      // Show detailed error message to user
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Failed to Load Routes'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Unable to connect to the server or load route data.'),
                  SizedBox(height: 12),
                  Text('Technical Details:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      e.toString(),
                      style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text('Possible Solutions:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('• Check your internet connection'),
                  Text('• Verify the server is running'),
                  Text('• Contact support if the problem persists'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _fetchRoutes(); // Retry
                },
                child: Text('Retry'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _rebuildControllers() {
    rowControllers
        .forEach((_, ctrls) => ctrls.values.forEach((c) => c.dispose()));
    rowControllers.clear();
    for (int i = 0; i < filteredRoutes.length; i++) {
      rowControllers[i] = {
        'routeNumber':
            TextEditingController(text: filteredRoutes[i]['routeNumber']),
        'routeName':
            TextEditingController(text: filteredRoutes[i]['routeName']),
      };
    }
  }

  void _filterRoutes(String query) {
    final q = query.toLowerCase();
    filteredRoutes = routes.where((r) {
      return (r['routeNumber'] as String).toLowerCase().contains(q) ||
          (r['routeName'] as String).toLowerCase().contains(q) ||
          (r['sourceName'] as String).toLowerCase().contains(q) ||
          (r['destinationName'] as String).toLowerCase().contains(q);
    }).toList();
    editingRows.clear();
    _rebuildControllers();
    setState(() {});
  }

  Future<void> _saveRow(int index) async {
    final route = filteredRoutes[index];
    final id = route['id'];
    final url = Uri.parse('${dotenv.env['BACKEND_API']}/update-route');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 12),
        Text('Updating route...'),
      ]),
      duration: Duration(seconds: 25),
    ));
    try {
      final res = await http.put(url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id': id,
            'organization_id': _token,
            'route_number': rowControllers[index]!['routeNumber']!.text,
            'route_name': rowControllers[index]!['routeName']!.text,
          }));
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (res.statusCode == 200) {
        setState(() {
          filteredRoutes[index]['routeNumber'] =
              rowControllers[index]!['routeNumber']!.text;
          filteredRoutes[index]['routeName'] =
              rowControllers[index]!['routeName']!.text;
          editingRows.remove(index);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ Route updated'), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('❌ Update failed ${res.statusCode}'),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Network error: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _buildRoutesTable() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search routes...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: _filterRoutes,
                ),
              ),
              SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  final created = await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => AddRoutePage()));
                  if (created == true) _fetchRoutes();
                },
                icon: Icon(Icons.add),
                label: Text('Add Route'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF03B0C1)),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Number')),
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Source')),
                DataColumn(label: Text('Destination')),
                DataColumn(label: Text('Actions')),
              ],
              rows: List.generate(filteredRoutes.length, (index) {
                final r = filteredRoutes[index];
                final editing = editingRows.contains(index);
                return DataRow(cells: [
                  DataCell(editing
                      ? SizedBox(
                          width: 100,
                          child: TextField(
                              controller:
                                  rowControllers[index]!['routeNumber']))
                      : Text(r['routeNumber'] ?? '')),
                  DataCell(editing
                      ? SizedBox(
                          width: 140,
                          child: TextField(
                              controller: rowControllers[index]!['routeName']))
                      : Text(r['routeName'] ?? '')),
                  DataCell(Text(r['sourceName'] ?? '')),
                  DataCell(Text(r['destinationName'] ?? '')),
                  DataCell(Row(children: [
                    if (!editing)
                      IconButton(
                          icon: Icon(Icons.edit, size: 20),
                          onPressed: () {
                            setState(() => editingRows.add(index));
                          }),
                    if (editing)
                      IconButton(
                          icon: Icon(Icons.save, size: 20, color: Colors.green),
                          onPressed: () => _saveRow(index)),
                    if (editing)
                      IconButton(
                          icon: Icon(Icons.close, size: 20, color: Colors.red),
                          onPressed: () =>
                              setState(() => editingRows.remove(index))),
                  ])),
                ]);
              }),
            ),
          ),
        ),
      ],
    );
  }

  void _showDebugInfo() {
    final api = RoutesApiService();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Debug Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Backend Configuration:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('API Base URL: ${api.baseUrl}'),
              Text('Organization Token: ${_token ?? 'Not set'}'),
              SizedBox(height: 12),
              Text('Environment:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('BACKEND_API: ${dotenv.env['BACKEND_API'] ?? 'Not set'}'),
              SizedBox(height: 12),
              Text('API Configuration:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('GET Routes: ${api.baseUrl}/get-all-routes'),
              Text('Method: GET with JSON body'),
              Text('Headers: Content-Type: application/json'),
              Text('Body: {"organization_id": "$_token"}'),
              SizedBox(height: 8),
              Text('All Operations (GET/POST/PUT/DELETE):'),
              Text('Headers: Content-Type: application/json'),
              SizedBox(height: 12),
              Text('Routes Status:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Total Routes Loaded: ${routes.length}'),
              Text('Filtered Routes Shown: ${filteredRoutes.length}'),
              Text('Is Loading: $isLoading'),
              Text('Has Error: $isError'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Test API directly
              await _testApiConnection();
            },
            child: Text('Test API'),
          ),
        ],
      ),
    );
  }

  Future<void> _testApiConnection() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Testing API Connection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Testing connection to backend...'),
          ],
        ),
      ),
    );

    try {
      final api = RoutesApiService();
      await api.getAllRoutes(_token ?? '1');
      Navigator.of(context).pop(); // Close testing dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ API Connection Successful!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close testing dialog

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('❌ API Test Failed'),
          content: SingleChildScrollView(
            child: Text(e.toString()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Set Route'),
        backgroundColor: Color(0xFF03B0C1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchRoutes,
            tooltip: 'Refresh Routes',
          ),
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: _showDebugInfo,
            tooltip: 'Debug Info',
          ),
        ],
      ),
      body: Row(
        children: [
          ModernSidebar(currentRoute: '/set-route'),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : isError
                    ? Center(child: Text('Failed to load routes'))
                    : _buildRoutesTable(),
          )
        ],
      ),
    );
  }
}
