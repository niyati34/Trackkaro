import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:new_app/live_camera.dart';
import 'package:new_app/login_page.dart';
import 'package:new_app/manage_driver_page.dart';
import 'package:new_app/notification.dart';
import 'package:new_app/on_route_page.dart';
import 'package:new_app/out_of_service_page.dart';
import 'package:new_app/standby_page.dart';
import 'package:new_app/live_tracking_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'busdetail_page.dart';
import 'student_detail_page.dart';
import 'custom_clickable_pie_chart.dart';
import 'ui/design_system.dart';
import 'dart:convert'; // Required for JSON encoding/decoding
import 'package:http/http.dart' as http; // Required for making API calls

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Map<String, double> dataMap = {
    'On Route': 30,
    'Standby': 20,
    'Out of Service': 10,
  };

  List<Color> colorList = [
    Colors.green,
    Colors.orange,
    Colors.blue,
  ];

  // --- Chatbot related variables (copied from StudentDetailPage) ---
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
    _checkToken();
  }

  @override
  void dispose() {
    // Dispose chatbot controllers
    _chatbotInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _checkToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      // Use pushReplacement to prevent going back to login via back button
      // Use named route for consistency if you have one, or direct MaterialPageRoute
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => LoginPage()));
    }
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
          _getChatbotResponse("Hi there! How can I help you today?",
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
        'https://new-track-karo-backend.onrender.com/ai-chat-query'; // Your backend API URL

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
            if (lowerCaseBotResponse.contains("bus") ||
                lowerCaseBotResponse.contains("route")) {
              quickResponses = ["Manage Buses", "Set Route"];
            } else if (lowerCaseBotResponse.contains("student") ||
                lowerCaseBotResponse.contains("enrollment")) {
              quickResponses = ["Manage Students", "Student Details"];
            } else if (lowerCaseBotResponse.contains("driver") ||
                lowerCaseBotResponse.contains("manage")) {
              quickResponses = ["Manage Drivers", "Driver Schedule"];
            } else {
              quickResponses = [
                "Manage Buses",
                "Manage Drivers",
                "Manage Students",
                "Live Tracking"
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
            "Hello! I'm your TrackKaro AI Assistant. How can I assist you with your dashboard and overall management today?";
        quickResponses = [
          "Manage Buses",
          "Manage Drivers",
          "Manage Students",
          "Check Live Tracking"
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
                            'Chat with TrackKaro AI', // Chatbot Name
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: UserDetailsDrawer(),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "debug",
            onPressed: () => Navigator.pushNamed(context, '/debug'),
            backgroundColor: Colors.red,
            mini: true,
            child: Icon(Icons.bug_report, color: Colors.white),
            tooltip: 'Network Debug',
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "chat",
            onPressed: _toggleChatbot, // Now calls the new chatbot toggle
            backgroundColor:
                Color(0xFF03B0C1), // Changed to the consistent color
            child: Icon(
              _isChatbotOpen
                  ? Icons.close
                  : Icons.add_comment, // Change icon based on state
              color: Colors.white,
            ),
            tooltip: 'Chat with Assistant', // Tooltip for clarity
          ),
        ],
      ),
      body: Stack(
        children: [
          Row(
            children: [
              ModernSidebar(currentRoute: '/home'),
              Expanded(child: _buildMainContent(context)),
            ],
          ),
          if (_isChatbotOpen)
            _buildChatbotWindow(), // Conditionally display the new chatbot window
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFF8FAFC),
      ),
      child: Column(
        children: [
          _buildMinimalistAppBar(context),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeSection(),
                  _buildMinimalistStatsGrid(),
                  _buildQuickActionsAndFleetOverview(context),
                  SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalistAppBar(BuildContext context) {
    return Container(
      height: 80, // Slightly taller for more prominence
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06), // Deeper shadow
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Spacer(),
              // Search bar - only show on larger screens
              if (MediaQuery.of(context).size.width > 800) ...[
                Container(
                  width: 320, // Wider
                  height: 44, // Taller
                  decoration: BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12), // More rounded
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search buses, drivers, routes...',
                      hintStyle:
                          TextStyle(fontSize: 14, color: Colors.grey.shade400),
                      prefixIcon: Icon(Icons.search,
                          size: 20, color: Colors.grey.shade400),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 20),
              ],
              // Notification icon
              Stack(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.notifications,
                        size: 22, color: Colors.grey.shade600),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 12),
              // User profile
              GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 18, // Bigger avatar
                        backgroundColor: Color(0xFF03B0C1),
                        child:
                            Icon(Icons.person, color: Colors.white, size: 18),
                      ),
                      if (MediaQuery.of(context).size.width > 600) ...[
                        SizedBox(width: 8),
                        Text(
                          'John',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600, // Bolder
                            color: Colors.grey.shade800, // Darker
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down,
                            size: 18, color: Colors.grey.shade500),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return _dashboardCard(
      margin: EdgeInsets.fromLTRB(24, 24, 24, 8),
      padding: EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 760;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isNarrow) ...[
                Text(
                  'Dashboard',
                  style: GoogleFonts.dmSans(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade900,
                    height: 1.05,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Good ${_getTimeOfDay()}, John · Here is your fleet overview',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 20),
                _buildHeaderActions(isNarrow: true),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dashboard',
                            style: GoogleFonts.dmSans(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey.shade900,
                              height: 1.05,
                            ),
                          ),
                          SizedBox(height: 14),
                          Text(
                            'Good ${_getTimeOfDay()}, John · Monitor buses, routes, and performance in real time',
                            style: GoogleFonts.dmSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 32),
                    _buildHeaderActions(),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderActions({bool isNarrow = false}) {
    final buttonSpacing = SizedBox(width: 14);
    final addBusButton = ElevatedButton.icon(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF03B0C1),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      icon: Icon(Icons.add, size: 20),
      label: Text(
        'Add Bus',
        style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );

    final importButton = OutlinedButton.icon(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        foregroundColor: Color(0xFF03B0C1),
        side: BorderSide(color: Color(0xFF03B0C1).withOpacity(0.4), width: 1.2),
        padding: EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(Icons.file_upload_outlined, size: 20),
      label: Text(
        'Import Data',
        style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );

    return isNarrow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              addBusButton,
              SizedBox(height: 12),
              importButton,
            ],
          )
        : Row(
            children: [
              addBusButton,
              buttonSpacing,
              importButton,
            ],
          );
  }

  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  Widget _buildMinimalistStatsGrid() {
    return Container(
      margin: EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive columns based on screen width
          int columns = 1;
          if (constraints.maxWidth > 1200)
            columns = 4;
          else if (constraints.maxWidth > 800)
            columns = 2;
          else if (constraints.maxWidth > 600) columns = 2;

          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildMinimalistStatCard(
                title: 'Total Buses',
                value: '24',
                icon: Icons.directions_bus_outlined,
                color: Color(0xFF03B0C1),
                trend: '+12%',
                width: (constraints.maxWidth - (16 * (columns - 1))) / columns,
                isHighlighted: true,
              ),
              _buildMinimalistStatCard(
                title: 'Active Routes',
                value: '19',
                icon: Icons.route_outlined,
                color: Color(0xFF059669),
                trend: '+8%',
                width: (constraints.maxWidth - (16 * (columns - 1))) / columns,
              ),
              _buildMinimalistStatCard(
                title: 'Students',
                value: '342',
                icon: Icons.people_outline,
                color: Color(0xFF7C3AED),
                trend: '+15%',
                width: (constraints.maxWidth - (16 * (columns - 1))) / columns,
              ),
              _buildMinimalistStatCard(
                title: 'Efficiency',
                value: '95%',
                icon: Icons.speed_outlined,
                color: Color(0xFFDC2626),
                trend: '+3%',
                width: (constraints.maxWidth - (16 * (columns - 1))) / columns,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMinimalistStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String trend,
    required double width,
    bool isHighlighted = false,
  }) {
    return Container(
      width: width.clamp(220.0, double.infinity),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isHighlighted ? color : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isHighlighted
                      ? Colors.white.withOpacity(0.9)
                      : Colors.grey.shade600,
                ),
              ),
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? Colors.white.withOpacity(0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_forward,
                  color: isHighlighted ? Colors.white : Colors.grey.shade500,
                  size: 18,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: isHighlighted ? Colors.white : Color(0xFF1A1D29),
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.trending_up,
                color: isHighlighted
                    ? Colors.white.withOpacity(0.8)
                    : Colors.green.shade500,
                size: 16,
              ),
              SizedBox(width: 6),
              Text(
                '$trend from last month',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isHighlighted
                      ? Colors.white.withOpacity(0.8)
                      : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsAndFleetOverview(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Fallback to vertical stacking on narrow screens
          if (constraints.maxWidth < 980) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCompactQuickActionsGrid(constraints.maxWidth),
                SizedBox(height: 24),
                _buildCompactFleetOverviewCard(),
              ],
            );
          }

          // Side by side layout
          double totalWidth = constraints.maxWidth;
          double gap = 28;
          double leftWidth = totalWidth * 0.50; // quick actions
          if (leftWidth > totalWidth - 480)
            leftWidth = totalWidth - 480; // ensure room for chart
          const int columns = 3; // 3 columns, 2 rows (6 actions)
          const double cardSpacing = 16;
          const double horizontalPadding = 20;
          const double verticalPadding = 24; // Increased padding
          const double headerHeight = 46; // title row

          double squareSize = (leftWidth -
                  horizontalPadding * 2 -
                  cardSpacing * (columns - 1)) /
              columns;
          squareSize = squareSize.clamp(108.0, 172.0);
          double gridHeight = squareSize * 2 + cardSpacing; // 2 rows
          double containerHeight = headerHeight +
              verticalPadding * 2 +
              gridHeight +
              48; // Increased extra height for proper fitting

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick Actions Panel
              Container(
                width: leftWidth,
                height: containerHeight,
                padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding, vertical: verticalPadding),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Quick Actions',
                          style: GoogleFonts.dmSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade900,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Expanded(
                      child: GridView.count(
                        physics: NeverScrollableScrollPhysics(),
                        crossAxisCount: columns,
                        mainAxisSpacing: cardSpacing,
                        crossAxisSpacing: cardSpacing,
                        childAspectRatio: 1,
                        children: [
                          _squareActionCard(
                              'Manage Buses',
                              Icons.directions_bus,
                              Color(0xFF03B0C1),
                              () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => BusDetailPage()))),
                          _squareActionCard(
                              'Drivers',
                              Icons.person,
                              Color(0xFF059669),
                              () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => ManageDriverPage()))),
                          _squareActionCard(
                              'Students',
                              Icons.school,
                              Color(0xFF7C3AED),
                              () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => StudentDetailPage()))),
                          _squareActionCard(
                              'Live Tracking',
                              Icons.location_on,
                              Color(0xFFDC2626),
                              () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => LiveTrackingPage()))),
                          _squareActionCard(
                              'Camera',
                              Icons.videocam,
                              Color(0xFFEAB308),
                              () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => LiveCameraPage()))),
                          _squareActionCard(
                              'Notifications',
                              Icons.notifications,
                              Color(0xFF8B5CF6),
                              () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => NotificationPage()))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: gap),
              // Fleet Overview Panel
              Expanded(
                child: Container(
                  height: containerHeight,
                  padding: EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _buildFleetOverviewInner(dark: false),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _squareActionCard(
      String title, IconData icon, Color accent, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Color(0xFF03B0C1), width: 2.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Compact vertical versions for narrow screens reuse existing smaller builders
  Widget _buildCompactQuickActionsGrid(double maxWidth) {
    return _buildMinimalistQuickActions(context);
  }

  Widget _buildCompactFleetOverviewCard() {
    return _buildMinimalistAnalytics();
  }

  Widget _buildFleetOverviewInner({bool dark = false}) {
    final dataMap = <String, double>{
      'On Route': 24.0,
      'Standby': 12.0,
      'Out of Service': 5.0,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Clean, minimal header
        Row(
          children: [
            Text(
              'Fleet Overview',
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade900,
              ),
            ),
            Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Color(0xFF03B0C1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Color(0xFF03B0C1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Live',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF03B0C1),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        Expanded(
          child: Row(
            children: [
              // Legend & metrics - simplified
              Expanded(
                flex: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Clean legend items
                    Column(
                      children: dataMap.entries
                          .map((e) => Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: _legendItemClean(
                                    e.key, e.value, _colorForSegment(e.key)),
                              ))
                          .toList(),
                    ),
                    Spacer(),
                    // Total summary
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Fleet',
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '${dataMap.values.reduce((a, b) => a + b).toInt()} Vehicles',
                            style: GoogleFonts.dmSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                flex: 12,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CustomClickablePieChart(
                      dataMap: dataMap,
                      colorList: [
                        Color(0xFF03B0C1),
                        Color(0xFF059669),
                        Color(0xFFDC2626),
                      ],
                      onSegmentTap: (segment) {
                        if (segment == 'On Route') {
                          Navigator.push(context,
                              MaterialPageRoute(builder: (_) => OnRoutePage()));
                        } else if (segment == 'Standby') {
                          Navigator.push(context,
                              MaterialPageRoute(builder: (_) => StandbyPage()));
                        } else if (segment == 'Out of Service') {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => OutOfServicePage()));
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendItemClean(String label, double value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Text(
          '${value.toInt()}',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _colorForSegment(String segment) {
    switch (segment) {
      case 'On Route':
        return Color(0xFF03B0C1);
      case 'Standby':
        return Color(0xFF059669);
      case 'Out of Service':
        return Color(0xFFDC2626);
      default:
        return Colors.grey;
    }
  }

  // Missing helper methods
  Widget _dashboardCard({
    required Widget child,
    EdgeInsets margin = EdgeInsets.zero,
    EdgeInsets padding = const EdgeInsets.all(24),
    Color? borderColor,
    double radius = 16,
  }) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: child,
    );
  }

  Widget _buildMinimalistQuickActions(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              'Quick Actions',
              style: GoogleFonts.dmSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade900,
              ),
            ),
          ),
          SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              int columns = 2;
              if (constraints.maxWidth > 1000)
                columns = 3;
              else if (constraints.maxWidth > 600) columns = 2;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildMinimalistActionCard(
                    'Manage Buses',
                    Icons.directions_bus,
                    Color(0xFF03B0C1),
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => BusDetailPage())),
                    width:
                        (constraints.maxWidth - (16 * (columns - 1))) / columns,
                  ),
                  _buildMinimalistActionCard(
                    'Drivers',
                    Icons.person,
                    Color(0xFF059669),
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ManageDriverPage())),
                    width:
                        (constraints.maxWidth - (16 * (columns - 1))) / columns,
                  ),
                  _buildMinimalistActionCard(
                    'Students',
                    Icons.school,
                    Color(0xFF7C3AED),
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => StudentDetailPage())),
                    width:
                        (constraints.maxWidth - (16 * (columns - 1))) / columns,
                  ),
                  _buildMinimalistActionCard(
                    'Live Tracking',
                    Icons.location_on,
                    Color(0xFFDC2626),
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => LiveTrackingPage())),
                    width:
                        (constraints.maxWidth - (16 * (columns - 1))) / columns,
                  ),
                  _buildMinimalistActionCard(
                    'Camera',
                    Icons.videocam,
                    Color(0xFFEAB308),
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => LiveCameraPage())),
                    width:
                        (constraints.maxWidth - (16 * (columns - 1))) / columns,
                  ),
                  _buildMinimalistActionCard(
                    'Notifications',
                    Icons.notifications,
                    Color(0xFF8B5CF6),
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => NotificationPage())),
                    width:
                        (constraints.maxWidth - (16 * (columns - 1))) / columns,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalistActionCard(
      String title, IconData icon, Color color, VoidCallback onTap,
      {required double width}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width.clamp(160.0, double.infinity),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalistAnalytics() {
    return Container(
      margin: EdgeInsets.all(16),
      child: Container(
        padding: EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF03B0C1),
                        Color(0xFF0891B2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.pie_chart,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Fleet Overview',
                  style: GoogleFonts.dmSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade900,
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFF03B0C1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Color(0xFF03B0C1),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Live',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF03B0C1),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 28),
            LayoutBuilder(
              builder: (context, constraints) {
                final dataMap = <String, double>{
                  'On Route': 24.0,
                  'Standby': 12.0,
                  'Out of Service': 5.0,
                };

                return Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLegendItem('On Route', 24, Color(0xFF03B0C1)),
                          SizedBox(height: 12),
                          _buildLegendItem('Standby', 12, Color(0xFF059669)),
                          SizedBox(height: 12),
                          _buildLegendItem(
                              'Out of Service', 5, Color(0xFFDC2626)),
                          SizedBox(height: 24),
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Fleet',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '41 Buses',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.grey.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 24),
                    Expanded(
                      flex: 1,
                      child: Container(
                        height: 280,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: 260,
                              maxHeight: 260,
                            ),
                            child: CustomClickablePieChart(
                              dataMap: dataMap,
                              colorList: [
                                Color(0xFF03B0C1),
                                Color(0xFF059669),
                                Color(0xFFDC2626),
                              ],
                              onSegmentTap: (selectedSegment) {
                                if (selectedSegment == 'On Route') {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => OnRoutePage()));
                                } else if (selectedSegment == 'Standby') {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => StandbyPage()));
                                } else if (selectedSegment ==
                                    'Out of Service') {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              OutOfServicePage()));
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Text(
          '$value',
          style: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

// User details drawer with modern design
class UserDetailsDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF03B0C1),
              Color(0xFF03B0C1).withOpacity(0.8),
            ],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.transparent,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      color: Color(0xFF03B0C1),
                      size: 40,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'John Doe',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Administrator',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildDrawerTile(
                    icon: Icons.person_outline,
                    title: 'Profile',
                    subtitle: 'johndoe',
                  ),
                  _buildDrawerTile(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    subtitle: 'johndoe@example.com',
                  ),
                  _buildDrawerTile(
                    icon: Icons.phone_outlined,
                    title: 'Phone',
                    subtitle: '+1234567890',
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    SharedPreferences prefs =
                        await SharedPreferences.getInstance();
                    await prefs.remove('token');
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => LoginPage()),
                      (route) => false,
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.logout,
                          color: Colors.white,
                          size: 22,
                        ),
                        SizedBox(width: 16),
                        Text(
                          'Logout',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white70,
            size: 20,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
