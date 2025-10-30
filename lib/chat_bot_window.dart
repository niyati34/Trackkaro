import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatMessage {
  final String message;
  final bool isUser;
  final DateTime timestamp;
  final List<String> quickResponses; // Added for quick response buttons
  final bool isTyping; // Added for typing indicator

  ChatMessage({
    required this.message,
    required this.isUser,
    required this.timestamp,
    this.quickResponses = const [],
    this.isTyping = false,
  });
}

class ChatBotWidget extends StatefulWidget {
  final bool isChatbotOpen;
  final VoidCallback toggleChatbot;
  final String chatBotName;
  final String backendApiUrl; // API URL to send queries

  const ChatBotWidget({
    Key? key,
    required this.isChatbotOpen,
    required this.toggleChatbot,
    required this.chatBotName,
    required this.backendApiUrl,
  }) : super(key: key);

  @override
  _ChatBotWidgetState createState() => _ChatBotWidgetState();
}

class _ChatBotWidgetState extends State<ChatBotWidget> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _chatbotInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.isChatbotOpen && _messages.isEmpty) {
      _getChatbotResponse("Hi there! How can I help you?", isInitialGreeting: true);
    }
  }

  @override
  void didUpdateWidget(covariant ChatBotWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isChatbotOpen && !oldWidget.isChatbotOpen) {
      // Chatbot just opened, add initial greeting if no messages exist
      if (_messages.isEmpty) {
        _getChatbotResponse("Hi there! How can I help you?", isInitialGreeting: true);
      }
    } else if (!widget.isChatbotOpen && oldWidget.isChatbotOpen) {
      // Chatbot just closed, clear messages
      _messages.clear();
      _chatbotInputController.clear();
    }
  }

  @override
  void dispose() {
    _chatbotInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _sendMessageToChatbot(String message, {bool isQuickResponse = false}) {
    if (message.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        message: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
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

  Future<void> _getChatbotResponse(String userMessage, {bool isInitialGreeting = false}) async {
    String botResponse = "I'm sorry, I couldn't get a response from the AI assistant at this moment. Please try again later.";
    List<String> quickResponses = [];

    // Add a "bot typing" message while waiting for API response
    setState(() {
      _messages.add(ChatMessage(
        message: 'Thinking...',
        isUser: false,
        timestamp: DateTime.now(),
        isTyping: true,
      ));
    });
    _scrollToBottom();

    try {
      if (!isInitialGreeting) {
        final response = await http.post(
          Uri.parse(widget.backendApiUrl),
          headers: {
            'Content-Type': 'application/json',
          },
          body: json.encode({'query': userMessage}),
        );

        // Remove the "bot typing" message
        setState(() {
          _messages.removeWhere((msg) => msg.isTyping == true);
        });

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = json.decode(response.body);
          botResponse = responseData['message'] ?? 'Sorry, I could not process that request.';
          quickResponses = (responseData['quick_responses'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
              [];

          // Fallback/refine quick responses if backend doesn't provide or provides generic ones
          if (quickResponses.isEmpty) {
            String lowerCaseBotResponse = botResponse.toLowerCase();
            if (lowerCaseBotResponse.contains("bus number") || lowerCaseBotResponse.contains("route")) {
              quickResponses = ["How to add a bus?", "How to edit a bus route?", "How to delete a bus?"];
            } else if (lowerCaseBotResponse.contains("shift") || lowerCaseBotResponse.contains("time")) {
              quickResponses = ["What shifts are available?", "How to change bus time?"];
            } else {
              quickResponses = ["Add a bus", "Edit a bus", "Delete a bus", "Search for a bus"];
            }
          }

        } else {
          String errorMessage = 'Error from AI assistant: Server status ${response.statusCode}.';
          try {
            final errorData = json.decode(response.body);
            errorMessage = errorData['error'] ?? errorData['message'] ?? errorMessage;
          } catch (e) {
            errorMessage = 'Server returned unexpected response (Status: ${response.statusCode}). Raw: ${response.body.substring(0, response.body.length.clamp(0, 100))}...';
          }
          botResponse = "❌ $errorMessage";
          quickResponses = ["What can you do?", "Is the server down?"];
        }
      } else {
        botResponse = "Hello! I'm your ${widget.chatBotName} Assistant. Ask me anything about bus management!";
        quickResponses = ["How to add a bus?", "How to edit bus details?", "What are shifts?"];
        // Remove typing indicator if it was added for initial greeting
        setState(() {
          _messages.removeWhere((msg) => msg.isTyping == true);
        });
      }
    } catch (e) {
      // Remove typing indicator on error
      setState(() {
        _messages.removeWhere((msg) => msg.isTyping == true);
      });
      botResponse = "❌ Network error: Could not connect to the AI assistant. Please check your internet connection.";
      quickResponses = ["Check internet connection", "Try again"];
    }

    setState(() {
      _messages.add(ChatMessage(
        message: botResponse,
        isUser: false,
        timestamp: DateTime.now(),
        quickResponses: quickResponses,
      ));
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isChatbotOpen) {
      return SizedBox.shrink(); // Don't build if not open
    }

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
                      backgroundImage: AssetImage('assets/chatbot_avatar.png'), // Ensure this asset exists
                      backgroundColor: Colors.white,
                      child: Icon(Icons.smart_toy, color: Color(0xFF03B0C1), size: 20), // Fallback
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chat with ${widget.chatBotName} AI',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'We typically reply in a few minutes.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: widget.toggleChatbot,
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
                    final isUser = message.isUser;

                    if (message.isTyping) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: 5),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[700]),
                          ),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: EdgeInsets.symmetric(vertical: 5),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          constraints: BoxConstraints(maxWidth: 250),
                          decoration: BoxDecoration(
                            color: isUser ? Color(0xFFE3F2FD) : Color(0xFFF1F1F1),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                              bottomLeft: isUser ? Radius.circular(16) : Radius.circular(4),
                              bottomRight: isUser ? Radius.circular(4) : Radius.circular(16),
                            ),
                          ),
                          child: Text(
                            message.message,
                            style: TextStyle(color: isUser ? Colors.blue.shade900 : Colors.black87),
                          ),
                        ),
                        if (!isUser && message.quickResponses.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                            child: Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children: message.quickResponses.map((response) =>
                                  ElevatedButton(
                                    onPressed: () => _sendMessageToChatbot(response, isQuickResponse: true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade200,
                                      foregroundColor: Colors.blue.shade700,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        side: BorderSide(color: Colors.blue.shade200),
                                      ),
                                      elevation: 0,
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    child: Text(response, style: TextStyle(fontSize: 13)),
                                  ),
                              ).toList(),
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
                              contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
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
                        'POWERED BY TRACKKARO AI',
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
}