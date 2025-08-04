import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../../services/message_service.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> participant;
  final String currentUserRole;

  const ChatScreen({
    super.key,
    required this.participant,
    required this.currentUserRole,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final MessageService _messageService = MessageService();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _currentUserId;
  StreamSubscription<List<Map<String, dynamic>>>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    // Try Firebase Auth first, then fall back to secure storage
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
      print('ChatScreen: Using Firebase Auth user ID: $_currentUserId');
    } else {
      _currentUserId = await _secureStorage.read(key: 'userUid');
      print('ChatScreen: Using secure storage user ID: $_currentUserId');
    }

    if (_currentUserId != null) {
      _setupMessageStream();
    } else {
      print('ChatScreen: No user ID found!');
    }
  }

  void _setupMessageStream() {
    if (_currentUserId == null) return;

    final participantId =
        widget.participant['id'] ?? widget.participant['uid'] ?? '';
    print(
      'Setting up message stream between $_currentUserId and $participantId',
    );

    setState(() => _isLoading = true);

    _messageSubscription?.cancel();
    _messageSubscription = _messageService
        .getMessagesStream(_currentUserId!, participantId)
        .listen(
          (messages) {
            print('Received ${messages.length} messages in chat stream');
            setState(() {
              _messages = messages;
              _isLoading = false;
            });
            _scrollToBottom();
          },
          onError: (error) {
            print('Error in message stream: $error');
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to load messages: $error'),
                backgroundColor: Colors.red,
              ),
            );
          },
        );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    setState(() => _isSending = true);

    try {
      final message = await _messageService.sendMessage(
        senderId: _currentUserId ?? '',
        receiverId: widget.participant['id'] ?? widget.participant['uid'] ?? '',
        message: messageText,
        senderRole: widget.currentUserRole,
      );

      print('Message sent successfully: ${message['id']}');

      _scrollToBottom();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check, color: Colors.white),
              SizedBox(width: 8),
              Text('Message sent'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isSending = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade100, width: 1),
            ),
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            FontAwesomeIcons.arrowLeft,
            color: Colors.redAccent,
            size: 18,
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                widget.participant['role'] == 'medical'
                    ? FontAwesomeIcons.userDoctor
                    : FontAwesomeIcons.user,
                color: Colors.redAccent,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.participant['name'] ?? 'Unknown User',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    widget.participant['role'] == 'medical'
                        ? 'Healthcare Provider'
                        : 'Patient',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: Icon(FontAwesomeIcons.phone, size: 16),
              color: Colors.grey.shade600,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Voice call feature coming soon'),
                    backgroundColor: Colors.grey.shade600,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
          Container(
            margin: EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: Icon(FontAwesomeIcons.video, size: 16),
              color: Colors.grey.shade600,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Video call feature coming soon'),
                    backgroundColor: Colors.grey.shade600,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.redAccent,
                            strokeWidth: 2.5,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading messages...',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Icon(
                            FontAwesomeIcons.comments,
                            size: 32,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 48),
                          child: Text(
                            'Start a conversation with ${widget.participant['name']}',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 16,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isCurrentUser =
                          message['senderId'] == _currentUserId;
                      final showAvatar =
                          index == _messages.length - 1 ||
                          _messages[index + 1]['senderId'] !=
                              message['senderId'];

                      return _buildMessageBubble(
                        message,
                        isCurrentUser,
                        showAvatar,
                      );
                    },
                  ),
          ),

          // Message Input
          SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade100, width: 1),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _sendMessage(),
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color:
                            _messageController.text.trim().isNotEmpty ||
                                _isSending
                            ? Colors.redAccent
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: IconButton(
                        onPressed: _isSending ? null : _sendMessage,
                        icon: _isSending
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                FontAwesomeIcons.paperPlane,
                                color: Colors.white,
                                size: 16,
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
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> message,
    bool isCurrentUser,
    bool showAvatar,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: showAvatar ? 16 : 4),
      child: Row(
        mainAxisAlignment: isCurrentUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) ...[
            showAvatar
                ? Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      FontAwesomeIcons.user,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                  )
                : SizedBox(width: 32),
            SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isCurrentUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isCurrentUser ? Colors.redAccent : Colors.white,
                    borderRadius: BorderRadius.circular(20).copyWith(
                      bottomLeft: isCurrentUser
                          ? Radius.circular(20)
                          : Radius.circular(4),
                      bottomRight: isCurrentUser
                          ? Radius.circular(4)
                          : Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    message['message'] ?? '',
                    style: TextStyle(
                      color: isCurrentUser
                          ? Colors.white
                          : Colors.grey.shade800,
                      fontSize: 16,
                      height: 1.3,
                    ),
                  ),
                ),
                if (showAvatar) ...[
                  SizedBox(height: 4),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      _formatMessageTime(message['timestamp']),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isCurrentUser) ...[
            SizedBox(width: 8),
            showAvatar
                ? Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      FontAwesomeIcons.user,
                      size: 16,
                      color: Colors.redAccent,
                    ),
                  )
                : SizedBox(width: 32),
          ],
        ],
      ),
    );
  }

  String _formatMessageTime(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime time;
    if (timestamp is DateTime) {
      time = timestamp;
    } else if (timestamp is String) {
      time = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else {
      return '';
    }

    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

// TODO: Add a delete functionality to remove messages
