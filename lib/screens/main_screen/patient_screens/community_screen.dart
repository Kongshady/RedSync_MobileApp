import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/community_service.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CommunityService _communityService = CommunityService();

  // Stream for real-time posts
  Stream<List<Map<String, dynamic>>>? _postsStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _postsStream = _communityService.getPostsStream();

    // Check for navigation arguments in the next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNavigationArguments();
    });
  }

  void _handleNavigationArguments() {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args.containsKey('openPostId')) {
      final postId = args['openPostId'] as String;
      _openSpecificPost(postId);
    }
  }

  void _openSpecificPost(String postId) async {
    try {
      // Get the specific post by ID
      final post = await _communityService.getPostById(postId);
      if (post != null) {
        // Navigate to the post detail screen
        _expandPost(post);
      } else {
        print('Post not found: $postId');
        // Show a snackbar or toast if post is not found
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Post not found')));
      }
    } catch (e) {
      print('Error opening specific post: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading post')));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        toolbarHeight: 70,
        title: Text('Community', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(FontAwesomeIcons.arrowLeft, size: 18),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Search feature coming soon'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: Icon(FontAwesomeIcons.magnifyingGlass, size: 16),
              color: Colors.grey.shade600,
            ),
          ),
          Container(
            margin: EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              onPressed: _showCreatePostDialog,
              icon: Icon(FontAwesomeIcons.plus, size: 16),
              color: Colors.redAccent,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade100, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.redAccent,
              labelColor: Colors.redAccent,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorWeight: 3,
              labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              tabs: [
                Tab(text: 'Feed'),
                Tab(text: 'Groups'),
                Tab(text: 'Events'),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [_buildFeedTab(), _buildGroupsTab(), _buildEventsTab()],
        ),
      ),
    );
  }

  Widget _buildFeedTab() {
    return RefreshIndicator(
      onRefresh: _refreshFeed,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _postsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
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
                    'Loading community posts...',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Icon(
                        FontAwesomeIcons.triangleExclamation,
                        size: 32,
                        color: Colors.orange.shade400,
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Error loading posts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please check your connection and try again',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _postsStream = _communityService.getPostsStream();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final posts = snapshot.data ?? [];

          if (posts.isEmpty) {
            return _buildEmptyFeedState();
          }

          return ListView.separated(
            padding: EdgeInsets.all(20),
            itemCount: posts.length,
            separatorBuilder: (context, index) => SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _buildPostItem(posts[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyFeedState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
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
                FontAwesomeIcons.users,
                size: 32,
                color: Colors.grey.shade400,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Welcome to the Community',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              'Connect with other patients, share your experiences, and support each other on your hemophilia journey.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            Container(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _showCreatePostDialog,
                icon: Icon(FontAwesomeIcons.plus, size: 16),
                label: Text('Create Your First Post'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Pull down to refresh',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostItem(Map<String, dynamic> post) {
    final postId = post['id'] as String;

    return InkWell(
      onTap: () => _expandPost(post),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              spreadRadius: 1,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post Header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(
                      (post['authorName'] ?? 'U').isNotEmpty
                          ? post['authorName'][0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post['authorName'] ?? 'Unknown User',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              post['authorRole'],
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            _formatTimestamp(_safeTimestamp(post['timestamp'])),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    onPressed: () => _showPostOptions(post),
                    icon: Icon(FontAwesomeIcons.ellipsis, size: 14),
                    color: Colors.grey.shade600,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Post Content
            Text(
              post['content'],
              style: TextStyle(
                fontSize: 15,
                color: Colors.black87,
                height: 1.5,
              ),
            ),

            SizedBox(height: 20),

            // Real-time engagement stats
            StreamBuilder<Map<String, dynamic>>(
              stream: _communityService.getLikesStream(postId),
              builder: (context, likesSnapshot) {
                return StreamBuilder<int>(
                  stream: _communityService.getCommentsCountStream(postId),
                  builder: (context, commentsSnapshot) {
                    final likesData =
                        likesSnapshot.data ?? {'count': 0, 'isLiked': false};
                    final likesCount = likesData['count'] as int;
                    final isLiked = likesData['isLiked'] as bool;
                    final commentsCount = commentsSnapshot.data ?? 0;

                    return Column(
                      children: [
                        // Engagement stats
                        if (likesCount > 0 || commentsCount > 0) ...[
                          Row(
                            children: [
                              if (likesCount > 0) ...[
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        FontAwesomeIcons.solidHeart,
                                        size: 12,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        '$likesCount',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              Spacer(),
                              if (commentsCount > 0) ...[
                                Text(
                                  '$commentsCount comments',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 16),
                        ],

                        // Divider
                        Container(
                          width: double.infinity,
                          height: 1,
                          color: Colors.grey.shade200,
                        ),
                        SizedBox(height: 16),

                        // Post Actions
                        Row(
                          children: [
                            _buildActionButton(
                              icon: isLiked
                                  ? FontAwesomeIcons.solidHeart
                                  : FontAwesomeIcons.heart,
                              label: 'Like',
                              color: isLiked
                                  ? Colors.red
                                  : Colors.grey.shade600,
                              onTap: () => _toggleLike(postId),
                            ),
                            SizedBox(width: 32),
                            _buildActionButton(
                              icon: FontAwesomeIcons.comment,
                              label: 'Comment',
                              color: Colors.grey.shade600,
                              onTap: () => _showCommentDialog(post),
                            ),
                            SizedBox(width: 32),
                            _buildActionButton(
                              icon: FontAwesomeIcons.share,
                              label: 'Share',
                              color: Colors.grey.shade600,
                              onTap: () => _sharePost(postId),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
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
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsTab() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              _buildComingSoonItem(
                icon: FontAwesomeIcons.users,
                title: 'Support Groups',
                subtitle:
                    'Connect with others in your area or condition-specific groups',
              ),
              SizedBox(height: 16),
              _buildComingSoonItem(
                icon: FontAwesomeIcons.commentDots,
                title: 'Discussion Forums',
                subtitle: 'Join topic-based discussions and ask questions',
              ),
              SizedBox(height: 16),
              _buildComingSoonItem(
                icon: FontAwesomeIcons.userDoctor,
                title: 'Expert Q&A',
                subtitle: 'Get answers from healthcare professionals',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventsTab() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              _buildComingSoonItem(
                icon: FontAwesomeIcons.calendar,
                title: 'Community Events',
                subtitle: 'Local meetups, conferences, and support events',
              ),
              SizedBox(height: 16),
              _buildComingSoonItem(
                icon: FontAwesomeIcons.chalkboardUser,
                title: 'Educational Webinars',
                subtitle: 'Learn from experts about hemophilia management',
              ),
              SizedBox(height: 16),
              _buildComingSoonItem(
                icon: FontAwesomeIcons.handHoldingHeart,
                title: 'Fundraising Events',
                subtitle: 'Participate in awareness and fundraising activities',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComingSoonItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(icon, color: Colors.redAccent, size: 24),
          ),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Coming Soon',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _expandPost(Map<String, dynamic> post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            PostDetailScreen(post: post, communityService: _communityService),
      ),
    );
  }

  void _showCommentDialog(Map<String, dynamic> post) {
    final TextEditingController commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          margin: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add Comment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Write a comment...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel'),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (commentController.text.trim().isNotEmpty) {
                            try {
                              await _communityService.addComment(
                                postId: post['id'],
                                content: commentController.text.trim(),
                              );
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Comment added!'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 1),
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
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('Post'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleLike(String postId) async {
    try {
      await _communityService.toggleLike(postId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating like: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _sharePost(String postId) async {
    try {
      await _communityService.sharePost(postId: postId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Post shared!'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
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

  Future<void> _refreshFeed() async {
    // Refresh the stream to get latest data
    setState(() {
      _postsStream = _communityService.getPostsStream();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Feed refreshed'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _showCreatePostDialog() {
    final TextEditingController postController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          margin: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Create Post',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: postController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Share your thoughts with the community...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel'),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (postController.text.trim().isNotEmpty) {
                            try {
                              await _communityService.createPost(
                                content: postController.text.trim(),
                              );
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Post created successfully!'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error creating post: $e'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('Post'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPostOptions(Map<String, dynamic> post) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwnPost =
        currentUser != null && post['authorId'] == currentUser.uid;

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
                  _showDeleteConfirmation(post);
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
                    content: Text('Feature coming soon'),
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
                  _showReportDialog(post);
                },
              ),
            ],
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> post) {
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
              await _deletePost(post);
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

  Future<void> _deletePost(Map<String, dynamic> post) async {
    try {
      await _communityService.deletePost(post['id']);
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

  void _showReportDialog(Map<String, dynamic> post) {
    String selectedReason = 'Inappropriate content';
    final reasons = [
      'Inappropriate content',
      'Spam or misleading',
      'Harassment or bullying',
      'False information',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                FontAwesomeIcons.flag,
                color: Colors.orange,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Text('Report Post'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Why are you reporting this post?'),
            SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setState) => Column(
                children: reasons
                    .map(
                      (reason) => RadioListTile<String>(
                        title: Text(reason),
                        value: reason,
                        groupValue: selectedReason,
                        onChanged: (value) {
                          setState(() {
                            selectedReason = value!;
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _reportPost(post, selectedReason);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text('Report'),
          ),
        ],
      ),
    );
  }

  Future<void> _reportPost(Map<String, dynamic> post, String reason) async {
    try {
      await _communityService.reportPost(postId: post['id'], reason: reason);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Post reported successfully'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error reporting post: $e'),
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

// PostDetailScreen - Expanded view like Facebook
class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final CommunityService communityService;

  const PostDetailScreen({
    super.key,
    required this.post,
    required this.communityService,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Map<String, dynamic> post;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    post = Map<String, dynamic>.from(widget.post);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Post'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Post Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.redAccent.withOpacity(0.1),
                        child: Text(
                          (post['authorName'] ?? 'U').isNotEmpty
                              ? post['authorName'][0].toUpperCase()
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
                              post['authorName'] ?? 'Unknown User',
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
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    post['authorRole'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  _formatTimestamp(
                                    _safeTimestamp(post['timestamp']),
                                  ),
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
                    post['content'],
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),

                  SizedBox(height: 20),

                  // Engagement stats using real-time streams
                  StreamBuilder<Map<String, dynamic>>(
                    stream: widget.communityService.getLikesStream(post['id']),
                    builder: (context, likesSnapshot) {
                      return StreamBuilder<int>(
                        stream: widget.communityService.getCommentsCountStream(
                          post['id'],
                        ),
                        builder: (context, commentsSnapshot) {
                          final likesData =
                              likesSnapshot.data ??
                              {'count': 0, 'isLiked': false};
                          final likesCount = likesData['count'] as int;
                          final commentsCount = commentsSnapshot.data ?? 0;

                          return Container(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade300),
                                bottom: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            child: Row(
                              children: [
                                if (likesCount > 0) ...[
                                  Icon(
                                    FontAwesomeIcons.solidHeart,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    '$likesCount likes',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                                Spacer(),
                                if (commentsCount > 0) ...[
                                  Text(
                                    '$commentsCount comments',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),

                  // Action buttons with real-time like status
                  StreamBuilder<Map<String, dynamic>>(
                    stream: widget.communityService.getLikesStream(post['id']),
                    builder: (context, likesSnapshot) {
                      final likesData =
                          likesSnapshot.data ?? {'count': 0, 'isLiked': false};
                      final isLiked = likesData['isLiked'] as bool;

                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                onPressed: _toggleLike,
                                icon: Icon(
                                  isLiked
                                      ? FontAwesomeIcons.solidHeart
                                      : FontAwesomeIcons.heart,
                                  size: 18,
                                  color: isLiked
                                      ? Colors.red
                                      : Colors.grey.shade600,
                                ),
                                label: Text(
                                  'Like',
                                  style: TextStyle(
                                    color: isLiked
                                        ? Colors.red
                                        : Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () {
                                  // Focus on comment input
                                  FocusScope.of(
                                    context,
                                  ).requestFocus(FocusNode());
                                },
                                icon: Icon(
                                  FontAwesomeIcons.comment,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                                label: Text(
                                  'Comment',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextButton.icon(
                                onPressed: _sharePost,
                                icon: Icon(
                                  FontAwesomeIcons.share,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                                label: Text(
                                  'Share',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  SizedBox(height: 16),

                  // Comments section with real-time updates
                  Text(
                    'Comments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),

                  SizedBox(height: 12),

                  // Real-time comments list
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: widget.communityService.getCommentsStream(
                      post['id'],
                    ),
                    builder: (context, commentsSnapshot) {
                      if (commentsSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.redAccent,
                              ),
                            ),
                          ),
                        );
                      }

                      final comments = commentsSnapshot.data ?? [];

                      if (comments.isEmpty) {
                        return Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'No comments yet. Be the first to comment!',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          return Container(
                            margin: EdgeInsets.only(bottom: 12),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.redAccent
                                          .withOpacity(0.1),
                                      child: Text(
                                        (comment['authorName'] ?? 'U')
                                                .isNotEmpty
                                            ? comment['authorName'][0]
                                                  .toUpperCase()
                                            : 'U',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            comment['authorName'] ??
                                                'Unknown User',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            _formatTimestamp(
                                              comment['timestamp'],
                                            ),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  comment['content'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Comment input
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  onPressed: _postComment,
                  icon: Icon(
                    FontAwesomeIcons.paperPlane,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleLike() async {
    try {
      await widget.communityService.toggleLike(post['id']);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating like: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _sharePost() async {
    try {
      await widget.communityService.sharePost(postId: post['id']);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Post shared!'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
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

  void _postComment() async {
    if (_commentController.text.trim().isNotEmpty) {
      try {
        await widget.communityService.addComment(
          postId: post['id'],
          content: _commentController.text.trim(),
        );
        _commentController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Comment posted!'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error posting comment: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
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
