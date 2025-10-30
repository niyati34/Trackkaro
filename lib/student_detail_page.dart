import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:new_app/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; // Still needed for _openLocation
import 'add_student_page.dart';
import 'ui/design_system.dart';
// Added service for unified student fetching with diagnostics
import 'services/students_api.dart';

class StudentDetailPage extends StatefulWidget {
  @override
  _StudentDetailPageState createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> filteredStudents = [];
  bool isLoading = true;
  bool isError = false;
  String? _token;

  bool isBulkEditing = false;
  Set<int> editingRows = <int>{};
  Map<int, Map<String, TextEditingController>> rowControllers =
      <int, Map<String, TextEditingController>>{};

  // --- Chatbot related variables (copied from LiveTrackingPage) ---
  bool _isChatbotOpen = false;
  final List<Map<String, dynamic>> _messages =
      []; // Use dynamic for quick_responses
  final TextEditingController _chatbotInputController = TextEditingController();
  final ScrollController _chatScrollController =
      ScrollController(); // To auto-scroll chat
  // --- End Chatbot variables ---

  @override
  void initState() {
    super.initState();
    _fetchStudentDetails();
  }

  @override
  void dispose() {
    _searchController.dispose();
    // Dispose all student table text controllers
    rowControllers.forEach((index, controllers) {
      controllers.forEach((key, controller) {
        controller.dispose();
      });
    });
    rowControllers.clear(); // Ensure the map is cleared
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

  Future<void> _fetchStudentDetails() async {
    await _getOrganizationToken();
    if (_token == null) {
      setState(() {
        isLoading = false;
        isError = true;
      });
      return;
    }
    setState(() {
      isLoading = true;
      isError = false;
    });
    try {
      final api = StudentsApiService();
      final list = await api.getAllStudentsWithFallback(_token!);
      students = list
          .map((s) => {
                'Enrollment No.': s.enrollmentNumber,
                'Name': s.name,
                'Phone Number': s.phone,
                'Bus Number': s.busNumber,
                'Address': s.address,
                'Bus Fees Paid': s.busFeePaid ? 'Yes' : 'No',
                'Email Address': s.email,
                'id': s.id,
              })
          .toList();
      filteredStudents = List.from(students);
      _initializeControllers();
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        isError = true;
      });
    }
  }

  void _initializeControllers() {
    // Clear existing controllers
    rowControllers.forEach((index, controllers) {
      controllers.forEach((key, controller) {
        controller.dispose();
      });
    });
    rowControllers.clear();

    // Initialize controllers for all filtered students
    for (int i = 0; i < filteredStudents.length; i++) {
      rowControllers[i] = {
        'Enrollment No.':
            TextEditingController(text: filteredStudents[i]['Enrollment No.']),
        'Name': TextEditingController(text: filteredStudents[i]['Name']),
        'Phone Number':
            TextEditingController(text: filteredStudents[i]['Phone Number']),
        'Bus Number':
            TextEditingController(text: filteredStudents[i]['Bus Number']),
        'Address': TextEditingController(text: filteredStudents[i]['Address']),
        'Email Address':
            TextEditingController(text: filteredStudents[i]['Email Address']),
      };
    }
  }

  void _filterStudents(String query) {
    List<Map<String, dynamic>> filtered = students.where((student) {
      return student.values.any((value) =>
          value.toString().toLowerCase().contains(query.toLowerCase()));
    }).toList();
    setState(() {
      filteredStudents = filtered;
      // Clear editing state when filtering
      editingRows.clear();
      isBulkEditing = false;
      _initializeControllers(); // Re-initialize controllers for the new filtered list
    });
  }

  Future<void> _addStudent() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddStudentPage()),
    );
    if (result != null) {
      await _fetchStudentDetails();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Student successfully added!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteStudent(int index) async {
    final student = filteredStudents[index];
    final String studentId = student['id'].toString();

    // Show confirmation dialog first
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Delete'),
          content: Text(
              'Are you sure you want to delete ${student['Name']}? This action cannot be undone.'),
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
      final String url = '${dotenv.env['BACKEND_API']}/delete-student';

      print('Attempting to delete student with ID: $studentId');
      print('Using token: $_token');
      print('API URL: $url');

      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'id': studentId.toString(),
          'organization_id': dotenv.env['ORGANIZATION_ID'] ?? '1',
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('✅ Student "${student['Name']}" deleted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        // Try to parse error message from response
        String errorMessage = 'Unknown error occurred';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['message'] ??
              errorData['error'] ??
              'Failed to delete student';
        } catch (e) {
          errorMessage = 'Server returned: ${response.statusCode}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to delete student: $errorMessage'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      print('Delete error: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Network error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  void _openLocation(String address) async {
    final String googleUrl =
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';
    final Uri url = Uri.parse(googleUrl);

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the map for "$address".')),
      );
    }
  }

  void _toggleBulkEdit() {
    setState(() {
      if (isBulkEditing) {
        // If exiting bulk edit mode, trigger saving all changes
        _saveBulkChanges();
      } else {
        // If entering bulk edit mode
        isBulkEditing = true;
        editingRows.clear(); // Clear any individual row editing states
        // All filtered students are now implicitly editable, so no need to add to editingRows set for bulk.
      }
    });
  }

  // Save all changes in bulk edit mode
  Future<void> _saveBulkChanges() async {
    int successCount = 0;
    int totalCount = filteredStudents.length;

    // Show a global loading indicator for bulk save
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
            SizedBox(width: 10),
            Text('Saving all student changes...'),
          ],
        ),
        duration: Duration(minutes: 2), // Long duration for bulk save
        backgroundColor: Colors.blue.shade700,
      ),
    );

    List<Future<void>> updateFutures = [];

    for (int i = 0; i < filteredStudents.length; i++) {
      final controllers = rowControllers[i];
      if (controllers == null) continue; // Skip if no controllers for this row

      final student = filteredStudents[i];
      final String studentId = student['id'].toString();
      final String url = '${dotenv.env['BACKEND_API']}/update-student';

      final updatedData = {
        'id': studentId,
        'organization_id': _token,
        'enrollment_number': controllers['Enrollment No.']!.text,
        'student_name': controllers['Name']!.text,
        'student_phone': controllers['Phone Number']!.text,
        'student_address': controllers['Address']!.text,
        'email': controllers['Email Address']!.text,
        // Convert 'Yes'/'No' to boolean for API as busfee_paid
        'busfee_paid':
            (student['Bus Fees Paid']?.toString().toLowerCase() == 'yes'),
      };

      updateFutures.add(() async {
        try {
          final response = await http.put(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(updatedData),
          );

          if (response.statusCode == 200) {
            // Update local data for this specific student
            setState(() {
              // Using setState inside the loop is fine here as it's within a Future.wait
              filteredStudents[i]['Enrollment No.'] =
                  controllers['Enrollment No.']!.text;
              filteredStudents[i]['Name'] = controllers['Name']!.text;
              filteredStudents[i]['Phone Number'] =
                  controllers['Phone Number']!.text;
              filteredStudents[i]['Bus Number'] =
                  controllers['Bus Number']!.text;
              filteredStudents[i]['Address'] = controllers['Address']!.text;
              filteredStudents[i]['Email Address'] =
                  controllers['Email Address']!.text;

              // Update main students list as well to keep it in sync
              final mainIndex =
                  students.indexWhere((s) => s['id'] == studentId);
              if (mainIndex != -1) {
                students[mainIndex] = Map.from(filteredStudents[i]);
              }
            });
            successCount++;
          } else {
            print(
                'Failed to update student ${student['Name']}: ${response.body}');
          }
        } catch (e) {
          print('Error updating student ${student['Name']}: $e');
        }
      }());
    }

    await Future.wait(
        updateFutures); // Wait for all individual updates to complete

    setState(() {
      isBulkEditing = false;
      editingRows.clear(); // Clear any remaining individual edits
      // No need to _initializeControllers() here if data is updated in place during the loop
    });

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar(); // Hide the bulk saving indicator

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '✅ $successCount of $totalCount students updated successfully!'),
        backgroundColor:
            successCount == totalCount ? Colors.green : Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Toggle individual row edit
  void _toggleRowEdit(int index) {
    setState(() {
      if (editingRows.contains(index)) {
        // If currently editing, try to save
        _saveRowChanges(index);
      } else {
        // If not editing, start editing
        editingRows.add(index);
        // Ensure controllers have the latest data if starting edit
        if (rowControllers[index] != null) {
          rowControllers[index]!['Enrollment No.']!.text =
              filteredStudents[index]['Enrollment No.']!;
          rowControllers[index]!['Name']!.text =
              filteredStudents[index]['Name']!;
          rowControllers[index]!['Phone Number']!.text =
              filteredStudents[index]['Phone Number']!;
          rowControllers[index]!['Bus Number']!.text =
              filteredStudents[index]['Bus Number']!;
          rowControllers[index]!['Address']!.text =
              filteredStudents[index]['Address']!;
          rowControllers[index]!['Email Address']!.text =
              filteredStudents[index]['Email Address']!;
        }
      }
    });
  }

  // Save individual row changes
  Future<void> _saveRowChanges(int index) async {
    final controllers = rowControllers[index];
    if (controllers == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: No controllers found for this row.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final student = filteredStudents[index];
    final String studentId = student['id'].toString();
    final String url = '${dotenv.env['BACKEND_API']}/update-student';

    // Show loading indicator for single row save
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
            SizedBox(width: 10),
            Text('Updating student...'),
          ],
        ),
        duration: Duration(seconds: 30),
        backgroundColor: Colors.blue.shade700,
      ),
    );

    final updatedData = {
      'id': studentId,
      'organization_id': _token,
      'enrollment_number': controllers['Enrollment No.']!.text,
      'student_name': controllers['Name']!.text,
      'student_phone': controllers['Phone Number']!.text,
      'student_address': controllers['Address']!.text,
      'email': controllers['Email Address']!.text,
      'busfee_paid':
          (student['Bus Fees Paid']?.toString().toLowerCase() == 'yes'),
    };

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updatedData),
      );

      ScaffoldMessenger.of(context)
          .hideCurrentSnackBar(); // Hide loading indicator

      if (response.statusCode == 200) {
        // Update local data
        setState(() {
          filteredStudents[index]['Enrollment No.'] =
              controllers['Enrollment No.']!.text;
          filteredStudents[index]['Name'] = controllers['Name']!.text;
          filteredStudents[index]['Phone Number'] =
              controllers['Phone Number']!.text;
          filteredStudents[index]['Bus Number'] =
              controllers['Bus Number']!.text;
          filteredStudents[index]['Address'] = controllers['Address']!.text;
          filteredStudents[index]['Email Address'] =
              controllers['Email Address']!.text;

          // Update main students list as well
          final mainIndex = students.indexWhere((s) => s['id'] == studentId);
          if (mainIndex != -1) {
            students[mainIndex] = Map.from(filteredStudents[index]);
          }

          editingRows.remove(index); // Exit editing mode for this row
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Student updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        String errorMessage = 'Failed to update student';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['message'] ??
              errorData['error'] ??
              'Failed to update student';
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

  // --- Chatbot Functionality (copied from LiveTrackingPage) ---
  void _toggleChatbot() {
    setState(() {
      _isChatbotOpen = !_isChatbotOpen;
      if (!_isChatbotOpen) {
        _messages.clear(); // Clear messages when closing
        _chatbotInputController.clear();
      } else {
        // Optional: Add an initial welcome message from the bot
        if (_messages.isEmpty) {
          _getChatbotResponse("Hi there! How can I help you with students?",
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
            if (lowerCaseBotResponse.contains("enrollment") ||
                lowerCaseBotResponse.contains("student id")) {
              quickResponses = [
                "How to find a student by ID?",
                "How to enroll a new student?"
              ];
            } else if (lowerCaseBotResponse.contains("bus fee") ||
                lowerCaseBotResponse.contains("payment")) {
              quickResponses = [
                "How to update bus fees?",
                "Check payment status."
              ];
            } else {
              quickResponses = [
                "Add a student",
                "Edit a student",
                "Delete a student",
                "Search for a student"
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
            "Hello! I'm your Student Management Assistant. Ask me anything about students!";
        quickResponses = [
          "Which students are on the RightTown Loop route?",
          "Who all are traveling via CityCenter Express?"
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

  Widget _buildEditableField(
      int rowIndex, String fieldKey, String initialValue) {
    if (!rowControllers.containsKey(rowIndex)) {
      return Text(initialValue);
    }

    if (!rowControllers[rowIndex]!.containsKey(fieldKey)) {
      return Text(initialValue);
    }

    return TextField(
      controller: rowControllers[rowIndex]![fieldKey],
      decoration: InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        isDense: true, // Makes the field more compact
      ),
      style: TextStyle(fontSize: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF03B0C1),
        elevation: 0,
        title: Text('TrackKaro'),
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
          return Stack(
            // Use Stack to overlay the chatbot window
            children: [
              Row(
                children: [
                  ModernSidebar(currentRoute: '/students'),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey,
                            width: 2.0,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: isLoading
                            ? Center(child: CircularProgressIndicator())
                            : isError
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                            'Failed to fetch Student details. Please try again.'),
                                        SizedBox(height: 10),
                                        ElevatedButton(
                                          onPressed: _fetchStudentDetails,
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
                                              Icon(Icons.school, size: 24),
                                              SizedBox(width: 10),
                                              Text(
                                                'Manage Student',
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
                                                onPressed: _fetchStudentDetails,
                                                icon: Icon(Icons.refresh,
                                                    color: Colors.white),
                                                label: Text('Refresh',
                                                    style: TextStyle(
                                                        color: Colors.white)),
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
                                                onPressed: _addStudent,
                                                icon: Icon(Icons.add,
                                                    color: Colors.white),
                                                label: Text(
                                                  'Add Students',
                                                  style: TextStyle(
                                                      color: Colors.white),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Color(0xFF03B0C1),
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 15),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                  ),
                                                ),
                                              ),
                                              ElevatedButton.icon(
                                                onPressed: _toggleBulkEdit,
                                                icon: Icon(
                                                    isBulkEditing
                                                        ? Icons.save
                                                        : Icons.edit_note,
                                                    color: Colors.white),
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
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                  ),
                                                ),
                                              ),
                                              if (isBulkEditing)
                                                ElevatedButton.icon(
                                                  onPressed: () {
                                                    setState(() {
                                                      isBulkEditing = false;
                                                      editingRows.clear();
                                                      _fetchStudentDetails(); // Revert changes by re-fetching data
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
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                    ),
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
                                        onChanged: _filterStudents,
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
                                            dataRowMinHeight:
                                                60, // Ensure enough height for dropdowns/text fields
                                            dataRowMaxHeight: 80,
                                            columns: [
                                              DataColumn(
                                                  label: Text('Enrollment No.',
                                                      style: TextStyle(
                                                          fontWeight: FontWeight
                                                              .bold))),
                                              DataColumn(
                                                  label: Text('Name',
                                                      style: TextStyle(
                                                          fontWeight: FontWeight
                                                              .bold))),
                                              DataColumn(
                                                  label: Text('Phone Number',
                                                      style: TextStyle(
                                                          fontWeight: FontWeight
                                                              .bold))),
                                              DataColumn(
                                                  label: Text('Bus Number',
                                                      style: TextStyle(
                                                          fontWeight: FontWeight
                                                              .bold))),
                                              DataColumn(
                                                  label: Text('Address',
                                                      style: TextStyle(
                                                          fontWeight: FontWeight
                                                              .bold))),
                                              DataColumn(
                                                  label: Text('Bus Fees Paid',
                                                      style: TextStyle(
                                                          fontWeight: FontWeight
                                                              .bold))),
                                              DataColumn(
                                                  label: Text('Email Address',
                                                      style: TextStyle(
                                                          fontWeight: FontWeight
                                                              .bold))),
                                              DataColumn(
                                                  label: Text('Action',
                                                      style: TextStyle(
                                                          fontWeight: FontWeight
                                                              .bold))),
                                            ],
                                            rows: filteredStudents
                                                .asMap()
                                                .entries
                                                .map((entry) {
                                              int index = entry.key;
                                              Map<String, dynamic> student =
                                                  entry.value;
                                              bool isRowEditing =
                                                  editingRows.contains(index) ||
                                                      isBulkEditing;

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
                                                            index,
                                                            'Enrollment No.',
                                                            student[
                                                                'Enrollment No.']!)
                                                        : Text(student[
                                                            'Enrollment No.']!)),
                                                    DataCell(isRowEditing
                                                        ? _buildEditableField(
                                                            index,
                                                            'Name',
                                                            student['Name']!)
                                                        : Text(
                                                            student['Name']!)),
                                                    DataCell(isRowEditing
                                                        ? _buildEditableField(
                                                            index,
                                                            'Phone Number',
                                                            student[
                                                                'Phone Number']!)
                                                        : Text(student[
                                                            'Phone Number']!)),
                                                    DataCell(isRowEditing
                                                        ? _buildEditableField(
                                                            index,
                                                            'Bus Number',
                                                            student[
                                                                'Bus Number']!)
                                                        : Text(student[
                                                            'Bus Number']!)),
                                                    DataCell(isRowEditing
                                                        ? _buildEditableField(
                                                            index,
                                                            'Address',
                                                            student['Address']!)
                                                        : GestureDetector(
                                                            onTap: () =>
                                                                _openLocation(
                                                                    student[
                                                                        'Address']!),
                                                            child: Text(
                                                              student[
                                                                  'Address']!,
                                                              style: TextStyle(
                                                                color:
                                                                    Colors.blue,
                                                                decoration:
                                                                    TextDecoration
                                                                        .underline,
                                                              ),
                                                            ),
                                                          )),
                                                    DataCell(
                                                      isRowEditing
                                                          ? DropdownButtonHideUnderline(
                                                              // Hides the default underline
                                                              child:
                                                                  DropdownButton<
                                                                      String>(
                                                                isExpanded:
                                                                    true, // Allows the dropdown to take full width of cell
                                                                value: [
                                                                  'Yes',
                                                                  'No'
                                                                ].contains(student[
                                                                        'Bus Fees Paid'])
                                                                    ? student[
                                                                        'Bus Fees Paid']
                                                                    : 'No', // Fallback to 'No' if value is unexpected
                                                                items: [
                                                                  'Yes',
                                                                  'No'
                                                                ]
                                                                    .map((fees) =>
                                                                        DropdownMenuItem(
                                                                          value:
                                                                              fees,
                                                                          child:
                                                                              Text(fees),
                                                                        ))
                                                                    .toList(),
                                                                onChanged:
                                                                    (newValue) {
                                                                  setState(() {
                                                                    student['Bus Fees Paid'] =
                                                                        newValue!;
                                                                  });
                                                                },
                                                                selectedItemBuilder:
                                                                    (BuildContext
                                                                        context) {
                                                                  return [
                                                                    'Yes',
                                                                    'No'
                                                                  ].map((String
                                                                      item) {
                                                                    return Align(
                                                                        alignment:
                                                                            Alignment
                                                                                .centerLeft,
                                                                        child: Text(
                                                                            item));
                                                                  }).toList();
                                                                },
                                                              ),
                                                            )
                                                          : Text(student[
                                                                  'Bus Fees Paid'] ??
                                                              'No'),
                                                    ),
                                                    DataCell(isRowEditing
                                                        ? _buildEditableField(
                                                            index,
                                                            'Email Address',
                                                            student[
                                                                'Email Address']!)
                                                        : Text(student[
                                                            'Email Address']!)),
                                                    DataCell(
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          // Individual row edit button (only show if not in bulk edit mode)
                                                          if (!isBulkEditing)
                                                            IconButton(
                                                              icon: Icon(
                                                                editingRows
                                                                        .contains(
                                                                            index)
                                                                    ? Icons.save
                                                                    : Icons
                                                                        .edit,
                                                                color: editingRows
                                                                        .contains(
                                                                            index)
                                                                    ? Colors
                                                                        .green
                                                                    : Colors
                                                                        .blue,
                                                              ),
                                                              onPressed: () =>
                                                                  _toggleRowEdit(
                                                                      index),
                                                              tooltip: editingRows
                                                                      .contains(
                                                                          index)
                                                                  ? 'Save Changes'
                                                                  : 'Edit Student',
                                                            ),
                                                          // Delete button (always show, but consider disabling in bulk edit if needed)
                                                          IconButton(
                                                            icon: Icon(
                                                                Icons.delete,
                                                                color:
                                                                    Colors.red),
                                                            onPressed: () =>
                                                                _deleteStudent(
                                                                    index),
                                                            tooltip:
                                                                'Delete Student',
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ]);
                                            }).toList(),
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
              // Chatbot FloatingActionButton (toggles the in-app chatbot window)
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

// NOTE: Removed standalone main() to prevent duplicate MaterialApp and routing issues.
