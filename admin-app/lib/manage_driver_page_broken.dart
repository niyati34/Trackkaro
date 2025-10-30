import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:new_app/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_driver_page.dart';
import 'common_sidebar.dart';
import 'services/drivers_api.dart';

class ManageDriverPage extends StatefulWidget {
  @override
  _ManageDriverPageState createState() => _ManageDriverPageState();
}

class _ManageDriverPageState extends State<ManageDriverPage> {
  List<Map<String, dynamic>> drivers = [];
  bool isLoading = true;
  bool isError = false;
  String? _token;
  final _driversApi = DriversApiService();

  List<Map<String, dynamic>> filteredDrivers = [];
  TextEditingController _searchController = TextEditingController();

  // Edit functionality
  bool isBulkEditing = false;
  Set<String> editingDriverIds = <String>{};
  Map<String, Map<String, TextEditingController>> driverControllers = {};

  // --- Chatbot related variables (copied from StudentDetailPage) ---
  bool _isChatbotOpen = false;
  final List<Map<String, dynamic>> _messages =
      []; // Use dynamic for quick_responses
  final TextEditingController _chatbotInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  // --- End Chatbot variables ---

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

  @override
  void initState() {
    super.initState();
    _fetchDriverDetails();
  }

  Future<void> _promptAssignBus(String driverId) async {
    final assignmentController = TextEditingController();
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Assign Bus to Driver'),
        content: TextField(
          controller: assignmentController,
          decoration: InputDecoration(
            labelText: 'Assignment ID',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(
                  ctx, {'assignment_id': assignmentController.text.trim()}),
              child: Text('Assign')),
        ],
      ),
    );

    if (result == null) return;
    final assignmentId = result['assignment_id'] ?? '';
    if (assignmentId.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Assignment ID is required')));
      return;
    }
    await _assignBusToDriver(driverId, assignmentId);
  }

  Future<void> _promptRevokeBus(String driverId) async {
    final assignmentController = TextEditingController();
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Revoke Driver from Bus'),
        content: TextField(
          controller: assignmentController,
          decoration: InputDecoration(
            labelText: 'Assignment ID',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(
                  ctx, {'assignment_id': assignmentController.text.trim()}),
              child: Text('Revoke')),
        ],
      ),
    );

    if (result == null) return;
    final assignmentId = result['assignment_id'] ?? '';
    if (assignmentId.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Assignment ID is required')));
      return;
    }
    await _revokeDriverFromBus(driverId, assignmentId);
  }

  Future<void> _assignBusToDriver(String driverId, String assignmentId) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Assigning bus...'), duration: Duration(seconds: 30)));
      final url =
          Uri.parse('${dotenv.env['BACKEND_API']}/assign-bus-to-driver');
      final payload = {
        'organization_id': _token,
        'driver_id': int.tryParse(driverId) ?? driverId,
        'assignment_id': int.tryParse(assignmentId) ?? assignmentId,
      };
      final res = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload));
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ Bus assigned to driver successfully'),
            backgroundColor: Colors.green));
        _fetchDriverDetails();
      } else {
        String msg = 'Failed to assign bus';
        try {
          final j = jsonDecode(res.body);
          msg = j['message'] ?? j['error'] ?? msg;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ $msg'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Network error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _revokeDriverFromBus(
      String driverId, String assignmentId) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Revoking driver from bus...'),
          duration: Duration(seconds: 30)));
      final url =
          Uri.parse('${dotenv.env['BACKEND_API']}/revoke-driver-from-bus');
      final payload = {
        'organization_id': _token,
        'driver_id': int.tryParse(driverId) ?? driverId,
        'assignment_id': int.tryParse(assignmentId) ?? assignmentId,
      };
      final res = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload));
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ Driver revoked from bus successfully'),
            backgroundColor: Colors.green));
        _fetchDriverDetails();
      } else {
        String msg = 'Failed to revoke driver';
        try {
          final j = jsonDecode(res.body);
          msg = j['message'] ?? j['error'] ?? msg;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ $msg'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Network error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _disposeAllControllers();
    // Dispose chatbot controllers
    _chatbotInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
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

  Future<void> _fetchDriverDetails() async {
    await _getOrganizationToken();
    if (_token == null) return;
    setState(() {
      isLoading = true;
      isError = false;
    });
    try {
      final raw = await _driversApi.getAllDrivers(_token!);
      setState(() {
        drivers = raw.map((bus) {
          String status = 'Active';
          if (bus['status'] != null) {
            final v = bus['status'].toString().toLowerCase();
            if (v == '0' || v == 'inactive' || v == 'false')
              status = 'Inactive';
          }
          return {
            'name': bus['driver_name']?.toString() ?? 'N/A',
            'phone': bus['driver_phone']?.toString() ?? 'N/A',
            'address': bus['driver_address']?.toString() ?? 'N/A',
            'route': bus['driver_route']?.toString() ?? 'N/A',
            'busNumber': bus['driver_busnumber']?.toString() ?? 'N/A',
            'salary': bus['driver_salary']?.toString() ?? 'N/A',
            'status': status,
            'id': bus['id'].toString(),
            'driver_photo': bus['driver_photo']?.toString() ?? 'photo.jpg'
          };
        }).toList();
        filteredDrivers = List.from(drivers);
        isLoading = false;
      });
    } catch (e) {
      print('Driver service failed: $e');
      setState(() {
        isLoading = false;
        isError = true;
      });
    }
  }

  void _filterDrivers(String query) {
    List<Map<String, dynamic>> filtered = drivers.where((driver) {
      return driver.values.any((value) =>
          value.toString().toLowerCase().contains(query.toLowerCase()));
    }).toList();
    setState(() {
      filteredDrivers = filtered;
      // Clear editing states when filtering
      editingDriverIds.clear();
      _disposeAllControllers();
      isBulkEditing = false;
    });
  }

  void _deleteDriver(int index) async {
    final driver = filteredDrivers[index];
    final String driverId = driver['id'].toString();
    final url = Uri.parse('${dotenv.env['BACKEND_API']}/delete-driver');

    // Show confirmation dialog first
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Delete'),
          content: Text(
              'Are you sure you want to delete ${driver['name']}? This action cannot be undone.'),
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

    print("Deleting driver with ID: $driverId");
    try {
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'id': driverId,
          "organization_id": _token,
        }),
      );

      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (response.statusCode == 200) {
        setState(() {
          filteredDrivers.removeAt(index);
          drivers.removeWhere((driver) => driver['id'] == driverId);
          editingDriverIds.remove(driverId);
          _disposeDriverControllers(driverId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Driver deleted successfully!'),
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
              'Failed to delete driver';
        } catch (e) {
          errorMessage = 'Server returned: ${response.statusCode}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to delete driver: $errorMessage'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      print('Error deleting driver: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Network error: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  void _addDriver() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddDriverPage()),
    );

    if (result != null && result == true) {
      await _fetchDriverDetails();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Driver successfully added!')),
      );
    }
  }

  // Individual row edit functionality
  void _editRow(String driverId) {
    print('Edit button clicked for driver: $driverId');

    if (editingDriverIds.contains(driverId)) {
      // Save this row
      _saveRowChanges(driverId);
    } else {
      // Edit this row
      setState(() {
        editingDriverIds.add(driverId);
        _initializeDriverControllers(driverId);
      });
      print('Driver $driverId is now in edit mode');
    }
  }

  // Bulk edit functionality
  void _toggleBulkEdit() {
    setState(() {
      if (isBulkEditing) {
        // Save all changes when exiting bulk edit mode
        _saveBulkChanges();
      } else {
        // Enter bulk edit mode
        isBulkEditing = true;
        editingDriverIds.clear();
        _disposeAllControllers();
        // Initialize controllers for all visible drivers
        for (var driver in filteredDrivers) {
          _initializeDriverControllers(driver['id']);
        }
        print('Bulk edit mode activated for ${filteredDrivers.length} drivers');
      }
    });
  }

  void _initializeDriverControllers(String driverId) {
    print('Initializing controllers for driver: $driverId');

    // Find the driver in filteredDrivers
    final driver = filteredDrivers.firstWhere(
      (d) => d['id'] == driverId,
      orElse: () => <String, dynamic>{},
    );

    if (driver.isEmpty) {
      print('Driver not found for ID: $driverId');
      return;
    }

    // Dispose existing controllers for this driver if they exist
    _disposeDriverControllers(driverId);

    // Create new controllers with current values
    driverControllers[driverId] = {
      'name': TextEditingController(text: driver['name']?.toString() ?? ''),
      'phone': TextEditingController(text: driver['phone']?.toString() ?? ''),
      'address':
          TextEditingController(text: driver['address']?.toString() ?? ''),
      'route': TextEditingController(text: driver['route']?.toString() ?? ''),
      'busNumber':
          TextEditingController(text: driver['busNumber']?.toString() ?? ''),
      'salary': TextEditingController(text: driver['salary']?.toString() ?? ''),
    };

    print('Controllers initialized for driver: $driverId');
  }

  Future<void> _saveRowChanges(String driverId) async {
    try {
      print('Saving changes for driver: $driverId');

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 10),
              Text('Updating driver...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );

      final controllers = driverControllers[driverId];
      if (controllers == null) {
        print('No controllers found for driver: $driverId');
        _showErrorSnackBar('Error: No controllers found for driver');
        return;
      }

      final driverIndex =
          filteredDrivers.indexWhere((d) => d['id'] == driverId);
      if (driverIndex == -1) {
        print('Driver not found in filtered list: $driverId');
        _showErrorSnackBar('Error: Driver not found');
        return;
      }

      // driver variable removed; controllers supply updated values

      // Validate required fields
      if (controllers['name']!.text.trim().isEmpty) {
        _showErrorSnackBar('Driver name cannot be empty');
        return;
      }

      final url = Uri.parse('${dotenv.env['BACKEND_API']}/update-driver');
      print('API URL: $url');

      // Status conversion removed (not used in update payload per backend contract)

      final int? salary = int.tryParse(controllers['salary']!.text.trim());
      final updatedData = {
        'id': int.tryParse(driverId) ?? driverId,
        'organization_id': _token,
        'driver_name': controllers['name']!.text.trim(),
        'driver_phone': controllers['phone']!.text.trim(),
        'driver_address': controllers['address']!.text.trim(),
        // 'driver_route' and 'driver_busnumber' are managed via separate assign API
        'driver_salary': salary ?? controllers['salary']!.text.trim(),
        // 'status' not part of the update-driver contract; omitted
      };

      print('Sending payload: ${jsonEncode(updatedData)}');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(updatedData),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      // Hide loading snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (response.statusCode == 200) {
        // Update local data
        setState(() {
          filteredDrivers[driverIndex]['name'] =
              controllers['name']!.text.trim();
          filteredDrivers[driverIndex]['phone'] =
              controllers['phone']!.text.trim();
          filteredDrivers[driverIndex]['address'] =
              controllers['address']!.text.trim();
          filteredDrivers[driverIndex]['route'] =
              controllers['route']!.text.trim();
          filteredDrivers[driverIndex]['busNumber'] =
              controllers['busNumber']!.text.trim();
          filteredDrivers[driverIndex]['salary'] =
              controllers['salary']!.text.trim();

          // Update main drivers list as well
          final mainIndex = drivers.indexWhere((d) => d['id'] == driverId);
          if (mainIndex != -1) {
            drivers[mainIndex] = Map.from(filteredDrivers[driverIndex]);
          }

          editingDriverIds.remove(driverId);
          _disposeDriverControllers(driverId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Driver updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        String errorMessage = 'Failed to update driver';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          } else if (errorData['error'] != null) {
            errorMessage = errorData['error'];
          }
        } catch (e) {
          errorMessage =
              'Failed to update driver (Status: ${response.statusCode})';
        }
        _showErrorSnackBar('❌ $errorMessage');
      }
    } catch (e) {
      print('Error updating driver: $e');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showErrorSnackBar('❌ Network error: Please check your connection');
    }
  }

  Future<void> _saveBulkChanges() async {
    int successCount = 0;
    int totalCount = driverControllers.length;

    if (totalCount == 0) {
      setState(() {
        isBulkEditing = false;
      });
      return;
    }

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 10),
            Text('Updating $totalCount drivers...'),
          ],
        ),
        duration: Duration(minutes: 2),
      ),
    );

    List<Future<void>> updateFutures = [];
    for (String driverId in driverControllers.keys.toList()) {
      // Use .toList() to avoid concurrent modification
      // CORRECTED LINE: Call the async function and add its returned Future
      updateFutures.add((() async {
        final controllers = driverControllers[driverId];
        if (controllers == null) return;

        final driverIndex =
            filteredDrivers.indexWhere((d) => d['id'] == driverId);
        if (driverIndex == -1) return;

        final driver = filteredDrivers[driverIndex];
        final url = Uri.parse('${dotenv.env['BACKEND_API']}/update-driver');

        final int? salary = int.tryParse(controllers['salary']!.text.trim());
        final updatedData = {
          'id': int.tryParse(driverId) ?? driverId,
          'organization_id': _token,
          'driver_name': controllers['name']!.text.trim(),
          'driver_phone': controllers['phone']!.text.trim(),
          'driver_address': controllers['address']!.text.trim(),
          // route/bus managed via assign API
          'driver_salary': salary ?? controllers['salary']!.text.trim(),
        };

        try {
          final response = await http.put(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(updatedData),
          );

          if (response.statusCode == 200) {
            // Update local data
            setState(() {
              filteredDrivers[driverIndex]['name'] =
                  controllers['name']!.text.trim();
              filteredDrivers[driverIndex]['phone'] =
                  controllers['phone']!.text.trim();
              filteredDrivers[driverIndex]['address'] =
                  controllers['address']!.text.trim();
              filteredDrivers[driverIndex]['route'] =
                  controllers['route']!.text.trim();
              filteredDrivers[driverIndex]['busNumber'] =
                  controllers['busNumber']!.text.trim();
              filteredDrivers[driverIndex]['salary'] =
                  controllers['salary']!.text.trim();

              // Update main drivers list as well
              final mainIndex = drivers.indexWhere((d) => d['id'] == driverId);
              if (mainIndex != -1) {
                drivers[mainIndex] = Map.from(filteredDrivers[driverIndex]);
              }
            });
            successCount++;
          }
        } catch (e) {
          print('Error updating driver ${driver['name']}: $e');
        } finally {
          // Dispose controller for this driver after its update attempt
          _disposeDriverControllers(driverId);
        }
      })()); // <--- Crucial change here: calling the async function immediately
    }

    await Future.wait(updateFutures);

    setState(() {
      isBulkEditing = false;
      editingDriverIds.clear();
      // _disposeAllControllers() is implicitly called by the loop's finally block
    });

    // Hide loading snackbar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '✅ $successCount of $totalCount drivers updated successfully!'),
        backgroundColor:
            successCount == totalCount ? Colors.green : Colors.orange,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _disposeDriverControllers(String driverId) {
    if (driverControllers.containsKey(driverId)) {
      for (var controller in driverControllers[driverId]!.values) {
        controller.dispose();
      }
      driverControllers.remove(driverId);
    }
  }

  void _disposeAllControllers() {
    for (var controllers in driverControllers.values) {
      for (var controller in controllers.values) {
        controller.dispose();
      }
    }
    driverControllers.clear();
  }

  Widget _buildEditableField(
      String driverId, String fieldKey, String initialValue) {
    // Ensure controllers exist
    if (!driverControllers.containsKey(driverId)) {
      print('Warning: Controllers not found for $driverId, initializing...');
      _initializeDriverControllers(driverId);
    }

    // Double check that the controller exists
    if (!driverControllers.containsKey(driverId) ||
        !driverControllers[driverId]!.containsKey(fieldKey)) {
      print('Error: Controller still not found for $driverId - $fieldKey');
      return Container(
        padding: EdgeInsets.all(8),
        child: Text(
          initialValue,
          style: TextStyle(fontSize: 14),
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(minWidth: 100),
      child: TextField(
        controller: driverControllers[driverId]![fieldKey],
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.blue),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          isDense: true,
        ),
        style: TextStyle(fontSize: 14),
        maxLines: fieldKey == 'address' ? 2 : 1,
      ),
    );
  }

  // --- Chatbot Functionality (copied and adapted from StudentDetailPage) ---
  void _toggleChatbot() {
    setState(() {
      _isChatbotOpen = !_isChatbotOpen;
      if (!_isChatbotOpen) {
        _messages.clear(); // Clear messages when closing
        _chatbotInputController.clear();
      } else {
        // Optional: Add an initial welcome message from the bot
        if (_messages.isEmpty) {
          _getChatbotResponse("Hi there! How can I help you with drivers?",
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
            if (lowerCaseBotResponse
                    .contains("Is Kiran assigned in any shift?") ||
                lowerCaseBotResponse.contains("salary")) {
              quickResponses = [
                "Is Ramesh available in the morning?",
                "What is the status of driver Suresh?",
                "What shift is driver Rahul working?"
              ];
            } else if (lowerCaseBotResponse
                    .contains("Show me if Nikhil is free or assigned.") ||
                lowerCaseBotResponse.contains("Who is not assigned any bus?")) {
              quickResponses = ["List all available drivers."];
            } else {
              quickResponses = [
                "Is Amit driving in the evening?",
                "Is Kiran assigned in any shift?"
              ];
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
            "Hello! I'm your Driver Management Assistant. Ask me anything about drivers!";
        quickResponses = [
          "Is Amit driving in the evening?",
          "What is the status of driver Suresh?",
          "Show all free drivers."
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
                      // For now, assuming you have a placeholder or it defaults to the Icon.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Driver Management',
          style: GoogleFonts.dmSans(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF03B0C1),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isMobile = constraints.maxWidth < 600;

          return Stack(
            // Use Stack to overlay the chatbot window
            children: [
              Row(
                children: [
                  // CommonSidebar Widget
                  CommonSidebar(
                    isMobile: isMobile,
                    onNavigate: (index) {
                      // Implement navigation logic based on index
                    },
                  ),
                  // Main Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(24),
                      child: _modernPageCard(
                        child: _modernHeader(
                          title: 'Driver Management Dashboard',
                          child: _buildDriverContent(),
                        ),
                      ),
                    ),
                  ),
                                        SizedBox(height: 10),
                                        ElevatedButton(
                                          onPressed: _fetchDriverDetails,
                                          child: Text('Retry'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Color(0xFF03B0C1),
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.person, size: 24),
                                              SizedBox(width: 10),
                                              Text(
                                                'Manage Drivers',
                                                style: TextStyle(
                                                  fontSize: 20.0,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Wrap(
                                            spacing: 10,
                                            children: [
                                              ElevatedButton.icon(
                                                onPressed: _fetchDriverDetails,
                                                icon: Icon(Icons.refresh),
                                                label: Text('Refresh'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Color(0xFF03B0C1),
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                  ),
                                                ),
                                              ),
                                              ElevatedButton.icon(
                                                onPressed: _addDriver,
                                                icon: Icon(Icons.add,
                                                    color: Colors.white),
                                                label: Text(
                                                  'Add Driver',
                                                  style: TextStyle(
                                                      color: Colors.white),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Color(0xFF03B0C1),
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 15),
                                                ),
                                              ),
                                              ElevatedButton.icon(
                                                onPressed: _toggleBulkEdit,
                                                icon: Icon(
                                                  isBulkEditing
                                                      ? Icons.save
                                                      : Icons.edit_note,
                                                  color: Colors.white,
                                                ),
                                                label: Text(
                                                  isBulkEditing
                                                      ? "Save All Changes"
                                                      : "Bulk Edit",
                                                  style: TextStyle(
                                                      color: Colors.white),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: isBulkEditing
                                                      ? Colors.green
                                                      : Color(0xFF03B0C1),
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 15),
                                                ),
                                              ),
                                              if (isBulkEditing)
                                                ElevatedButton.icon(
                                                  onPressed: () {
                                                    setState(() {
                                                      isBulkEditing = false;
                                                      editingDriverIds.clear();
                                                      _disposeAllControllers();
                                                    });
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                          content: Text(
                                                              'Bulk edit cancelled. Changes reverted.')),
                                                    );
                                                  },
                                                  icon: Icon(Icons.cancel,
                                                      color: Colors.white),
                                                  label: Text(
                                                    'Cancel',
                                                    style: TextStyle(
                                                        color: Colors.white),
                                                  ),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red,
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 20,
                                                            vertical: 15),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 10),
                                      Divider(height: 20, thickness: 1),
                                      TextField(
                                        controller: _searchController,
                                        decoration: InputDecoration(
                                          hintText: 'Search...',
                                          prefixIcon: Icon(Icons.search),
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 15),
                                        ),
                                        onChanged: _filterDrivers,
                                      ),
                                      SizedBox(height: 10),
                                      if (isBulkEditing)
                                        Container(
                                          padding: EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.info,
                                                  color: Colors.blue),
                                              SizedBox(width: 10),
                                              Expanded(
                                                // Use Expanded to prevent overflow
                                                child: Text(
                                                  'Bulk Edit Mode: All fields are editable. Click "Save All Changes" to update all or "Cancel" to revert.',
                                                  style: TextStyle(
                                                      color:
                                                          Colors.blue.shade700),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      SizedBox(height: 10),
                                      Expanded(
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: DataTable(
                                            columnSpacing: 20,
                                            dataRowMinHeight: 60,
                                            dataRowMaxHeight: 80,
                                            columns: [
                                              DataColumn(
                                                  label: Text('Name',
                                                      style: TextStyle(
                                                          fontWeight: FontWeight
                                                              .bold))),
                                              DataColumn(
                                                  label: Text('Phone',
                                                      style: TextStyle(
                                                          fontWeight: FontWeight
                                                              .bold))),
                                              DataColumn(
                                                  label: Text('Address',
                                                      style: TextStyle(
                                                          fontWeight: FontWeight
                                                              .bold))),
                                              DataColumn(
                                                  label: Text('Route',
                                                      style: TextStyle(
                                                          fontWeight: FontWeight
                                                              .bold))),
                                              DataColumn(
                                                  label: Text('Bus Number',
                                                      style: TextStyle(
                                                          fontWeight: FontWeight
                                                              .bold))),
                                              DataColumn(
                                                  label: Text('Salary',
                                                      style: TextStyle(
                                                          fontWeight: FontWeight
                                                              .bold))),
                                              DataColumn(
                                                  label: Text('Status',
                                                      style: TextStyle(
                                                          fontWeight: FontWeight
                                                              .bold))),
                                              DataColumn(
                                                  label: Text('Actions',
                                                      style: TextStyle(
                                                          fontWeight: FontWeight
                                                              .bold))),
                                            ],
                                            rows: List<DataRow>.generate(
                                              filteredDrivers.length,
                                              (index) {
                                                final driver =
                                                    filteredDrivers[index];
                                                final String driverId =
                                                    driver['id'].toString();
                                                final bool isRowEditing =
                                                    isBulkEditing ||
                                                        editingDriverIds
                                                            .contains(driverId);

                                                return DataRow(
                                                    color: MaterialStateProperty
                                                        .resolveWith<Color?>(
                                                      (Set<MaterialState>
                                                          states) {
                                                        if (isRowEditing) {
                                                          return Colors
                                                              .yellow.shade50;
                                                        }
                                                        return null;
                                                      },
                                                    ),
                                                    cells: [
                                                      DataCell(isRowEditing
                                                          ? _buildEditableField(
                                                              driverId,
                                                              'name',
                                                              driver['name']!)
                                                          : Text(
                                                              driver['name'] ??
                                                                  '')),
                                                      DataCell(isRowEditing
                                                          ? _buildEditableField(
                                                              driverId,
                                                              'phone',
                                                              driver['phone']!)
                                                          : Text(
                                                              driver['phone'] ??
                                                                  '')),
                                                      DataCell(isRowEditing
                                                          ? _buildEditableField(
                                                              driverId,
                                                              'address',
                                                              driver[
                                                                  'address']!)
                                                          : Text(driver[
                                                                  'address'] ??
                                                              '')),
                                                      DataCell(Text(
                                                          driver['route'] ??
                                                              '')),
                                                      DataCell(Text(
                                                          driver['busNumber'] ??
                                                              '')),
                                                      DataCell(isRowEditing
                                                          ? _buildEditableField(
                                                              driverId,
                                                              'salary',
                                                              driver['salary']!)
                                                          : Text(driver[
                                                                  'salary'] ??
                                                              '')),
                                                      DataCell(Text(
                                                          driver['status'] ??
                                                              '')),
                                                      DataCell(Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          if (!isBulkEditing)
                                                            IconButton(
                                                              icon: Icon(
                                                                editingDriverIds
                                                                        .contains(
                                                                            driverId)
                                                                    ? Icons.save
                                                                    : Icons
                                                                        .edit,
                                                                color: editingDriverIds
                                                                        .contains(
                                                                            driverId)
                                                                    ? Colors
                                                                        .green
                                                                    : Colors
                                                                        .blue,
                                                              ),
                                                              onPressed: () =>
                                                                  _editRow(
                                                                      driverId),
                                                              tooltip: editingDriverIds
                                                                      .contains(
                                                                          driverId)
                                                                  ? 'Save Changes'
                                                                  : 'Edit Driver',
                                                            ),
                                                          // Assign/Revoke bus actions
                                                          IconButton(
                                                            icon: Icon(
                                                                Icons.link,
                                                                color: Colors
                                                                    .teal),
                                                            tooltip:
                                                                'Assign Bus to Driver',
                                                            onPressed: () =>
                                                                _promptAssignBus(
                                                                    driverId),
                                                          ),
                                                          IconButton(
                                                            icon: Icon(
                                                                Icons.link_off,
                                                                color: Colors
                                                                    .orange),
                                                            tooltip:
                                                                'Revoke Driver from Bus',
                                                            onPressed: () =>
                                                                _promptRevokeBus(
                                                                    driverId),
                                                          ),
                                                          IconButton(
                                                            icon: Icon(
                                                                Icons.delete,
                                                                color:
                                                                    Colors.red),
                                                            onPressed: () =>
                                                                _deleteDriver(
                                                                    index),
                                                            tooltip:
                                                                'Delete Driver',
                                                          ),
                                                        ],
                                                      )),
                                                    ]);
                                              },
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
          );
        },
      ),
    );
  }
}
