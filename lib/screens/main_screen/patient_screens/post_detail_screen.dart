import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../services/app_notification_service.dart';
import '../../../services/community_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final Function(Map<String, dynamic>) onPostUpdate;
  final AppNotificationService appNotificationService;

  const PostDetailScreen({
    super.key,
    required this.post,
    required this.onPostUpdate,
    required this.appNotificationService,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Map<String, dynamic> _post;
  final TextEditingController _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _post = Map<String, dynamic>.from(widget.post);

    // Calculate if current user has liked this post
    final user = _auth.currentUser;
    if (user != null) {
      final likes = List<String>.from(_post['likes'] ?? []);
      _post['isLiked'] = likes.contains(user.uid);
    } else {
      _post['isLiked'] = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Post Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _showPostOptions(),
            icon: Icon(FontAwesomeIcons.ellipsis),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Post
                  _buildMainPost(),

                  Divider(height: 1, color: Colors.grey.shade300),

                  // Comments Section
                  _buildCommentsSection(),
                ],
              ),
            ),
          ),

          // Comment Input
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildMainPost() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post Header
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                child: Text(
                  (_post['authorName'] ?? 'U').isNotEmpty
                      ? _post['authorName'][0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _post['authorName'] ?? 'Unknown User',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (_post['authorRole'] ?? 'Patient') ==
                                    'Healthcare Provider'
                                ? Colors.blue.shade50
                                : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _post['authorRole'] ?? 'Patient',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  (_post['authorRole'] ?? 'Patient') ==
                                      'Healthcare Provider'
                                  ? Colors.blue.shade700
                                  : Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          _formatTimestamp(_safeTimestamp(_post['timestamp'])),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Post Content
          Text(
            _post['content'],
            style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
          ),

          SizedBox(height: 20),

          // Post Actions
          Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionButton(
                  icon: _post['isLiked']
                      ? FontAwesomeIcons.solidHeart
                      : FontAwesomeIcons.heart,
                  label: '${_post['likeCount'] ?? 0} Likes',
                  color: _post['isLiked'] ? Colors.red : Colors.grey.shade600,
                  onTap: _toggleLike,
                ),
                _buildActionButton(
                  icon: FontAwesomeIcons.comment,
                  label: '${_post['commentCount'] ?? 0} Comments',
                  color: Colors.grey.shade600,
                  onTap: () => _scrollToComments(),
                ),
                _buildActionButton(
                  icon: FontAwesomeIcons.share,
                  label: 'Share',
                  color: Colors.grey.shade600,
                  onTap: _sharePost,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    final comments = List<dynamic>.from(_post['comments'] ?? []);

    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comments (${comments.length})',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),

          ...comments.map((comment) => _buildCommentItem(comment)),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    // Handle timestamp - could be Timestamp from Firestore or DateTime from local
    DateTime commentTime;
    if (comment['timestamp'] is Timestamp) {
      commentTime = (comment['timestamp'] as Timestamp).toDate();
    } else if (comment['timestamp'] is DateTime) {
      commentTime = comment['timestamp'];
    } else {
      commentTime = DateTime.now(); // fallback
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
            child: Text(
              (comment['authorName'] ?? 'A')[0].toUpperCase(),
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comment['authorName'] ?? 'Anonymous',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 6),
                  Text(
                    comment['content'] ?? '',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _formatTimestamp(commentTime),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
              child: Text(
                'U',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Write a comment...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: Colors.redAccent),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            IconButton(
              onPressed: () {
                if (_commentController.text.trim().isNotEmpty) {
                  _addComment(_commentController.text.trim());
                  _commentController.clear();
                }
              },
              icon: Icon(FontAwesomeIcons.paperPlane),
              color: Colors.redAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLike() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userId = user.uid;
      final postRef = _firestore.collection('community_posts').doc(_post['id']);

      // Get current likes
      final likes = List<String>.from(_post['likes'] ?? []);
      final isCurrentlyLiked = likes.contains(userId);

      if (isCurrentlyLiked) {
        // Remove like
        await postRef.update({
          'likes': FieldValue.arrayRemove([userId]),
          'likeCount': FieldValue.increment(-1),
        });

        setState(() {
          likes.remove(userId);
          _post['likes'] = likes;
          _post['likeCount'] = (_post['likeCount'] ?? 0) - 1;
          _post['isLiked'] = false;
        });
      } else {
        // Add like
        await postRef.update({
          'likes': FieldValue.arrayUnion([userId]),
          'likeCount': FieldValue.increment(1),
        });

        setState(() {
          likes.add(userId);
          _post['likes'] = likes;
          _post['likeCount'] = (_post['likeCount'] ?? 0) + 1;
          _post['isLiked'] = true;
        });

        // Send notification to post author (only if not liking own post)
        if (_post['authorId'] != userId) {
          await widget.appNotificationService.notifyPostLike(
            recipientId: _post['authorId'],
            likerName: user.displayName ?? 'Someone',
            postId: _post['id'],
            postPreview: _post['content'] ?? '',
          );
        }
      }

      widget.onPostUpdate(_post);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating like: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sharePost() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final postRef = _firestore.collection('community_posts').doc(_post['id']);
      await postRef.update({
        'shares': FieldValue.arrayUnion([user.uid]),
        'shareCount': FieldValue.increment(1),
      });

      setState(() {
        final shares = List<String>.from(_post['shares'] ?? []);
        shares.add(user.uid);
        _post['shares'] = shares;
        _post['shareCount'] = (_post['shareCount'] ?? 0) + 1;
      });

      // Send notification to post author (only if not sharing own post)
      if (_post['authorId'] != user.uid) {
        await widget.appNotificationService.notifyPostShare(
          recipientId: _post['authorId'],
          sharerName: user.displayName ?? 'Someone',
          postId: _post['id'],
          postPreview: _post['content'] ?? '',
        );
      }

      widget.onPostUpdate(_post);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Post shared successfully!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing post: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _scrollToComments() {
    // In a real app, you would scroll to comments section
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Scroll to comments'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _addComment(String commentText) async {
    try {
      final user = _auth.currentUser;
      if (user == null || commentText.trim().isEmpty) return;

      final commentData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'authorId': user.uid,
        'authorName': user.displayName ?? 'Anonymous',
        'content': commentText.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Update Firestore
      final postRef = _firestore.collection('community_posts').doc(_post['id']);
      await postRef.update({
        'comments': FieldValue.arrayUnion([commentData]),
        'commentCount': FieldValue.increment(1),
      });

      // Update local state
      setState(() {
        final comments = List<dynamic>.from(_post['comments'] ?? []);
        comments.insert(0, {
          ...commentData,
          'timestamp': DateTime.now(), // For local display
        });
        _post['comments'] = comments;
        _post['commentCount'] = (_post['commentCount'] ?? 0) + 1;
      });

      widget.onPostUpdate(_post);

      // Send notification to post author
      if (_post['authorId'] != user.uid) {
        await widget.appNotificationService.notifyPostComment(
          recipientId: _post['authorId'],
          commenterName: user.displayName ?? 'Someone',
          postId: _post['id'],
          postPreview: _post['content'] ?? '',
          commentText: commentText.trim(),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Comment added!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding comment: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPostOptions() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwnPost =
        currentUser != null && _post['authorId'] == currentUser.uid;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwnPost) ...[
              ListTile(
                leading: Icon(FontAwesomeIcons.trash, color: Colors.red),
                title: Text('Delete Post', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation();
                },
              ),
              Divider(height: 1),
            ],
            ListTile(
              leading: Icon(FontAwesomeIcons.bookmark, color: Colors.blue),
              title: Text('Save Post'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Post saved! (Feature coming soon)'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            if (!isOwnPost) ...[
              ListTile(
                leading: Icon(FontAwesomeIcons.flag, color: Colors.orange),
                title: Text('Report Post'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Post reported! (Feature coming soon)'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(FontAwesomeIcons.trash, color: Colors.red, size: 20),
            ),
            SizedBox(width: 12),
            Text('Delete Post'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deletePost();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost() async {
    try {
      // We need to import and use the community service
      final communityService = CommunityService();
      await communityService.deletePost(_post['id']);

      // Navigate back to community screen
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Post deleted successfully'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting post: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Helper method to safely convert timestamp
  DateTime _safeTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is DateTime) return timestamp;
    if (timestamp is Timestamp) return timestamp.toDate();
    return DateTime.now(); // Fallback
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

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
