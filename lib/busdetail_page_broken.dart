import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:new_app/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'services/buses_api.dart';
import 'services/bus_assignments_api.dart';
import 'add_bus_page.dart';
import 'common_sidebar.dart';

class BusDetailPage extends StatefulWidget {
  @override
  _BusDetailPageState createState() => _BusDetailPageState();
}

class _BusDetailPageState extends State<BusDetailPage> {
  List<Map<String, dynamic>> buses = [];
  bool isLoading = true;
  bool isError = false;
  String? _token;
  final _busesApi = BusesApiService();
  final _assignmentsApi = BusAssignmentsApiService();
  List<Map<String, dynamic>> _assignments = [];
  bool _assignmentsError = false;
  bool _filterRelaxed = false;

  String selectedShift = 'Shift 1';
  String selectedTime = 'Morning';
  List<Map<String, dynamic>> filteredBuses = [];
  bool isEditMode = false;
  Set<int> editingRows = {};

  Map<int, Map<String, TextEditingController>> controllers = {};

  // Chatbot variables
  bool _isChatbotOpen = false;
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _chatbotInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  // Modern helper widgets
  Widget _modernPageCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: Offset(0, 4),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _modernHeader({required String title, required Widget child}) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Future<void> _getOrganizationToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _token = prefs.getString('token');
      if (_token == null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
          (Route<dynamic> route) => false,
        );
      }
    });
  }

  Future<void> _fetchBusDetails() async {
    await _getOrganizationToken();
    if (_token == null) return;
    setState(() {
      isLoading = true;
      isError = false;
      _assignmentsError = false;
    });
    try {
      // Fetch buses and assignments in parallel then merge
      final busesFuture = _busesApi.getAllBuses(_token!);
      final assignmentsFuture = _assignmentsApi.getAllAssignments(_token!);

      final results = await Future.wait<List<Map<String, dynamic>>>([
        busesFuture,
        assignmentsFuture,
      ]).catchError((e) {
        // We'll handle individual errors below
        return <List<Map<String, dynamic>>>[];
      });

      List<Map<String, dynamic>> rawBuses = [];
      List<Map<String, dynamic>> rawAssignments = [];
      if (results.isNotEmpty) {
        if (results.length > 0) rawBuses = results[0];
        if (results.length > 1) rawAssignments = results[1];
      }

      // If assignments fetch failed separately, attempt sequential fallback
      if (rawAssignments.isEmpty) {
        try {
          rawAssignments = await _assignmentsApi.getAllAssignments(_token!);
        } catch (e) {
          _assignmentsError = true;
          debugPrint('Bus assignments fetch failed: $e');
        }
      }

      // Merge assignment data into bus records (route_id, shift, time)
      if (rawAssignments.isNotEmpty && rawBuses.isNotEmpty) {
        _assignments = rawAssignments;
        rawBuses = _assignmentsApi.mergeAssignments(
            buses: rawBuses, assignments: rawAssignments);
      }

      setState(() {
        buses = rawBuses.map((bus) {
          final shift = bus['shift'] ?? 'Shift 1';
          final time = bus['time'] ?? 'Morning';
          final routeId = bus['route_id'];
          return {
            'busNumber': bus['bus_number'] ?? '',
            'busSeats': bus['bus_seats']?.toString() ?? '',
            'busRoute':
                bus['bus_route'] ?? (routeId != null ? 'Route $routeId' : ''),
            'registrationPlate': bus['register_numberplate'] ?? '',
            'status': (bus['status'] == true || bus['status'] == '1')
                ? 'Activate'
                : 'Deactivate',
            'shift': shift,
            'time': time,
            'driver_name': bus['driver_name'] ?? 'N/A',
            'driver_phone': bus['driver_phone'] ?? 'N/A',
            'id': bus['id'].toString(),
            'assignments': bus['assignments'] ?? [],
            'route_id': routeId
          };
        }).toList();
        isLoading = false;
        filterBuses();
        _initializeControllers();
      });
    } catch (e) {
      print('Bus service failed: $e');
      setState(() {
        isLoading = false;
        isError = true;
      });
    }
  }

  void _initializeControllers() {
    controllers.clear();
    for (int i = 0; i < filteredBuses.length; i++) {
      controllers[i] = {
        'busNumber': TextEditingController(text: filteredBuses[i]['busNumber']),
        'busSeats': TextEditingController(text: filteredBuses[i]['busSeats']),
        'busRoute': TextEditingController(text: filteredBuses[i]['busRoute']),
        'registrationPlate':
            TextEditingController(text: filteredBuses[i]['registrationPlate']),
      };
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchBusDetails();
  }

  @override
  void dispose() {
    // Dispose all controllers
    controllers.forEach((key, controllerMap) {
      controllerMap.forEach((key, controller) {
        controller.dispose();
      });
    });
    // Dispose chatbot controllers
    _chatbotInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void filterBuses() {
    setState(() {
      filteredBuses = buses
          .where((bus) =>
              bus['shift'] == selectedShift && bus['time'] == selectedTime)
          .toList();
    });
    _rebuildAssignmentRows();
    _initializeControllers();
  }

  // Flatten per-assignment rows so multiple assignments for same bus all show
  final List<Map<String, dynamic>> _assignmentRows = [];
  void _rebuildAssignmentRows() {
    _assignmentRows.clear();
    _filterRelaxed = false;
    final normSelectedShift = _normalizeShift(selectedShift);
    final normSelectedTime = _normalizeTime(selectedTime);
    bool anyMatched = false;

    int totalAssignments = 0;
    for (final bus in buses) {
      final List assignments = (bus['assignments'] as List?) ?? [];
      if (assignments.isEmpty) {
        // treat bus itself as one pseudo-assignment
        totalAssignments += 1;
        final busShift = _normalizeShift(bus['shift'] ?? 'Shift 1');
        final busTime = _normalizeTime(bus['time'] ?? 'Morning');
        if (busShift == normSelectedShift && busTime == normSelectedTime) {
          anyMatched = true;
          _assignmentRows
              .add(_buildRowFrom(bus: bus, shift: busShift, time: busTime));
        }
        continue;
      }
      for (final aRaw in assignments) {
        if (aRaw is! Map) continue;
        totalAssignments += 1;
        final rawShift = aRaw['shift'] ?? bus['shift'];
        final rawTime = aRaw['time'] ?? bus['time'];
        final normShift = _normalizeShift(rawShift);
        final normTime = _normalizeTime(rawTime);
        if (normShift == normSelectedShift && normTime == normSelectedTime) {
          anyMatched = true;
          _assignmentRows.add(_buildRowFrom(
              bus: bus, assignment: aRaw, shift: normShift, time: normTime));
        }
      }
    }

    if (!anyMatched && totalAssignments > 0) {
      // Relax filter: show everything so user at least sees data
      _filterRelaxed = true;
      _assignmentRows.clear();
      for (final bus in buses) {
        final List assignments = (bus['assignments'] as List?) ?? [];
        if (assignments.isEmpty) {
          final busShift = _normalizeShift(bus['shift'] ?? 'Shift 1');
          final busTime = _normalizeTime(bus['time'] ?? 'Morning');
          _assignmentRows
              .add(_buildRowFrom(bus: bus, shift: busShift, time: busTime));
          continue;
        }
        for (final aRaw in assignments) {
          if (aRaw is! Map) continue;
          final normShift = _normalizeShift(aRaw['shift'] ?? bus['shift']);
          final normTime = _normalizeTime(aRaw['time'] ?? bus['time']);
          _assignmentRows.add(_buildRowFrom(
              bus: bus, assignment: aRaw, shift: normShift, time: normTime));
        }
      }
    }
    debugPrint(
        'Rebuilt assignment rows: ${_assignmentRows.length} (totalAssignments=$totalAssignments, filterRelaxed=$_filterRelaxed)');
  }

  Map<String, dynamic> _buildRowFrom(
      {required Map bus,
      Map? assignment,
      required String shift,
      required String time}) {
    final routeName = assignment != null ? assignment['route_name'] : null;
    final routeId =
        assignment != null ? assignment['route_id'] : bus['route_id'];
    return {
      'busNumber': bus['busNumber'] ?? bus['bus_number'] ?? '',
      'busSeats': bus['busSeats'] ?? bus['bus_seats']?.toString() ?? '',
      'busRoute': routeName ??
          (routeId != null ? 'Route $routeId' : (bus['busRoute'] ?? '')),
      'registrationPlate':
          bus['registrationPlate'] ?? bus['register_numberplate'] ?? '',
      'shift': shift,
      'time': time,
      'status': bus['status'] ??
          ((bus['status'] == true || bus['status'] == '1')
              ? 'Activate'
              : 'Deactivate'),
      'id': bus['id']?.toString() ?? bus['bus_id']?.toString() ?? '',
      'assignment_id': assignment != null ? assignment['id']?.toString() : null,
    };
  }

  String _normalizeShift(dynamic raw) {
    final s = raw?.toString().trim().toLowerCase();
    if (s == null || s.isEmpty) return 'Shift 1';
    if (s == '1' || s.contains('shift 1')) return 'Shift 1';
    if (s == '2' || s.contains('shift 2')) return 'Shift 2';
    if (s == '3' || s.contains('shift 3')) return 'Shift 3';
    if (s.contains('morning')) return 'Shift 1'; // heuristic fallback
    return 'Shift 1';
  }

  String _normalizeTime(dynamic raw) {
    final s = raw?.toString().trim().toLowerCase();
    if (s == null || s.isEmpty) return 'Morning';
    if (s.startsWith('m')) return 'Morning';
    if (s.startsWith('e')) return 'Evening';
    if (s.startsWith('a')) return 'Afternoon';
    return 'Morning';
  }

  void filterSearchResults(String query) {
    List<Map<String, dynamic>> filtered = buses
        .where((bus) =>
            bus['shift'] == selectedShift && bus['time'] == selectedTime)
        .toList();
    if (query.isNotEmpty) {
      filtered = filtered.where((bus) {
        return bus.values.any((value) =>
            value.toString().toLowerCase().contains(query.toLowerCase()));
      }).toList();
    }
    setState(() {
      filteredBuses = filtered;
    });
    _initializeControllers();
  }

  void deleteBus(int index) async {
    final bus = filteredBuses[index];
    final String busId = bus['id'].toString();
    final String url = '${dotenv.env['BACKEND_API']}/delete-bus';

    // Show confirmation dialog first
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Delete'),
          content: Text(
              'Are you sure you want to delete Bus ${bus['busNumber']}? This action cannot be undone.'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete != true) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          "id": busId,
          "organization_id": _token,
        }),
      );

      // Close loading dialog
      if (Navigator.canPop(context)) {
        // Check if dialog is still open
        Navigator.of(context).pop();
      }

      if (response.statusCode == 200) {
        setState(() {
          filteredBuses.removeAt(index);
          // Remove the corresponding bus from the main list
          buses.removeWhere((bus) => bus['id'] == busId);
        });
        _initializeControllers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Bus "${bus['busNumber']}" deleted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        String errorMessage = 'Unknown error occurred';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['message'] ??
              errorData['error'] ??
              'Failed to delete bus';
        } catch (e) {
          errorMessage = 'Server returned: ${response.statusCode}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to delete bus: $errorMessage'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Network error: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  // Save changes for global edit mode
  Future<void> saveAllChanges() async {
    int successCount = 0;
    int totalCount = filteredBuses.length;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
            SizedBox(width: 10),
            Text('Saving all bus changes...'),
          ],
        ),
        duration: Duration(minutes: 2),
        backgroundColor: Colors.blue.shade700,
      ),
    );

    List<Future<void>> updateFutures = [];

    for (int i = 0; i < filteredBuses.length; i++) {
      final controllersForBus = controllers[i];
      if (controllersForBus == null) continue;

      final bus = filteredBuses[i];
      final String busId = bus['id'].toString();
      final String url = '${dotenv.env['BACKEND_API']}/update-bus';

      final updatedData = {
        'id': int.tryParse(busId) ?? 0,
        'organization_id': int.tryParse(_token ?? '0') ?? 0,
        'bus_number': controllersForBus['busNumber']!.text,
        'bus_seats': int.tryParse(controllersForBus['busSeats']!.text) ?? 0,
        'register_numberplate': controllersForBus['registrationPlate']!.text,
        'status': bus['status'] ==
            'Activate', // Boolean: true for Activate, false for others
      };

      updateFutures.add(() async {
        try {
          final response = await http.put(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(updatedData),
          );

          if (response.statusCode == 200) {
            setState(() {
              filteredBuses[i]['busNumber'] =
                  controllersForBus['busNumber']!.text;
              filteredBuses[i]['busSeats'] =
                  controllersForBus['busSeats']!.text;
              filteredBuses[i]['busRoute'] =
                  controllersForBus['busRoute']!.text;
              filteredBuses[i]['registrationPlate'] =
                  controllersForBus['registrationPlate']!.text;

              final mainIndex = buses.indexWhere((b) => b['id'] == busId);
              if (mainIndex != -1) {
                buses[mainIndex] = Map.from(filteredBuses[i]);
              }
            });
            successCount++;
          } else {
            print('Failed to update bus ${bus['busNumber']}: ${response.body}');
          }
        } catch (e) {
          print('Error updating bus ${bus['busNumber']}: $e');
        }
      }());
    }

    await Future.wait(updateFutures);

    setState(() {
      isEditMode = false;
      editingRows.clear();
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('✅ $successCount of $totalCount buses updated successfully!'),
        backgroundColor:
            successCount == totalCount ? Colors.green : Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Save changes for single row
  Future<void> saveRowChanges(int index) async {
    final controllersForBus = controllers[index];
    if (controllersForBus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: No controllers found for this row.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bus = filteredBuses[index];
    final String busId = bus['id'].toString();
    final String url = '${dotenv.env['BACKEND_API']}/update-bus';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
            SizedBox(width: 10),
            Text('Updating bus...'),
          ],
        ),
        duration: Duration(seconds: 30),
        backgroundColor: Colors.blue.shade700,
      ),
    );

    final updatedData = {
      'id': int.tryParse(busId) ?? 0,
      'organization_id': int.tryParse(_token ?? '0') ?? 0,
      'bus_number': controllersForBus['busNumber']!.text,
      'bus_seats': int.tryParse(controllersForBus['busSeats']!.text) ?? 0,
      'register_numberplate': controllersForBus['registrationPlate']!.text,
      'status': bus['status'] ==
          'Activate', // Boolean: true for Activate, false for others
    };

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updatedData),
      );

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (response.statusCode == 200) {
        setState(() {
          filteredBuses[index]['busNumber'] =
              controllersForBus['busNumber']!.text;
          filteredBuses[index]['busSeats'] =
              controllersForBus['busSeats']!.text;
          filteredBuses[index]['busRoute']!.text =
              controllersForBus['busRoute']!.text;
          filteredBuses[index]['registrationPlate'] =
              controllersForBus['registrationPlate']!.text;

          final mainIndex = buses.indexWhere((b) => b['id'] == busId);
          if (mainIndex != -1) {
            buses[mainIndex] = Map.from(filteredBuses[index]);
          }

          editingRows.remove(index);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Bus updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        String errorMessage = 'Failed to update bus';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['message'] ??
              errorData['error'] ??
              'Failed to update bus';
        } catch (e) {
          errorMessage = 'Server returned: ${response.statusCode}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $errorMessage'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Network error: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Toggle edit mode for single row
  void toggleRowEdit(int index) {
    setState(() {
      if (editingRows.contains(index)) {
        saveRowChanges(index);
      } else {
        editingRows.add(index);
        // Refresh controller values
        if (controllers[index] != null) {
          controllers[index]!['busNumber']!.text =
              filteredBuses[index]['busNumber'];
          controllers[index]!['busSeats']!.text =
              filteredBuses[index]['busSeats'];
          controllers[index]!['busRoute']!.text =
              filteredBuses[index]['busRoute'];
          controllers[index]!['registrationPlate']!.text =
              filteredBuses[index]['registrationPlate'];
        }
      }
    });
  }

  // --- Chatbot Functionality (copied from StudentDetailPage) ---
  void _toggleChatbot() {
    setState(() {
      _isChatbotOpen = !_isChatbotOpen;
      if (!_isChatbotOpen) {
        _messages.clear(); // Clear messages when closing
        _chatbotInputController.clear();
      } else {
        // Optional: Add an initial welcome message from the bot
        if (_messages.isEmpty) {
          _getChatbotResponse("Hi there! How can I help you with buses?",
              isInitialGreeting: true);
        }
      }
    });
  }

  void _sendMessageToChatbot(String message, {bool isQuickResponse = false}) {
    if (message.trim().isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'message': message});
    });
    _chatbotInputController.clear();
    _scrollToBottom();
    _getChatbotResponse(message);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _getChatbotResponse(String userMessage,
      {bool isInitialGreeting = false}) async {
    String botResponse =
        "I'm sorry, I couldn't get a response from the AI assistant at this moment. Please try again later.";
    List<String> quickResponses = [];

    // Define the AI chatbot API endpoint
    final String apiUrl =
        'https://new-track-karo-backend.onrender.com/ai-chat-query'; // Confirmed API

    // Add a "bot typing" message while waiting for API response
    setState(() {
      _messages
          .add({'sender': 'bot', 'message': 'Thinking...', 'isTyping': true});
    });
    _scrollToBottom();

    try {
      if (!isInitialGreeting) {
        // Only make API call for actual user queries, not initial greeting
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
          },
          body: json.encode({'query': userMessage}),
        );

        // Remove the "bot typing" message regardless of success or failure
        setState(() {
          _messages.removeWhere((msg) => msg['isTyping'] == true);
        });

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = json.decode(response.body);
          // Assuming backend returns {"message": "...", "quick_responses": ["...", "..."]}
          botResponse = responseData['message'] ??
              'Sorry, I could not process that request.';
          quickResponses = (responseData['quick_responses'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];

          // Add logic to parse the botResponse and
          // generate relevant quick responses if the backend doesn't provide them.
          // Or refine quick responses based on backend's reply.
          // Example:
          if (quickResponses.isEmpty) {
            String lowerCaseBotResponse = botResponse.toLowerCase();
            if (lowerCaseBotResponse.contains("Which buses run on route 10") ||
                lowerCaseBotResponse
                    .contains("Show me all buses for route 103.")) {
              quickResponses = ["Show me all buses for route 103."];
            } else if (lowerCaseBotResponse
                    .contains("Bus numbers on route 101?") ||
                lowerCaseBotResponse.contains("Bus numbers on route 101")) {
              quickResponses = ["Bus numbers on route 101?"];
            } else {
              quickResponses = ["How many buses are assigned to route 102?"];
            }
          }
        } else {
          // Handle non-200 status codes (e.g., 429 for rate limit, 500 for server error)
          String errorMessage =
              'Error from AI assistant: Server status ${response.statusCode}.';
          try {
            final errorData = json.decode(response.body);
            errorMessage =
                errorData['error'] ?? errorData['message'] ?? errorMessage;
          } catch (e) {
            errorMessage =
                'Server returned unexpected response (Status: ${response.statusCode}). Raw: ${response.body.substring(0, response.body.length.clamp(0, 100))}...'; // Show first 100 chars
          }
          botResponse = "❌ $errorMessage";
          print(
              "Error: AI API returned status ${response.statusCode}: $errorMessage");
          quickResponses = [
            "What can you do?",
            "Is the server down?"
          ]; // Offer helpful quick responses on error
        }
      } else {
        // Initial greeting handled client-side if no specific API call is desired for it
        botResponse =
            "Hello! I'm your Bus Management Assistant. Ask me anything about buses, routes, or shifts!";
        quickResponses = [
          "Which buses run on route 105?",
          "Show me all buses for route 103.",
          "How many buses are assigned to route 102?"
        ];

        // Remove the "bot typing" message for initial greeting as it's not an API call
        setState(() {
          _messages.removeWhere((msg) => msg['isTyping'] == true);
        });
      }
    } catch (e) {
      // Remove the "bot typing" message on network error
      setState(() {
        _messages.removeWhere((msg) => msg['isTyping'] == true);
      });
      // Handle network errors (e.g., no internet connection)
      botResponse =
          "❌ Network error: Could not connect to the AI assistant. Please check your internet connection.";
      print("Network error calling AI API: $e");
      quickResponses = ["Check internet connection", "Try again"];
    }

    setState(() {
      _messages.add({
        'sender': 'bot',
        'message': botResponse,
        'quick_responses': quickResponses
      });
    });
    _scrollToBottom();
  }

  Widget _buildChatbotWindow() {
    return Positioned(
      bottom: 80,
      right: 20,
      child: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: 350, // Slightly wider for better UI
          height: 500, // Taller to accommodate more content
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Chatbot Header (TrackKaro)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: BoxDecoration(
                  color: Color(0xFF03B0C1),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      // You can replace this with a NetworkImage if your avatar is online,
                      // or ensure 'assets/chatbot_avatar.png' exists in your project.
                      backgroundImage: AssetImage('assets/chatbot_avatar.png'),
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person,
                          color: Color(0xFF03B0C1),
                          size: 20), // Fallback if image not found
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chat with TrackKaro AI', // Changed from Jessica Cowles to TrackKaro AI
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                          Text(
                            'We typically reply in a few minutes.', // Custom taglines/status labels
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.keyboard_arrow_down,
                          color: Colors.white), // Collapse icon
                      onPressed: () {
                        // Implement minimize/collapse functionality if desired
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: _toggleChatbot,
                    ),
                  ],
                ),
              ),
              // Chat Messages Area
              Expanded(
                child: ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.all(10.0),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isUser = message['sender'] == 'user';
                    // Check for 'isTyping' and render a typing indicator if true
                    if (message['isTyping'] == true) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: 5),
                          padding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Color(0xFFF1F1F1),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(4),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Typing...', // Simple typing indicator
                            style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[700]),
                          ),
                        ),
                      );
                    }
                    // Continue with normal message rendering
                    final List<String> quickResponses =
                        (message['quick_responses'] as List<dynamic>?)
                                ?.map((e) => e.toString())
                                .toList() ??
                            [];

                    return Column(
                      crossAxisAlignment: isUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: EdgeInsets.symmetric(vertical: 5),
                          padding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          constraints: BoxConstraints(
                              maxWidth: 250), // Constrain bubble width
                          decoration: BoxDecoration(
                            color: isUser
                                ? Color(0xFFE3F2FD)
                                : Color(
                                    0xFFF1F1F1), // Light blue for user, light grey for bot
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                              bottomLeft: isUser
                                  ? Radius.circular(16)
                                  : Radius.circular(
                                      4), // Pointed bottom left for bot
                              bottomRight: isUser
                                  ? Radius.circular(4)
                                  : Radius.circular(
                                      16), // Pointed bottom right for user
                            ),
                          ),
                          child: Text(
                            message['message']!,
                            style: TextStyle(
                                color: isUser
                                    ? Colors.blue.shade900
                                    : Colors.black87),
                          ),
                        ),
                        if (!isUser &&
                            index ==
                                _messages.length -
                                    1) // Response Rating for last bot message
                          Padding(
                            padding: const EdgeInsets.only(
                                top: 4.0, bottom: 8.0, left: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text('Was this helpful?',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[600])),
                                SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    // Handle thumbs up
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Thanks for your feedback!')));
                                  },
                                  child: Icon(Icons.thumb_up_alt_outlined,
                                      size: 18, color: Colors.grey[600]),
                                ),
                                SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    // Handle thumbs down
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Thanks for your feedback!')));
                                  },
                                  child: Icon(Icons.thumb_down_alt_outlined,
                                      size: 18, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        if (!isUser &&
                            quickResponses.isNotEmpty) // Quick Response Buttons
                          Padding(
                            padding:
                                const EdgeInsets.only(top: 8.0, bottom: 4.0),
                            child: Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children: quickResponses
                                  .map(
                                    (response) => ElevatedButton(
                                      onPressed: () => _sendMessageToChatbot(
                                          response,
                                          isQuickResponse: true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey.shade200,
                                        foregroundColor: Colors.blue.shade700,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          side: BorderSide(
                                              color: Colors.blue.shade200),
                                        ),
                                        elevation: 0,
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                      ),
                                      child: Text(response,
                                          style: TextStyle(fontSize: 13)),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              // Message Input Field
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          // Replaced Icons.robot_outlined with Icons.smart_toy_outlined or Icons.assistant_photo
                          icon: Icon(Icons.smart_toy_outlined,
                              color: Colors.grey), // Triggering other bots
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content:
                                    Text('Simulating "Trigger other bots"')));
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.attach_file,
                              color: Colors.grey), // Attachments
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Simulating "Attachments"')));
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.sentiment_satisfied_alt,
                              color: Colors.grey), // Emojis
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Simulating "Emojis"')));
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: _chatbotInputController,
                            decoration: InputDecoration(
                              hintText: 'Enter your message...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide
                                    .none, // No border for cleaner look
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 15, vertical: 10),
                            ),
                            onSubmitted: _sendMessageToChatbot,
                          ),
                        ),
                        SizedBox(width: 8),
                        FloatingActionButton(
                          mini: true,
                          backgroundColor: Color(0xFF03B0C1),
                          child: Icon(Icons.send, color: Colors.white),
                          onPressed: () {
                            _sendMessageToChatbot(_chatbotInputController.text);
                          },
                        ),
                      ],
                    ),
                    // Padding(
                    //   padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                    //   child: Text(
                    //     'POWERED BY TIDIO', // Powered by label
                    //     style: TextStyle(fontSize: 10, color: Colors.grey),
                    //   ),
                    // ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // --- End Chatbot Functionality ---

  // Modern page card helper for consistent styling
  Widget _modernPageCard({
    required Widget child,
    EdgeInsets margin = const EdgeInsets.all(16),
    EdgeInsets padding = const EdgeInsets.all(24),
  }) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _modernHeader() {
    return _modernPageCard(
      margin: EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF03B0C1), Color(0xFF0891B2)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.directions_bus, color: Colors.white, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bus Management',
                  style: GoogleFonts.dmSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage your fleet, track assignments, and monitor bus status',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddBusPage()),
            ),
            icon: Icon(Icons.add, size: 18),
            label: Text('Add Bus'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF03B0C1),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Trackkaro',
          style: GoogleFonts.dmSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF03B0C1),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Color(0xFF03B0C1), size: 24),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Row(
            children: [
              if (MediaQuery.of(context).size.width > 600)
                CommonSidebar(
                  isMobile: false,
                  onNavigate: (index) {
                    // Handle navigation based on the index
                  },
                ),
              Expanded(
                child: Column(
                  children: [
                    _modernHeader(),
                    Expanded(
                      child: _modernPageCard(
                        margin: EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: isLoading
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      color: Color(0xFF03B0C1),
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Loading bus details...',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : isError
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          size: 64,
                                          color: Colors.red.shade300,
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'Failed to fetch bus details',
                                          style: GoogleFonts.dmSans(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Please check your connection and try again',
                                          style: GoogleFonts.dmSans(
                                            fontSize: 14,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                        SizedBox(height: 24),
                                        ElevatedButton.icon(
                                          onPressed: _fetchBusDetails,
                                          icon: Icon(Icons.refresh, size: 18),
                                          label: Text('Retry'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Color(0xFF03B0C1),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : _buildModernBusContent(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Chatbot overlay (unchanged from original)
          if (_isChatbotOpen) _buildChatbotWindow(),
        ],
      ),
    );
  }

  Widget _buildModernBusContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Modern filters section
        Container(
          margin: EdgeInsets.only(bottom: 20),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedShift,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedShift = newValue!;
                          _applyFilters();
                        });
                      },
                      items: <String>['Shift 1', 'Shift 2', 'Shift 3']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedTime,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedTime = newValue!;
                          _applyFilters();
                        });
                      },
                      items: <String>['Morning', 'Evening']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Placeholder for bus data table
        Expanded(
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Bus Fleet',
                      style: GoogleFonts.dmSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(0xFF03B0C1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${filteredBuses.length} buses',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF03B0C1),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Expanded(
                  child: Center(
                    child: Text(
                      'Modern bus data table will be implemented here...',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
                ),
              ),
            ],
          ),
                                      ),
                                      child: const Text(
                                        '⚠ Unable to load route assignments; route / shift / time may be incomplete.',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  Row(
                                    children: [
                                      Icon(Icons.directions_bus),
                                      SizedBox(width: 8),
                                      Text(
                                        'Manage Buses',
                                        style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      if (_assignments.isNotEmpty) ...[
                                        SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.shade50,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            '${_assignments.length} assignments',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.teal.shade800),
                                          ),
                                        )
                                      ],
                                      Spacer(),
                                      Row(
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: _fetchBusDetails,
                                            icon: Icon(Icons.refresh),
                                            label: Text('Refresh'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Color(0xFF03B0C1),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          ElevatedButton.icon(
                                            onPressed: () async {
                                              final result =
                                                  await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) =>
                                                        AddBusPage()),
                                              );
                                              if (result != null) {
                                                _fetchBusDetails(); // Refresh the list
                                              }
                                            },
                                            icon: Icon(Icons.add),
                                            label: Text('Add Bus'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Color(0xFF03B0C1),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              if (isEditMode) {
                                                saveAllChanges();
                                              } else {
                                                setState(() {
                                                  isEditMode = true;
                                                  editingRows
                                                      .clear(); // Clear individual row edits
                                                });
                                              }
                                            },
                                            icon: Icon(isEditMode
                                                ? Icons.save
                                                : Icons.edit),
                                            label: Text(isEditMode
                                                ? 'Save All'
                                                : 'Edit All'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Color(0xFF03B0C1),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          onChanged: filterSearchResults,
                                          decoration: InputDecoration(
                                            prefixIcon: Icon(Icons.search),
                                            hintText: 'Search...',
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      DropdownButton<String>(
                                        value: selectedTime,
                                        onChanged: (String? newValue) {
                                          setState(() {
                                            selectedTime = newValue!;
                                            filterBuses();
                                          });
                                        },
                                        items: <String>[
                                          'Morning',
                                          'Afternoon',
                                          'Evening'
                                        ].map<DropdownMenuItem<String>>(
                                            (String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(value),
                                          );
                                        }).toList(),
                                      ),
                                      SizedBox(width: 10),
                                      DropdownButton<String>(
                                        value: selectedShift,
                                        onChanged: (String? newValue) {
                                          setState(() {
                                            selectedShift = newValue!;
                                            filterBuses();
                                          });
                                        },
                                        items: <String>[
                                          'Shift 1',
                                          'Shift 2',
                                          'Shift 3'
                                        ].map<DropdownMenuItem<String>>(
                                            (String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(value),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 20),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.vertical,
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: DataTable(
                                          columnSpacing: 20,
                                          dataRowMinHeight: 60,
                                          dataRowMaxHeight: 80,
                                          columns: [
                                            DataColumn(
                                                label: Text('Bus Number')),
                                            DataColumn(
                                                label: Text('Bus Seats')),
                                            DataColumn(
                                                label: Text('Bus Route')),
                                            DataColumn(
                                                label:
                                                    Text('Registration Plate')),
                                            DataColumn(label: Text('Shift')),
                                            DataColumn(label: Text('Time')),
                                            DataColumn(label: Text('Status')),
                                            DataColumn(label: Text('Actions')),
                                          ],
                                          rows: List<DataRow>.generate(
                                            _assignmentRows.length,
                                            (index) {
                                              final row =
                                                  _assignmentRows[index];
                                              return DataRow(cells: [
                                                DataCell(Text(
                                                    row['busNumber'] ?? '')),
                                                DataCell(Text(
                                                    row['busSeats'] ?? '')),
                                                DataCell(Text(
                                                    row['busRoute'] ?? '')),
                                                DataCell(Text(
                                                    row['registrationPlate'] ??
                                                        '')),
                                                DataCell(
                                                    Text(row['shift'] ?? '')),
                                                DataCell(
                                                    Text(row['time'] ?? '')),
                                                DataCell(
                                                    Text(row['status'] ?? '')),
                                                DataCell(Text(row[
                                                            'assignment_id'] !=
                                                        null
                                                    ? '#${row['assignment_id']}'
                                                    : '')),
                                              ]);
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                  ),
                ),
              ),
            ],
          ),
          // Chatbot Floating Action Button (toggles the in-app chatbot window)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _toggleChatbot,
              backgroundColor: Color(0xFF03B0C1),
              child: Icon(
                _isChatbotOpen ? Icons.close : Icons.add_comment,
                color: Colors.white,
              ),
              tooltip: 'Chat with Assistant',
            ),
          ),
          // Chatbot Window (conditionally displayed)
          if (_isChatbotOpen) _buildChatbotWindow(),
        ],
      ),
    );
  }
}
