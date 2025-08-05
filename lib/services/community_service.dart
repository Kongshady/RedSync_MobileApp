import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'firestore.dart';
import 'notification_service.dart';

class CommunityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService();

  // Get all posts for the community feed with real-time likes and comments
  Stream<List<Map<String, dynamic>>> getPostsStream() {
    return _firestore
        .collection('community_posts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          List<Map<String, dynamic>> posts = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();

            // Get author information
            final authorData = await _getUserData(data['authorId']);

            posts.add({
              'id': doc.id,
              'content': data['content'] ?? '',
              'timestamp':
                  (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
              'authorId': data['authorId'] ?? '',
              'authorName': authorData['name'] ?? 'Unknown User',
              'authorRole': authorData['role'] ?? 'Patient',
              'imageUrl': data['imageUrl'],
            });
          }

          return posts;
        });
  }

  // Get real-time likes count and user like status for a specific post
  Stream<Map<String, dynamic>> getLikesStream(String postId) {
    final currentUserId = _auth.currentUser?.uid ?? '';

    return _firestore
        .collection('community_posts')
        .doc(postId)
        .collection('likes')
        .snapshots()
        .map((snapshot) {
          final likesCount = snapshot.docs.length;
          final isLiked = snapshot.docs.any((like) => like.id == currentUserId);

          return {'count': likesCount, 'isLiked': isLiked};
        });
  }

  // Get real-time comments count for a specific post
  Stream<int> getCommentsCountStream(String postId) {
    return _firestore
        .collection('community_posts')
        .doc(postId)
        .collection('comments')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Get real-time comments for a specific post
  Stream<List<Map<String, dynamic>>> getCommentsStream(String postId) {
    return _firestore
        .collection('community_posts')
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'content': data['content'] ?? '',
              'timestamp':
                  (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
              'authorId': data['authorId'] ?? '',
              'authorName': data['authorName'] ?? 'Unknown User',
              'authorRole': data['authorRole'] ?? 'Patient',
            };
          }).toList();
        });
  }

  // Create a new post
  Future<void> createPost({required String content, String? imageUrl}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    await _firestore.collection('community_posts').add({
      'content': content,
      'authorId': currentUser.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'imageUrl': imageUrl,
    });
  }

  // Toggle like on a post
  Future<void> toggleLike(String postId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // Get post data to check author and content
      final postDoc = await _firestore
          .collection('community_posts')
          .doc(postId)
          .get();
      if (!postDoc.exists) return;

      final postData = postDoc.data()!;
      final postAuthorId = postData['authorId'] as String;
      final postContent = postData['content'] as String;

      final likeRef = _firestore
          .collection('community_posts')
          .doc(postId)
          .collection('likes')
          .doc(currentUser.uid);

      final likeDoc = await likeRef.get();

      if (likeDoc.exists) {
        // Unlike the post
        await likeRef.delete();
      } else {
        // Like the post
        await likeRef.set({
          'userId': currentUser.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Send notification to post author (don't notify if user likes their own post)
        if (postAuthorId != currentUser.uid) {
          final currentUserData = await _getUserData(currentUser.uid);
          final currentUserName = currentUserData['name'] ?? 'Someone';

          print(
            'Creating like notification for user: $postAuthorId by $currentUserName',
          );

          // Store notification in Firestore
          await _firestoreService.createNotificationWithData(
            uid: postAuthorId,
            text:
                '$currentUserName liked your post: "${postContent.length > 30 ? '${postContent.substring(0, 30)}...' : postContent}"',
            type: 'post_like',
            data: {
              'postId': postId,
              'likerName': currentUserName,
              'likerId': currentUser.uid,
            },
          );

          // Show local notification with proper navigation
          await _notificationService.showPostNotification(
            id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            title: 'New Like!',
            body:
                '$currentUserName liked your post: "${postContent.length > 30 ? '${postContent.substring(0, 30)}...' : postContent}"',
            postId: postId,
            type: 'like',
          );

          print('Like notification created successfully');
        }
      }
    } catch (e) {
      print('Error toggling like: $e');
      rethrow;
    }
  }

  // Add a comment to a post
  Future<void> addComment({
    required String postId,
    required String content,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Get post data to check author and content
      final postDoc = await _firestore
          .collection('community_posts')
          .doc(postId)
          .get();
      if (!postDoc.exists) return;

      final postData = postDoc.data()!;
      final postAuthorId = postData['authorId'] as String;

      // Get user data
      final userData = await _getUserData(currentUser.uid);
      final userName = userData['name'] ?? 'Unknown User';
      final userRole = userData['role'] ?? 'Patient';

      await _firestore
          .collection('community_posts')
          .doc(postId)
          .collection('comments')
          .add({
            'content': content,
            'authorId': currentUser.uid,
            'authorName': userName,
            'authorRole': userRole,
            'timestamp': FieldValue.serverTimestamp(),
          });

      // Send notification to post author (don't notify if user comments on their own post)
      if (postAuthorId != currentUser.uid) {
        print(
          'Creating comment notification for user: $postAuthorId by $userName',
        );

        // Store notification in Firestore
        await _firestoreService.createNotificationWithData(
          uid: postAuthorId,
          text:
              '$userName commented on your post: "${content.length > 50 ? '${content.substring(0, 50)}...' : content}"',
          type: 'post_comment',
          data: {
            'postId': postId,
            'commenterName': userName,
            'commenterId': currentUser.uid,
            'commentText': content,
          },
        );

        // Show local notification with proper navigation
        await _notificationService.showPostNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'New Comment!',
          body:
              '$userName commented on your post: "${content.length > 50 ? '${content.substring(0, 50)}...' : content}"',
          postId: postId,
          type: 'comment',
        );

        print('Comment notification created successfully');
      }
    } catch (e) {
      print('Error adding comment: $e');
      rethrow;
    }
  }

  // Get a specific post by ID
  Future<Map<String, dynamic>?> getPostById(String postId) async {
    try {
      final postDoc = await _firestore
          .collection('community_posts')
          .doc(postId)
          .get();

      if (!postDoc.exists) {
        return null;
      }

      final postData = postDoc.data()!;

      // Get real-time counts
      final likesSnapshot = await _firestore
          .collection('community_posts')
          .doc(postId)
          .collection('likes')
          .get();

      final commentsSnapshot = await _firestore
          .collection('community_posts')
          .doc(postId)
          .collection('comments')
          .get();

      // Check if current user liked this post
      final currentUser = _auth.currentUser;
      bool isLiked = false;
      if (currentUser != null) {
        final userLikeDoc = await _firestore
            .collection('community_posts')
            .doc(postId)
            .collection('likes')
            .doc(currentUser.uid)
            .get();
        isLiked = userLikeDoc.exists;
      }

      // Get author information from users collection
      final authorId = postData['authorId'] ?? '';
      String authorName = postData['authorName'] ?? '';
      String authorRole = postData['authorRole'] ?? '';

      if (authorId.isNotEmpty) {
        try {
          final authorData = await _getUserData(authorId);
          authorName = authorData['name'] ?? 'Unknown User';
          authorRole = authorData['role'] ?? 'Patient';
        } catch (e) {
          print('Error fetching author data: $e');
          // Fallback to stored data if fetching fails
          authorName = postData['authorName'] ?? 'Unknown User';
          authorRole = postData['authorRole'] ?? 'Patient';
        }
      }

      // Handle timestamp conversion
      DateTime? timestamp;
      final timestampData = postData['timestamp'] ?? postData['createdAt'];
      if (timestampData is Timestamp) {
        timestamp = timestampData.toDate();
      } else if (timestampData is DateTime) {
        timestamp = timestampData;
      } else {
        timestamp = DateTime.now(); // Fallback
      }

      return {
        'id': postDoc.id,
        'title': postData['title'] ?? '',
        'content': postData['content'] ?? '',
        'authorId': authorId,
        'authorName': authorName,
        'authorRole': authorRole,
        'timestamp': timestamp,
        'createdAt': timestamp,
        'likesCount': likesSnapshot.docs.length,
        'commentsCount': commentsSnapshot.docs.length,
        'isLiked': isLiked,
      };
    } catch (e) {
      print('Error getting post by ID: $e');
      return null;
    }
  }

  // Delete a post (only author can delete)
  Future<void> deletePost(String postId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Get the post to check if current user is the author
      final postDoc = await _firestore
          .collection('community_posts')
          .doc(postId)
          .get();
      if (!postDoc.exists) {
        throw Exception('Post not found');
      }

      final postData = postDoc.data()!;
      if (postData['authorId'] != currentUser.uid) {
        throw Exception('You can only delete your own posts');
      }

      // Delete all subcollections first
      final batch = _firestore.batch();

      // Delete likes
      final likesSnapshot = await _firestore
          .collection('community_posts')
          .doc(postId)
          .collection('likes')
          .get();
      for (var doc in likesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete comments
      final commentsSnapshot = await _firestore
          .collection('community_posts')
          .doc(postId)
          .collection('comments')
          .get();
      for (var doc in commentsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete the post itself
      batch.delete(_firestore.collection('community_posts').doc(postId));

      await batch.commit();
      print('Post deleted successfully: $postId');
    } catch (e) {
      print('Error deleting post: $e');
      rethrow;
    }
  }

  // Check if current user can delete a post
  bool canDeletePost(String postAuthorId) {
    final currentUser = _auth.currentUser;
    return currentUser != null && currentUser.uid == postAuthorId;
  }

  // Report a post
  Future<void> reportPost({
    required String postId,
    required String reason,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore.collection('post_reports').add({
      'postId': postId,
      'reporterId': currentUser.uid,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  // Get user data by ID
  Future<Map<String, dynamic>> _getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return {'id': userId, 'uid': userId, ...doc.data()!};
      }
    } catch (e) {
      print('Error getting user data: $e');
    }

    // Return default user data if not found
    return {
      'id': userId,
      'uid': userId,
      'name': 'Unknown User',
      'role': 'patient',
      'email': '',
    };
  }

  // Share post (create a reference/notification)
  Future<void> sharePost({required String postId, String? message}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // Get the post to find the owner
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) return;

      final postData = postDoc.data() as Map<String, dynamic>;
      final postOwnerId = postData['userId'] as String;

      // Create a share record
      await _firestore.collection('post_shares').add({
        'postId': postId,
        'sharerId': currentUser.uid,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Send notification to the post owner (if it's not their own post)
      if (postOwnerId != currentUser.uid) {
        final sharerName = currentUser.displayName ?? 'Someone';

        // Store notification in Firestore
        await _firestoreService.createNotificationWithData(
          uid: postOwnerId,
          text: '$sharerName shared your post',
          type: 'post_share',
          data: {
            'postId': postId,
            'sharerName': sharerName,
            'sharerId': currentUser.uid,
          },
        );

        // Show local notification with proper navigation
        await _notificationService.showPostNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'Post Shared!',
          body: '$sharerName shared your post',
          postId: postId,
          type: 'share',
        );
      }
    } catch (e) {
      print('Error sharing post: $e');
    }
  }
}
