import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'ui/design_system.dart'; // ✅ Add your sidebar import here

class NotificationPage extends StatefulWidget {
  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final TextEditingController _messageController = TextEditingController();
  bool isSending = false;

  // --- Chatbot related variables ---
  bool _isChatbotOpen = false;
  final List<Map<String, dynamic>> _messages =
      []; // Use dynamic for quick_responses
  final TextEditingController _chatbotInputController = TextEditingController();
  final ScrollController _chatScrollController =
      ScrollController(); // To auto-scroll chat
  // --- End Chatbot variables ---

  @override
  void dispose() {
    _messageController.dispose();
    // Dispose chatbot controllers
    _chatbotInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> sendNotification() async {
    final String message = _messageController.text.trim();

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❗ Message cannot be empty.")),
      );
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${dotenv.env['BACKEND_API']}/send-notification-to-students'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "message": message,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Notification sent to all students.")),
        );
        _messageController.clear();
      } else {
        String errorMessage = 'Failed to send notification.';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage =
              errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (e) {
          // If response body is not JSON, just use the status code
          errorMessage =
              'Failed to send notification (Status: ${response.statusCode})';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ $errorMessage")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error occurred: $e")),
      );
    } finally {
      setState(() {
        isSending = false;
      });
    }
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
          _getChatbotResponse(
              "Hi there! How can I help you with notifications?",
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

    final String apiUrl =
        'https://new-track-karo-backend.onrender.com/ai-chat-query'; // Your backend AI API URL

    setState(() {
      _messages
          .add({'sender': 'bot', 'message': 'Thinking...', 'isTyping': true});
    });
    _scrollToBottom();

    try {
      if (!isInitialGreeting) {
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
          },
          body: json.encode({'query': userMessage}),
        );

        setState(() {
          _messages.removeWhere((msg) => msg['isTyping'] == true);
        });

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = json.decode(response.body);
          botResponse = responseData['message'] ??
              'Sorry, I could not process that request.';
          quickResponses = (responseData['quick_responses'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];

          if (quickResponses.isEmpty) {
            String lowerCaseBotResponse = botResponse.toLowerCase();
            if (lowerCaseBotResponse.contains("notification") ||
                lowerCaseBotResponse.contains("send message")) {
              quickResponses = [
                "How to send a notification?",
                "What kind of notifications can I send?"
              ];
            } else if (lowerCaseBotResponse.contains("student")) {
              quickResponses = [
                "Notify all students",
                "Notify specific students"
              ];
            } else {
              quickResponses = [
                "Send a general announcement",
                "How do I use this page?",
                "What is TrackKaro?"
              ];
            }
          }
        } else {
          String errorMessage =
              'Error from AI assistant: Server status ${response.statusCode}.';
          try {
            final errorData = json.decode(response.body);
            errorMessage =
                errorData['error'] ?? errorData['message'] ?? errorMessage;
          } catch (e) {
            errorMessage =
                'Server returned unexpected response (Status: ${response.statusCode}). Raw: ${response.body.substring(0, response.body.length.clamp(0, 100))}...';
          }
          botResponse = "❌ $errorMessage";
          print(
              "Error: AI API returned status ${response.statusCode}: $errorMessage");
          quickResponses = ["What can you do?", "Is the server down?"];
        }
      } else {
        botResponse =
            "Hello! I'm your Notification Assistant. I can help you understand how to send messages to students.";
        quickResponses = [
          "How to send a notification?",
          "Can I send emergency alerts?",
          "What happens after I send a message?"
        ];

        setState(() {
          _messages.removeWhere((msg) => msg['isTyping'] == true);
        });
      }
    } catch (e) {
      setState(() {
        _messages.removeWhere((msg) => msg['isTyping'] == true);
      });
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
          width: 350,
          height: 500,
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
              // Chatbot Header
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
                      backgroundImage: AssetImage(
                          'assets/chatbot_avatar.png'), // Ensure this asset exists
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person,
                          color: Color(0xFF03B0C1), size: 20), // Fallback
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chat with TrackKaro AI',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                          Text(
                            'We typically reply in a few minutes.',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon:
                          Icon(Icons.keyboard_arrow_down, color: Colors.white),
                      onPressed: () {},
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
                            'Typing...',
                            style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[700]),
                          ),
                        ),
                      );
                    }
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
                          constraints: BoxConstraints(maxWidth: 250),
                          decoration: BoxDecoration(
                            color:
                                isUser ? Color(0xFFE3F2FD) : Color(0xFFF1F1F1),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                              bottomLeft: isUser
                                  ? Radius.circular(16)
                                  : Radius.circular(4),
                              bottomRight: isUser
                                  ? Radius.circular(4)
                                  : Radius.circular(16),
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
                        if (!isUser && index == _messages.length - 1)
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
                        if (!isUser && quickResponses.isNotEmpty)
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
                          icon: Icon(Icons.smart_toy_outlined,
                              color: Colors.grey),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content:
                                    Text('Simulating "Trigger other bots"')));
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.attach_file, color: Colors.grey),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Simulating "Attachments"')));
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.sentiment_satisfied_alt,
                              color: Colors.grey),
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
                                borderSide: BorderSide.none,
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
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                      child: Text(
                        'POWERED BY TIDIO',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ),
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text('Trackkaro'),
        backgroundColor: Color(0xFF03B0C1),
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
      body: Stack(
        // Use Stack to overlay the chatbot
        children: [
          Row(
            children: [
              if (MediaQuery.of(context).size.width > 600)
                ModernSidebar(currentRoute: '/notifications'),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 5,
                          blurRadius: 7,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          " Enter a message to send to all students:",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 20),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            maxLines: null,
                            expands: true,
                            keyboardType: TextInputType.multiline,
                            decoration: InputDecoration(
                              hintText: "Type your message here...",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: isSending ? null : sendNotification,
                          icon: Icon(Icons.send),
                          label: Text(isSending
                              ? 'Sending...'
                              : 'Send to All Students'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF03B0C1),
                            foregroundColor: Colors.white,
                            minimumSize: Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        )
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
