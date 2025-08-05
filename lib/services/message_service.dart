import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore.dart';

class MessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  // Send a message between healthcare provider and patient
  Future<Map<String, dynamic>> sendMessage({
    required String senderId,
    required String receiverId,
    required String message,
    required String senderRole,
  }) async {
    try {
      print('Sending message from $senderId to $receiverId: $message');

      final messageData = {
        'senderId': senderId,
        'receiverId': receiverId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'senderRole': senderRole,
        'isRead': false,
        'messageType': 'text',
      };

      // Add message to Firestore
      final docRef = await _firestore.collection('messages').add(messageData);
      print('Message added with ID: ${docRef.id}');

      // Create conversation document if it doesn't exist
      final conversationId = _getConversationId(senderId, receiverId);
      print('Updating conversation: $conversationId');

      await _firestore.collection('conversations').doc(conversationId).set({
        'participants': [senderId, receiverId],
        'lastMessage': message,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSender': senderId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('Conversation updated successfully');

      // Send notification to the receiver
      try {
        // Get sender's display name
        final senderDoc = await _firestore
            .collection('users')
            .doc(senderId)
            .get();
        final senderData = senderDoc.data();
        final senderName =
            senderData?['displayName'] ?? senderData?['name'] ?? 'Someone';

        await _firestoreService.createNotificationWithData(
          uid: receiverId,
          text: 'You have a new message from $senderName',
          type: 'message',
          data: {
            'senderId': senderId,
            'senderName': senderName,
            'conversationId': _getConversationId(senderId, receiverId),
          },
        );
      } catch (notificationError) {
        print('Error sending notification: $notificationError');
        // Don't throw here as the message was sent successfully
      }

      // Return the message data with the generated ID
      return {
        'id': docRef.id,
        'senderId': senderId,
        'receiverId': receiverId,
        'message': message,
        'timestamp': DateTime.now(),
        'senderRole': senderRole,
        'isRead': false,
        'messageType': 'text',
      };
    } catch (e) {
      print('Error sending message: $e');
      throw Exception('Failed to send message: $e');
    }
  }

  // Get messages between two users
  Future<List<Map<String, dynamic>>> getMessages(
    String userId1,
    String userId2,
  ) async {
    try {
      // Since Firestore doesn't support multiple whereIn queries,
      // we need to make two separate queries and combine the results
      final query1 = await _firestore
          .collection('messages')
          .where('senderId', isEqualTo: userId1)
          .where('receiverId', isEqualTo: userId2)
          .get();

      final query2 = await _firestore
          .collection('messages')
          .where('senderId', isEqualTo: userId2)
          .where('receiverId', isEqualTo: userId1)
          .get();

      List<Map<String, dynamic>> messages = [];

      // Add messages from first query
      for (var doc in query1.docs) {
        final data = doc.data();
        messages.add({
          'id': doc.id,
          ...data,
          'timestamp':
              (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        });
      }

      // Add messages from second query
      for (var doc in query2.docs) {
        final data = doc.data();
        messages.add({
          'id': doc.id,
          ...data,
          'timestamp':
              (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        });
      }

      // Sort messages by timestamp
      messages.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));

      return messages;
    } catch (e) {
      print('Error loading messages: $e');
      // Return sample data if Firestore fails (for development)
      return _getSampleMessages(userId1, userId2);
    }
  }

  // Get conversations as a stream for real-time updates
  Stream<List<Map<String, dynamic>>> getConversationsStream(String userId) {
    print('Starting conversation stream for user: $userId');

    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          print(
            'Conversation stream update: ${snapshot.docs.length} conversations',
          );

          List<Map<String, dynamic>> conversations = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();
            print('Processing conversation ${doc.id}: $data');

            final participants = List<String>.from(data['participants'] ?? []);
            final otherUserId = participants.firstWhere(
              (id) => id != userId,
              orElse: () => '',
            );

            if (otherUserId.isNotEmpty) {
              // Get other user's information
              final otherUserData = await _getUserData(otherUserId);
              print('Other user data: $otherUserData');

              conversations.add({
                'id': doc.id,
                'otherUser': otherUserData,
                'lastMessage': data['lastMessage'] ?? '',
                'lastMessageTimestamp':
                    (data['lastMessageTimestamp'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
                'lastMessageSender': data['lastMessageSender'] ?? '',
                'isLastMessageRead':
                    data['lastMessageSender'] ==
                    userId, // If current user sent last message, mark as read
              });
            }
          }

          print('Returning ${conversations.length} conversations from stream');
          return conversations;
        });
  }

  // Get all conversations for a user (keeping for backward compatibility)
  Future<List<Map<String, dynamic>>> getConversations(String userId) async {
    try {
      print('Getting conversations for user: $userId');

      final query = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: userId)
          .orderBy('updatedAt', descending: true)
          .get();

      print('Found ${query.docs.length} conversations');

      List<Map<String, dynamic>> conversations = [];

      for (var doc in query.docs) {
        final data = doc.data();
        print('Processing conversation ${doc.id}: $data');

        final participants = List<String>.from(data['participants'] ?? []);
        final otherUserId = participants.firstWhere(
          (id) => id != userId,
          orElse: () => '',
        );

        if (otherUserId.isNotEmpty) {
          // Get other user's information
          final otherUserData = await _getUserData(otherUserId);
          print('Other user data: $otherUserData');

          conversations.add({
            'id': doc.id,
            'otherUser': otherUserData,
            'lastMessage': data['lastMessage'] ?? '',
            'lastMessageTimestamp':
                (data['lastMessageTimestamp'] as Timestamp?)?.toDate() ??
                DateTime.now(),
            'lastMessageSender': data['lastMessageSender'] ?? '',
            'isLastMessageRead':
                data['lastMessageSender'] ==
                userId, // If current user sent last message, mark as read
          });
        }
      }

      print('Returning ${conversations.length} conversations');
      return conversations;
    } catch (e) {
      print('Error loading conversations: $e');
      // Return sample conversations if Firestore fails
      return _getSampleConversations(userId);
    }
  } // Get user data by ID

  Future<Map<String, dynamic>> _getUserData(String userId) async {
    try {
      print('Getting user data for: $userId');
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final userData = {'id': userId, 'uid': userId, ...doc.data()!};
        print('Found user data: $userData');
        return userData;
      } else {
        print('User document not found for: $userId');
      }
    } catch (e) {
      print('Error getting user data: $e');
    }

    // Return default user data if not found
    final defaultData = {
      'id': userId,
      'uid': userId,
      'name': 'Unknown User',
      'role': 'patient',
      'email': '',
    };
    print('Returning default user data: $defaultData');
    return defaultData;
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(
    String currentUserId,
    String otherUserId,
  ) async {
    try {
      final query = await _firestore
          .collection('messages')
          .where('senderId', isEqualTo: otherUserId)
          .where('receiverId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();

      for (var doc in query.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Helper method to generate consistent conversation ID
  String _getConversationId(String userId1, String userId2) {
    final users = [userId1, userId2]..sort();
    return '${users[0]}_${users[1]}';
  }

  // Sample data for development/testing
  List<Map<String, dynamic>> _getSampleMessages(
    String userId1,
    String userId2,
  ) {
    return [
      {
        'id': '1',
        'senderId': userId2,
        'receiverId': userId1,
        'message': 'Hello! How are you feeling today?',
        'timestamp': DateTime.now().subtract(Duration(hours: 2)),
        'senderRole': 'medical',
        'isRead': true,
        'messageType': 'text',
      },
      {
        'id': '2',
        'senderId': userId1,
        'receiverId': userId2,
        'message':
            'I\'m feeling much better, thank you! The medication is working well.',
        'timestamp': DateTime.now().subtract(Duration(hours: 1, minutes: 30)),
        'senderRole': 'patient',
        'isRead': true,
        'messageType': 'text',
      },
      {
        'id': '3',
        'senderId': userId2,
        'receiverId': userId1,
        'message':
            'That\'s great to hear! Please continue with your current dosage and let me know if you experience any side effects.',
        'timestamp': DateTime.now().subtract(Duration(hours: 1)),
        'senderRole': 'medical',
        'isRead': false,
        'messageType': 'text',
      },
    ];
  }

  List<Map<String, dynamic>> _getSampleConversations(String userId) {
    return [
      {
        'id': 'conv_1',
        'otherUser': {
          'id': 'doctor_1',
          'uid': 'doctor_1',
          'name': 'Dr. Sarah Johnson',
          'role': 'medical',
          'email': 'sarah.johnson@hospital.com',
          'specialization': 'Hematologist',
        },
        'lastMessage':
            'Please continue with your current dosage and let me know if you experience any side effects.',
        'lastMessageTimestamp': DateTime.now().subtract(Duration(hours: 1)),
        'lastMessageSender': 'doctor_1',
        'isLastMessageRead': false,
      },
      {
        'id': 'conv_2',
        'otherUser': {
          'id': 'nurse_1',
          'uid': 'nurse_1',
          'name': 'Nurse Emily Rodriguez',
          'role': 'medical',
          'email': 'emily.rodriguez@hospital.com',
          'specialization': 'Clinical Nurse',
        },
        'lastMessage': 'Don\'t forget your appointment tomorrow at 2 PM.',
        'lastMessageTimestamp': DateTime.now().subtract(Duration(hours: 5)),
        'lastMessageSender': 'nurse_1',
        'isLastMessageRead': true,
      },
    ];
  }

  // Get unread message count for a user
  Future<int> getUnreadMessageCount(String userId) async {
    try {
      final query = await _firestore
          .collection('messages')
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      return query.docs.length;
    } catch (e) {
      print('Error getting unread message count: $e');
      return 0;
    }
  }

  // Stream messages for real-time updates
  Stream<List<Map<String, dynamic>>> getMessagesStream(
    String userId1,
    String userId2,
  ) {
    print('Starting message stream between $userId1 and $userId2');

    // Use a simpler approach - query all messages and filter on client side
    // This avoids complex stream combinations that might cause issues
    return _firestore
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          List<Map<String, dynamic>> messages = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();

            // Filter messages to only include those between the two specific users
            if ((data['senderId'] == userId1 &&
                    data['receiverId'] == userId2) ||
                (data['senderId'] == userId2 &&
                    data['receiverId'] == userId1)) {
              messages.add({
                'id': doc.id,
                ...data,
                'timestamp':
                    (data['timestamp'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
              });
            }
          }

          print(
            'Message stream update: ${messages.length} messages between $userId1 and $userId2',
          );
          return messages;
        });
  }
}
