import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NetworkDebugPage extends StatefulWidget {
  @override
  _NetworkDebugPageState createState() => _NetworkDebugPageState();
}

class _NetworkDebugPageState extends State<NetworkDebugPage> {
  List<String> debugLogs = [];
  bool isTestingRunning = false;

  void addLog(String message) {
    setState(() {
      debugLogs.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
  }

  Future<void> runNetworkTests() async {
    setState(() {
      isTestingRunning = true;
      debugLogs.clear();
    });

    addLog('Starting network diagnostics...');

    // Test 1: Environment variables
    final baseUrl = dotenv.env['BACKEND_API'];
    addLog('Base URL from env: $baseUrl');

    // Test 2: Get token
    String? token;
    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('token');
      addLog('Token from SharedPreferences: ${token ?? 'null'}');
    } catch (e) {
      addLog('ERROR getting token: $e');
    }

    // Test 3: Simple connectivity test
    try {
      addLog('Testing basic connectivity...');
      final response = await http.get(
        Uri.parse('$baseUrl/'),
        headers: {'User-Agent': 'Flutter-Debug'},
      ).timeout(Duration(seconds: 10));
      addLog(
          'Base URL test: ${response.statusCode} - ${response.reasonPhrase}');
      addLog('Response headers: ${response.headers}');
    } catch (e) {
      addLog('ERROR on base URL: $e');
    }

    // Test 4: Test different endpoints with different methods
    final endpoints = [
      {'path': '/get-all-routes', 'method': 'GET'},
      {'path': '/get-all-routes', 'method': 'POST'}, // legacy fallback
      {'path': '/get-all-students', 'method': 'GET'},
      {'path': '/get-all-students', 'method': 'POST'}, // legacy
      {'path': '/get-all-bus', 'method': 'GET'},
      {'path': '/get-all-bus', 'method': 'POST'}, // legacy
      {'path': '/get-all-drivers', 'method': 'GET'},
      {'path': '/get-all-drivers', 'method': 'POST'}, // legacy
    ];

    for (final endpoint in endpoints) {
      try {
        addLog('Testing ${endpoint['method']} ${endpoint['path']}...');

        http.Response response;
        final uri = Uri.parse('$baseUrl${endpoint['path']}');

        if (endpoint['method'] == 'POST') {
          response = await http
              .post(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  'User-Agent': 'Flutter-Debug',
                },
                body: jsonEncode({'organization_id': token ?? '1'}),
              )
              .timeout(Duration(seconds: 10));
        } else {
          final queryUri = uri.replace(queryParameters: {
            'organization_id': token ?? '1',
          });
          response = await http.get(
            queryUri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Flutter-Debug',
            },
          ).timeout(Duration(seconds: 10));
        }

        addLog(
            '${endpoint['method']} ${endpoint['path']}: ${response.statusCode}');
        if (response.statusCode != 200) {
          final body = response.body.length > 200
              ? response.body.substring(0, 200) + '...'
              : response.body;
          addLog('Response body: $body');
        } else {
          addLog('SUCCESS! Response length: ${response.body.length}');
          try {
            final parsed = jsonDecode(response.body);
            if (parsed is List) {
              addLog('Response is array with ${parsed.length} items');
            } else if (parsed is Map) {
              addLog('Response is object with keys: ${parsed.keys.join(', ')}');
            }
          } catch (e) {
            addLog(
                'Response is not JSON: ${response.body.substring(0, 100)}...');
          }
        }
      } catch (e) {
        addLog('ERROR on ${endpoint['method']} ${endpoint['path']}: $e');
      }
    }

    // Test 5: Test with different tokens
    final testTokens = ['1', token, 'test-org'];
    for (final testToken in testTokens) {
      if (testToken == null) continue;
      try {
        addLog('Testing with token: $testToken');
        final response = await http
            .post(
              Uri.parse('$baseUrl/get-all-students'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({'organization_id': testToken}),
            )
            .timeout(Duration(seconds: 10));
        addLog('Token $testToken result: ${response.statusCode}');
      } catch (e) {
        addLog('ERROR with token $testToken: $e');
      }
    }

    addLog('Network diagnostics completed!');
    setState(() {
      isTestingRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Network Debug'),
        backgroundColor: Color(0xFF03B0C1),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ElevatedButton(
                  onPressed: isTestingRunning ? null : runNetworkTests,
                  child: Text(
                      isTestingRunning ? 'Testing...' : 'Run Network Tests'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF03B0C1),
                    foregroundColor: Colors.white,
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      debugLogs.clear();
                    });
                  },
                  child: Text('Clear Logs'),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text('Debug Logs:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: ListView.builder(
                  itemCount: debugLogs.length,
                  itemBuilder: (context, index) {
                    final log = debugLogs[index];
                    final isError = log.contains('ERROR');
                    final isSuccess = log.contains('SUCCESS');

                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isError
                            ? Colors.red.withOpacity(0.1)
                            : isSuccess
                                ? Colors.green.withOpacity(0.1)
                                : null,
                      ),
                      child: Text(
                        log,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: isError
                              ? Colors.red
                              : isSuccess
                                  ? Colors.green
                                  : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
