import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:new_app/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_route_page.dart'; // Import the AddRoutePage
import 'ui/design_system.dart'; // Import the design system
import 'package:http/http.dart' as http;

class LiveTrackingPage extends StatefulWidget {
  @override
  _LiveTrackingPageState createState() => _LiveTrackingPageState();
}

class _LiveTrackingPageState extends State<LiveTrackingPage> {
  List<Map<String, dynamic>> routes = [];
  bool isLoading = true;
  bool isError = false;
  String? _token;

  List<Map<String, dynamic>> filteredRoutes = [];
  final TextEditingController _searchController = TextEditingController();
  bool isEditing = false; // Track edit mode
  Set<int> editingRows = {}; // Track which rows are being edited
  Map<int, Map<String, TextEditingController>> rowControllers =
      {}; // Controllers for each row

  // --- Chatbot related variables ---
  bool _isChatbotOpen = false;
  final List<Map<String, dynamic>> _messages =
      []; // Use dynamic for quick_responses
  final TextEditingController _chatbotInputController = TextEditingController();
  final ScrollController _chatScrollController =
      ScrollController(); // To auto-scroll chat
  // --- End Chatbot variables ---

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

  Future<void> _fetchRoutes() async {
    await _getOrganizationToken();
    setState(() {
      isLoading = true;
      isError = false;
    });
    try {
      final response = await http.post(
        Uri.parse('${dotenv.env['BACKEND_API']}/get-all-routes'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'organization_id': _token,
        }),
      );

      if (response.statusCode == 200) {
        final List<dynamic> routeList = json.decode(response.body);
        setState(() {
          routes = routeList.map((bus) {
            return {
              'routeNumber': bus['route_number'],
              'routeName': bus['route_name'],
              'source': bus['source'],
              'destination': bus['destination'],
              'stops': bus['stops'],
              'id': bus['id'].toString(),
            };
          }).toList();
          isLoading = false;
          filteredRoutes = List.from(routes);
        });
      } else {
        setState(() {
          isError = true;
          isLoading = false;
        });
      }
    } catch (e) {
      print("This is the error: $e");
      setState(() {
        isError = true;
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchRoutes();
  }

  @override
  void dispose() {
    rowControllers.forEach((index, controllers) {
      controllers.forEach((key, controller) => controller.dispose());
    });
    _searchController.dispose();
    _chatbotInputController.dispose();
    _chatScrollController.dispose(); // Dispose scroll controller
    super.dispose();
  }

  void _filterRoutes(String query) {
    List<Map<String, dynamic>> filtered = routes.where((route) {
      return route['routeNumber'].toLowerCase().contains(query.toLowerCase()) ||
          route['routeName'].toLowerCase().contains(query.toLowerCase()) ||
          route['source'].toLowerCase().contains(query.toLowerCase()) ||
          route['destination'].toLowerCase().contains(query.toLowerCase());
    }).toList();
    setState(() {
      filteredRoutes = filtered;
      editingRows.clear();
      rowControllers.forEach((index, controllers) {
        controllers.forEach((key, controller) => controller.dispose());
      });
      rowControllers.clear();
      isEditing = false;
    });
  }

  void _refreshRouteData() {
    _fetchRoutes();
    setState(() {
      editingRows.clear();
      rowControllers.forEach((index, controllers) {
        controllers.forEach((key, controller) => controller.dispose());
      });
      rowControllers.clear();
      isEditing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Routes data refreshed!')),
    );
  }

  void _editRow(int index) {
    setState(() {
      editingRows.add(index);
      rowControllers[index] = {
        'routeNumber':
            TextEditingController(text: filteredRoutes[index]['routeNumber']),
        'routeName':
            TextEditingController(text: filteredRoutes[index]['routeName']),
        'source': TextEditingController(text: filteredRoutes[index]['source']),
        'destination':
            TextEditingController(text: filteredRoutes[index]['destination']),
      };
    });
  }

  Future<void> _saveRow(int index) async {
    final route = filteredRoutes[index];
    final String routeId = route['id'].toString();
    final String url = '${dotenv.env['BACKEND_API']}/update-route';

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
            Text('Updating route...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "id": routeId,
          "organization_id": _token,
          "route_number": rowControllers[index]!['routeNumber']!.text,
          "route_name": rowControllers[index]!['routeName']!.text,
          "source": rowControllers[index]!['source']!.text,
          "destination": rowControllers[index]!['destination']!.text,
        }),
      );

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (response.statusCode == 200) {
        setState(() {
          filteredRoutes[index]['routeNumber'] =
              rowControllers[index]!['routeNumber']!.text;
          filteredRoutes[index]['routeName'] =
              rowControllers[index]!['routeName']!.text;
          filteredRoutes[index]['source'] =
              rowControllers[index]!['source']!.text;
          filteredRoutes[index]['destination'] =
              rowControllers[index]!['destination']!.text;

          editingRows.remove(index);
          rowControllers[index]
              ?.forEach((key, controller) => controller.dispose());
          rowControllers.remove(index);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Route updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        String errorMessage = 'Failed to update Route';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          } else if (errorData['error'] != null) {
            errorMessage = errorData['error'];
          }
        } catch (e) {
          errorMessage =
              'Failed to update Route (Status: ${response.statusCode})';
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
          content: Text('❌ Network error: Please check your connection'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _cancelEdit(int index) {
    setState(() {
      editingRows.remove(index);
      rowControllers[index]?.forEach((key, controller) => controller.dispose());
      rowControllers.remove(index);
    });
  }

  void deleteRoute(int index) async {
    final route = filteredRoutes[index];
    final String routeId = route['id'].toString();
    final String url = '${dotenv.env['BACKEND_API']}/delete-route';

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
            Text('Deleting route...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "id": routeId,
          "organization_id": _token,
        }),
      );

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (response.statusCode == 200) {
        setState(() {
          filteredRoutes.removeAt(index);
          routes.removeWhere((r) => r['id'] == routeId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Route deleted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        String errorMessage = 'Failed to delete Route';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          } else if (errorData['error'] != null) {
            errorMessage = errorData['error'];
          }
        } catch (e) {
          errorMessage =
              'Failed to delete Route (Status: ${response.statusCode})';
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
          content: Text('❌ Network error: Please check your connection'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _addRoute() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddRoutePage()),
    );
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        routes.add(result);
        filteredRoutes = List.from(routes);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Route successfully added!')),
      );
    }
  }

  void _toggleEditModeGlobal() {
    setState(() {
      isEditing = !isEditing;
      if (!isEditing) {
        editingRows.clear();
        rowControllers.forEach((index, controllers) {
          controllers.forEach((key, controller) => controller.dispose());
        });
        rowControllers.clear();
      } else {
        for (int i = 0; i < filteredRoutes.length; i++) {
          _editRow(i);
        }
      }
    });
  }

  void _saveAllChanges() async {
    int successCount = 0;
    int totalUpdates = editingRows.length;

    if (totalUpdates == 0) {
      setState(() {
        isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No changes to save.')),
      );
      return;
    }

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
            Text('Saving all changes...'),
          ],
        ),
        duration: Duration(minutes: 2),
      ),
    );

    List<Future<void>> updateFutures = [];
    for (int index in editingRows.toList()) {
      updateFutures.add(() async {
        final route = filteredRoutes[index];
        final String routeId = route['id'].toString();
        final String url = '${dotenv.env['BACKEND_API']}/update-route';

        try {
          final response = await http.put(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "id": routeId,
              "organization_id": _token,
              "route_number": rowControllers[index]!['routeNumber']!.text,
              "route_name": rowControllers[index]!['routeName']!.text,
              "source": rowControllers[index]!['source']!.text,
              "destination": rowControllers[index]!['destination']!.text,
            }),
          );

          if (response.statusCode == 200) {
            setState(() {
              filteredRoutes[index]['routeNumber'] =
                  rowControllers[index]!['routeNumber']!.text;
              filteredRoutes[index]['routeName'] =
                  rowControllers[index]!['routeName']!.text;
              filteredRoutes[index]['source'] =
                  rowControllers[index]!['source']!.text;
              filteredRoutes[index]['destination'] =
                  rowControllers[index]!['destination']!.text;

              final mainIndex = routes.indexWhere((r) => r['id'] == routeId);
              if (mainIndex != -1) {
                routes[mainIndex] = Map.from(filteredRoutes[index]);
              }
            });
            successCount++;
          } else {
            print('Failed to update route $routeId: ${response.body}');
          }
        } catch (e) {
          print('Error updating route $routeId: $e');
        } finally {
          rowControllers[index]
              ?.forEach((key, controller) => controller.dispose());
          rowControllers.remove(index);
        }
      }());
    }

    await Future.wait(updateFutures);

    setState(() {
      isEditing = false;
      editingRows.clear();
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '✅ $successCount of $totalUpdates routes updated successfully!'),
        backgroundColor:
            successCount == totalUpdates ? Colors.green : Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // --- Chatbot Functionality ---
  void _toggleChatbot() {
    setState(() {
      _isChatbotOpen = !_isChatbotOpen;
      if (!_isChatbotOpen) {
        _messages.clear(); // Clear messages when closing
        _chatbotInputController.clear();
      } else {
        // Optional: Add an initial welcome message from the bot
        if (_messages.isEmpty) {
          _getChatbotResponse("Hi there! How can I help you with routes?",
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
        'https://new-track-karo-backend.onrender.com/ai-chat-query';

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

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = json.decode(response.body);
          if (responseData.containsKey('message')) {
            botResponse = responseData['message'];
            // You can add logic here to parse the botResponse and
            // generate relevant quick responses based on its content.
            // For now, let's keep some general ones or add logic for specific keywords.
            String lowerCaseBotResponse = botResponse.toLowerCase();
            if (lowerCaseBotResponse
                    .contains("Which buses run on route 105?") &&
                lowerCaseBotResponse
                    .contains("Show me all buses for route 103")) {
              quickResponses = [
                "Bus numbers on route 101?",
                "Show me all buses for route 103"
              ];
            } else if (lowerCaseBotResponse.contains("bus") &&
                lowerCaseBotResponse.contains("route")) {
              quickResponses = [
                "Which buses run on route 105?",
                "How many buses are assigned to route 102"
              ];
            } else {
              quickResponses = [
                "How many buses are assigned to route 102?",
                "Show me all buses for route 103"
              ];
            }
          } else {
            botResponse =
                "I received an unexpected response from the AI assistant.";
            print("Error: AI response missing 'message' key: ${response.body}");
            quickResponses = ["What can you do?", "Tell me about routes."];
          }
        } else {
          // Handle non-200 status codes (e.g., 429 for rate limit, 500 for server error)
          final Map<String, dynamic> errorData = json.decode(response.body);
          String errorMessage = errorData['error'] ?? 'Unknown error';
          botResponse = "Error from AI assistant: $errorMessage";
          print(
              "Error: AI API returned status ${response.statusCode}: $errorMessage");
          quickResponses = [
            "What can you do?",
            "Is the server down?"
          ]; // Offer helpful quick responses on error
        }
      } else {
        botResponse =
            "Hello! I'm your Route Management Assistant. Ask me anything about routes, drivers, or schedules!";
        quickResponses = [
          "Show me all buses for route 103",
          "How many buses are assigned to route 102?"
        ];
      }
    } catch (e) {
      // Handle network errors (e.g., no internet connection)
      botResponse =
          "It seems I'm having trouble connecting to the AI assistant. Please check your internet connection.";
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
              // Chatbot Header (Jessica Cowles)
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
                            'Chat with Trackkaro AI', // Chatbot/company name
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF03B0C1),
        elevation: 0,
        title: Text('Trackkaro'),
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
            children: [
              Row(
                children: [
                  ModernSidebar(currentRoute: '/tracking'),
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
                                            'Failed to fetch Route details. Please try again.'),
                                        SizedBox(height: 10),
                                        ElevatedButton(
                                          onPressed: _fetchRoutes,
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
                                              Icon(Icons.location_on, size: 24),
                                              SizedBox(width: 10),
                                              Text(
                                                'Live Tracking',
                                                style: TextStyle(
                                                  fontSize: 20.0,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Wrap(
                                            spacing: 10,
                                            runSpacing: 10,
                                            children: [
                                              ElevatedButton.icon(
                                                onPressed: _refreshRouteData,
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
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 15),
                                                ),
                                              ),
                                              ElevatedButton.icon(
                                                onPressed: _addRoute,
                                                icon: Icon(Icons.add,
                                                    color: Colors.white),
                                                label: Text('Add Route',
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
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 15),
                                                ),
                                              ),
                                              ElevatedButton.icon(
                                                onPressed: isEditing
                                                    ? _saveAllChanges
                                                    : _toggleEditModeGlobal,
                                                icon: Icon(
                                                  isEditing
                                                      ? Icons.save
                                                      : Icons.edit,
                                                  color: Colors.white,
                                                ),
                                                label: Text(
                                                  isEditing
                                                      ? 'Save All'
                                                      : 'Bulk Edit',
                                                  style: TextStyle(
                                                      color: Colors.white),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: isEditing
                                                      ? Colors.green
                                                      : Color(0xFF03B0C1),
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                  ),
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 15),
                                                ),
                                              ),
                                              if (isEditing)
                                                ElevatedButton.icon(
                                                  onPressed: () {
                                                    setState(() {
                                                      isEditing = false;
                                                      editingRows.clear();
                                                      rowControllers.forEach(
                                                          (index, controllers) {
                                                        controllers.forEach(
                                                            (key, controller) =>
                                                                controller
                                                                    .dispose());
                                                      });
                                                      rowControllers.clear();
                                                      _fetchRoutes();
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
                                                    foregroundColor:
                                                        Colors.white,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                    ),
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
                                        onChanged: _filterRoutes,
                                      ),
                                      SizedBox(height: 10),
                                      if (isEditing)
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
                                                child: Text(
                                                  'Bulk Edit Mode: All fields are editable. Click "Save All" to update, or "Cancel" to revert.',
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
                                                  label: Text('Route Number',
                                                      style: TextStyle(
                                                          fontWeight: FontWeight
                                                              .bold))),
                                              DataColumn(
                                                  label: Text('Route Name',
                                                      style: TextStyle(
                                                          fontWeight: FontWeight
                                                              .bold))),
                                              DataColumn(
                                                  label: Text('Source',
                                                      style: TextStyle(
                                                          fontWeight: FontWeight
                                                              .bold))),
                                              DataColumn(
                                                  label: Text('Destination',
                                                      style: TextStyle(
                                                          fontWeight: FontWeight
                                                              .bold))),
                                              DataColumn(
                                                  label: Text('Action',
                                                      style: TextStyle(
                                                          fontWeight: FontWeight
                                                              .bold))),
                                            ],
                                            rows: filteredRoutes.map((route) {
                                              int index =
                                                  filteredRoutes.indexOf(route);
                                              bool isRowEditing =
                                                  editingRows.contains(index);

                                              return DataRow(
                                                color: MaterialStateProperty
                                                    .resolveWith<Color?>(
                                                  (Set<MaterialState> states) {
                                                    if (isRowEditing) {
                                                      return Colors
                                                          .yellow.shade50;
                                                    }
                                                    return null;
                                                  },
                                                ),
                                                cells: [
                                                  DataCell(
                                                    isRowEditing
                                                        ? TextFormField(
                                                            controller:
                                                                rowControllers[
                                                                        index]![
                                                                    'routeNumber'],
                                                            decoration:
                                                                InputDecoration(
                                                              border:
                                                                  OutlineInputBorder(),
                                                              isDense: true,
                                                              contentPadding:
                                                                  EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          10,
                                                                      vertical:
                                                                          8),
                                                            ),
                                                            style: TextStyle(
                                                                fontSize: 14),
                                                          )
                                                        : Text(route[
                                                                'routeNumber'] ??
                                                            'N/A'),
                                                  ),
                                                  DataCell(
                                                    isRowEditing
                                                        ? TextFormField(
                                                            controller:
                                                                rowControllers[
                                                                        index]![
                                                                    'routeName'],
                                                            decoration:
                                                                InputDecoration(
                                                              border:
                                                                  OutlineInputBorder(),
                                                              isDense: true,
                                                              contentPadding:
                                                                  EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          10,
                                                                      vertical:
                                                                          8),
                                                            ),
                                                            style: TextStyle(
                                                                fontSize: 14),
                                                          )
                                                        : Text(route[
                                                                'routeName'] ??
                                                            'N/A'),
                                                  ),
                                                  DataCell(
                                                    isRowEditing
                                                        ? TextFormField(
                                                            controller:
                                                                rowControllers[
                                                                        index]![
                                                                    'source'],
                                                            decoration:
                                                                InputDecoration(
                                                              border:
                                                                  OutlineInputBorder(),
                                                              isDense: true,
                                                              contentPadding:
                                                                  EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          10,
                                                                      vertical:
                                                                          8),
                                                            ),
                                                            style: TextStyle(
                                                                fontSize: 14),
                                                          )
                                                        : Text(
                                                            route['source'] ??
                                                                'N/A'),
                                                  ),
                                                  DataCell(
                                                    isRowEditing
                                                        ? TextFormField(
                                                            controller:
                                                                rowControllers[
                                                                        index]![
                                                                    'destination'],
                                                            decoration:
                                                                InputDecoration(
                                                              border:
                                                                  OutlineInputBorder(),
                                                              isDense: true,
                                                              contentPadding:
                                                                  EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          10,
                                                                      vertical:
                                                                          8),
                                                            ),
                                                            style: TextStyle(
                                                                fontSize: 14),
                                                          )
                                                        : Text(route[
                                                                'destination'] ??
                                                            'N/A'),
                                                  ),
                                                  DataCell(
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        if (isRowEditing) ...[
                                                          IconButton(
                                                            onPressed: () =>
                                                                _saveRow(index),
                                                            icon: Icon(
                                                                Icons.check,
                                                                color: Colors
                                                                    .green),
                                                            tooltip:
                                                                'Save This Row',
                                                          ),
                                                          IconButton(
                                                            onPressed: () =>
                                                                _cancelEdit(
                                                                    index),
                                                            icon: Icon(
                                                                Icons.close,
                                                                color:
                                                                    Colors.red),
                                                            tooltip:
                                                                'Cancel This Row',
                                                          ),
                                                        ] else ...[
                                                          IconButton(
                                                            onPressed: () =>
                                                                _editRow(index),
                                                            icon: Icon(
                                                                Icons.edit,
                                                                color: Colors
                                                                    .blue),
                                                            tooltip:
                                                                'Edit This Row',
                                                          ),
                                                          IconButton(
                                                            onPressed: () =>
                                                                deleteRoute(
                                                                    index),
                                                            icon: Icon(
                                                                Icons.delete,
                                                                color:
                                                                    Colors.red),
                                                            tooltip: 'Delete',
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              );
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
              if (_isChatbotOpen) _buildChatbotWindow(),
            ],
          );
        },
      ),
    );
  }
}
