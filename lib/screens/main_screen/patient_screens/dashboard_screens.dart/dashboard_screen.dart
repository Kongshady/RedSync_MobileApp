import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hemophilia_manager/services/firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final FirestoreService _firestoreService = FirestoreService();
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  String _userName = '';
  bool _isLoading = true;
  bool _isGuest = false;
  List<Map<String, dynamic>> _recentBleeds = [];
  List<Map<String, dynamic>> _recentInfusions = [];
  List<Map<String, dynamic>> _recentActivities = [];
  List<Map<String, dynamic>> _todaysReminders = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadRecentActivities();
    _loadTodaysReminders();
  }

  @override
  void didUpdateWidget(Dashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh data when the widget updates
    _loadRecentActivities();
    _loadTodaysReminders();
  }

  Future<void> _loadUserData() async {
    try {
      // Check if user is a guest
      final guestStatus = await _secureStorage.read(key: 'isGuest');
      setState(() {
        _isGuest = guestStatus == 'true';
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = await _firestoreService.getUser(user.uid);
        if (userData != null) {
          setState(() {
            _userName = _isGuest ? 'Guest' : (userData['name'] ?? 'User');
          });
        } else {
          setState(() {
            _userName = _isGuest ? 'Guest' : 'User';
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _userName = 'User';
        _isGuest = false;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRecentActivities() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('Loading recent activities for user: ${user.uid}'); // Debug log

        // Load recent bleeds from Firestore
        final bleeds = await _firestoreService.getBleedLogs(user.uid, limit: 5);
        _recentBleeds = bleeds;
        print('Loaded ${bleeds.length} bleed logs'); // Debug log

        // Load recent dosage calculations from Firestore
        final dosageHistory = await _firestoreService
            .getDosageCalculationHistory(user.uid, limit: 5);
        _recentInfusions = dosageHistory;
        print(
          'Loaded ${dosageHistory.length} dosage calculations',
        ); // Debug log

        // Combine all activities and sort by timestamp
        List<Map<String, dynamic>> allActivities = [];

        // Add bleeds with activity type
        for (var bleed in bleeds) {
          allActivities.add({
            ...bleed,
            'activityType': 'bleed',
            'timestamp': bleed['createdAt']?.millisecondsSinceEpoch ?? 0,
          });
        }

        // Add dosage calculations as infusion activities
        for (var dosage in dosageHistory) {
          allActivities.add({
            ...dosage,
            'activityType': 'infusion',
            'timestamp':
                dosage['createdAt']?.millisecondsSinceEpoch ??
                dosage['timestamp'] ??
                0,
          });
        }

        // Sort by timestamp (most recent first)
        allActivities.sort(
          (a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0),
        );

        // Take only the 5 most recent activities
        _recentActivities = allActivities.take(5).toList();
        print(
          'Total recent activities: ${_recentActivities.length}',
        ); // Debug log

        setState(() {});
      } else {
        print('No user logged in'); // Debug log
      }
    } catch (e) {
      print('Error loading recent activities: $e');
    }
  }

  Future<void> _loadTodaysReminders() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final reminders = await _firestoreService.getTodaysMedicationReminders(
          user.uid,
        );

        setState(() {
          _todaysReminders = reminders;
        });
      }
    } catch (e) {
      print('Error loading today\'s reminders: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeOfDay = _getTimeOfDay();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadUserData();
          await _loadRecentActivities();
          await _loadTodaysReminders();
        },
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Section
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _getTimeIcon(),
                        color: Colors.redAccent,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$timeOfDay${_isLoading ? '!' : ', $_userName!'}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'Here\'s your health summary for today',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Guest Mode Indicator
                if (_isGuest) ...[
                  SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Guest Mode',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Data won\'t be saved. Create an account to track your health progress.',
                                style: TextStyle(
                                  color: Colors.blue.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(
                              context,
                              '/register',
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue.shade700,
                            padding: EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 32),

                // Quick Stats Section
                _buildQuickStats(),
                SizedBox(height: 32),

                // Reminders Section
                _buildSection(
                  title: 'Today\'s Reminders',
                  icon: FontAwesomeIcons.clock,
                  children: [
                    if (_todaysReminders.isEmpty)
                      _buildReminderItem(
                        icon: FontAwesomeIcons.calendar,
                        title: 'No Reminders',
                        subtitle: 'No medication reminders scheduled for today',
                        iconColor: Colors.grey,
                      )
                    else
                      ..._todaysReminders.map(
                        (reminder) => Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: _buildSwipeableMedicationReminder(reminder),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 32),

                // Recent Activity Section
                _buildSection(
                  title: 'Recent Activity',
                  icon: FontAwesomeIcons.clockRotateLeft,
                  children: [
                    if (_recentActivities.isEmpty)
                      _buildEmptyState(
                        icon: FontAwesomeIcons.heart,
                        title: 'No recent activity',
                        subtitle: 'Your logged activities will appear here',
                      )
                    else
                      ..._recentActivities.map(
                        (activity) => Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: _buildActivityItem(
                            icon: activity['activityType'] == 'bleed'
                                ? FontAwesomeIcons.droplet
                                : FontAwesomeIcons.syringe,
                            title: activity['activityType'] == 'bleed'
                                ? 'Bleed Logged'
                                : 'Dosage Calculated',
                            subtitle: activity['activityType'] == 'bleed'
                                ? '${activity['bodyRegion'] ?? 'Unknown'} • ${activity['severity'] ?? 'Unknown'}'
                                : '${activity['factorType'] ?? 'Factor'} ${activity['dosage'] ?? '0'} IU',
                            time: _formatActivityTime(activity),
                            iconColor: activity['activityType'] == 'bleed'
                                ? Colors.red
                                : Colors.purple,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 50), // Add extra spacing at bottom instead of FAB space
              ],
            ),
          ),
        ),
    ));
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatContainer(
            icon: FontAwesomeIcons.droplet,
            value: '${_recentBleeds.length}',
            label: 'Recent Bleeds',
            color: Colors.red,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _buildStatContainer(
            icon: FontAwesomeIcons.syringe,
            value: '${_recentInfusions.length}',
            label: 'This Week',
            color: Colors.purple,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _buildStatContainer(
            icon: FontAwesomeIcons.calendar,
            value: '${_recentActivities.length}',
            label: 'Activities',
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatContainer({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: Colors.grey.shade700),
            ),
            SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildReminderItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Color iconColor,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatActivityTime(Map<String, dynamic> activity) {
    try {
      if (activity['activityType'] == 'bleed') {
        // For bleeds, use the date field
        return activity['date'] ?? 'Unknown';
      } else {
        // For dosage calculations, format the timestamp
        final timestamp = activity['timestamp'];
        if (timestamp != null) {
          final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          return '${date.day}/${date.month}/${date.year}';
        }
      }
    } catch (e) {
      print('Error formatting activity time: $e');
    }
    return 'Unknown';
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  IconData _getTimeIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) return FontAwesomeIcons.sun;
    if (hour < 17) return FontAwesomeIcons.cloudSun;
    return FontAwesomeIcons.moon;
  }

  Widget _buildSwipeableMedicationReminder(Map<String, dynamic> reminder) {
    return Slidable(
      key: ValueKey(reminder['id']),
      endActionPane: ActionPane(
        motion: ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => _markMedicationTaken(reminder),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            icon: Icons.check,
            label: 'Done',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: _buildMedicationReminderItemWithButton(reminder),
    );
  }

  Widget _buildMedicationReminderItemWithButton(Map<String, dynamic> reminder) {
    final reminderTime = reminder['reminderDateTime'] as DateTime?;
    final isPending = reminder['isPending'] as bool? ?? false;
    final isOverdue = reminder['isOverdue'] as bool? ?? false;

    IconData icon;
    Color iconColor;
    String status;

    if (isOverdue) {
      icon = FontAwesomeIcons.clockRotateLeft;
      iconColor = Colors.red;
      status = 'Overdue';
    } else if (isPending) {
      icon = FontAwesomeIcons.clock;
      iconColor = Colors.orange;
      status = 'Pending';
    } else {
      icon = FontAwesomeIcons.check;
      iconColor = Colors.green;
      status = 'Upcoming';
    }

    final timeString = reminderTime != null
        ? '${reminderTime.hour.toString().padLeft(2, '0')}:${reminderTime.minute.toString().padLeft(2, '0')}'
        : 'Unknown';

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOverdue
            ? Colors.red.shade50
            : isPending
            ? Colors.orange.shade50
            : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue
              ? Colors.red.shade200
              : isPending
              ? Colors.orange.shade200
              : Colors.green.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        reminder['medicationName'] ?? 'Unknown Medication',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: iconColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  '${reminder['dosage'] ?? 'Unknown dosage'} • ${reminder['administrationType'] ?? 'Unknown type'}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Scheduled for $timeString',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.swipe_left,
                            size: 12,
                            color: Colors.grey.shade600,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Swipe to mark done',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markMedicationTaken(Map<String, dynamic> reminder) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Mark medication as taken
      await _firestoreService.markMedicationTaken(user.uid, reminder['id']);

      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Medication marked as taken!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Refresh the reminders list
      await _loadTodaysReminders();
    } catch (e) {
      print('Error marking medication as taken: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to mark medication as taken'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
