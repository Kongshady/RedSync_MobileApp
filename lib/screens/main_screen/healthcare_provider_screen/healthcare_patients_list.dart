import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hemophilia_manager/screens/main_screen/healthcare_provider_screen/patient_details_screen.dart';
import '../../../services/firestore.dart';
import '../shared/chat_screen.dart';

class HealthcarePatientsList extends StatefulWidget {
  const HealthcarePatientsList({super.key});

  @override
  State<HealthcarePatientsList> createState() => _HealthcarePatientsListState();
}

class _HealthcarePatientsListState extends State<HealthcarePatientsList>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();
  final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleRequest(
    String requestId,
    String patientUid,
    bool accept,
  ) async {
    try {
      if (accept) {
        // Accept the request
        await FirebaseFirestore.instance
            .collection('data_sharing_requests')
            .doc(requestId)
            .update({
              'status': 'accepted',
              'acceptedAt': FieldValue.serverTimestamp(),
            });

        // Create a data sharing relationship
        await FirebaseFirestore.instance.collection('data_sharing').add({
          'patientUid': patientUid,
          'providerUid': currentUid,
          'createdAt': FieldValue.serverTimestamp(),
          'active': true,
        });

        // Send notification to patient
        await _firestoreService.createNotification(
          patientUid,
          'Your data sharing request has been accepted by the healthcare provider.',
        );

        _showSnackBar('Request accepted successfully', Colors.green);
      } else {
        // Reject the request
        await FirebaseFirestore.instance
            .collection('data_sharing_requests')
            .doc(requestId)
            .update({
              'status': 'rejected',
              'rejectedAt': FieldValue.serverTimestamp(),
            });

        // Send notification to patient
        await _firestoreService.createNotification(
          patientUid,
          'Your data sharing request has been declined by the healthcare provider.',
        );

        _showSnackBar('Request rejected', Colors.orange);
      }
    } catch (e) {
      _showSnackBar('Error processing request: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: Text(
          'RedSync PH',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: StreamBuilder<int>(
              stream: _firestoreService.getUnreadNotificationCount(currentUid),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;
                return Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.redAccent.withOpacity(0.1),
                      child: IconButton(
                        icon: const Icon(
                          FontAwesomeIcons.solidBell,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        onPressed: () {
                          Navigator.pushNamed(context, '/notifications');
                        },
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/settings');
              },
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade200,
                child: Icon(Icons.person, color: Colors.grey.shade600),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.redAccent,
          labelColor: Colors.redAccent,
          unselectedLabelColor: Colors.grey.shade600,
          tabs: [
            Tab(icon: Icon(FontAwesomeIcons.users, size: 18), text: 'Patients'),
            Tab(icon: Icon(FontAwesomeIcons.inbox, size: 18), text: 'Requests'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // Patients List Tab
            _buildPatientsListTab(),
            // Incoming Request Tab
            _buildIncomingRequestsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientsListTab() {
    return Column(
      children: [
        // Header section
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(24, 20, 24, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade100, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Patients',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Manage your patient relationships',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        // Patients list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('data_sharing')
                .where('providerUid', isEqualTo: currentUid)
                .where('active', isEqualTo: true)
                .snapshots(),
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
                          strokeWidth: 2.5,
                          color: Colors.redAccent,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Loading patients...',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FontAwesomeIcons.triangleExclamation,
                        size: 48,
                        color: Colors.red.shade300,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Error loading patients',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final dataSharingDocs = snapshot.data?.docs ?? [];

              if (dataSharingDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Icon(
                          FontAwesomeIcons.userGroup,
                          size: 32,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'No patients yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 48),
                        child: Text(
                          'Patients who share their data with you will appear here',
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
                );
              }

              return ListView.separated(
                padding: EdgeInsets.symmetric(vertical: 8),
                itemCount: dataSharingDocs.length,
                separatorBuilder: (context, index) =>
                    Divider(height: 1, color: Colors.grey.shade100, indent: 80),
                itemBuilder: (context, index) {
                  final sharingData =
                      dataSharingDocs[index].data() as Map<String, dynamic>;
                  final patientUid = sharingData['patientUid'];

                  return FutureBuilder<Map<String, dynamic>?>(
                    future: _firestoreService.getUser(patientUid),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) {
                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: Colors.grey.shade500,
                                  size: 24,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 120,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Container(
                                      width: 160,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final userData = userSnapshot.data!;
                      final userName = userData['name'] ?? 'Unknown Patient';
                      final userEmail = userData['email'] ?? 'No email';

                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PatientDetailsScreen(
                                patientUid: patientUid,
                                patientData: userData,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          child: Row(
                            children: [
                              // Avatar
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Center(
                                  child: Text(
                                    userName[0].toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              // Patient info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      userEmail,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Action buttons
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: IconButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ChatScreen(
                                              participant: {
                                                'id': patientUid,
                                                'name': userData['name'],
                                                'role': 'patient',
                                                'profilePicture':
                                                    userData['profilePicture'],
                                              },
                                              currentUserRole: 'medical',
                                            ),
                                          ),
                                        );
                                      },
                                      icon: Icon(
                                        FontAwesomeIcons.message,
                                        color: Colors.blue.shade600,
                                        size: 16,
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(
                                    FontAwesomeIcons.chevronRight,
                                    color: Colors.grey.shade400,
                                    size: 14,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIncomingRequestsTab() {
    return Column(
      children: [
        // Header section
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(24, 20, 24, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade100, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Requests',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Review pending data sharing requests',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        // Requests list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('data_sharing_requests')
                .where('providerUid', isEqualTo: currentUid)
                .where('status', isEqualTo: 'pending')
                .snapshots(),
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
                          strokeWidth: 2.5,
                          color: Colors.redAccent,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Loading requests...',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FontAwesomeIcons.triangleExclamation,
                        size: 48,
                        color: Colors.red.shade300,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Error loading requests',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final requests = snapshot.data?.docs ?? [];

              if (requests.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Icon(
                          FontAwesomeIcons.inbox,
                          size: 32,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'No pending requests',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 48),
                        child: Text(
                          'Data sharing requests from patients will appear here',
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
                );
              }

              return ListView.separated(
                padding: EdgeInsets.all(24),
                itemCount: requests.length,
                separatorBuilder: (context, index) => SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final request = requests[index];
                  final requestData = request.data() as Map<String, dynamic>;
                  final patientUid = requestData['patientUid'];
                  final requestId = request.id;

                  return FutureBuilder<Map<String, dynamic>?>(
                    future: _firestoreService.getUser(patientUid),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) {
                        return Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 120,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Container(
                                      width: 200,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final userData = userSnapshot.data!;
                      final userName = userData['name'] ?? 'Unknown Patient';
                      final userEmail = userData['email'] ?? 'No email';

                      return Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.blue.shade100,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Patient info
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade600,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Center(
                                    child: Text(
                                      userName[0].toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        userName,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        userEmail,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            // Request message
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    FontAwesomeIcons.shareNodes,
                                    color: Colors.blue.shade600,
                                    size: 16,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Wants to share their health data with you',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16),
                            // Action buttons
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 44,
                                    child: ElevatedButton(
                                      onPressed: () => _handleRequest(
                                        requestId,
                                        patientUid,
                                        true,
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade600,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            FontAwesomeIcons.check,
                                            size: 14,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Accept',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    height: 44,
                                    child: ElevatedButton(
                                      onPressed: () => _handleRequest(
                                        requestId,
                                        patientUid,
                                        false,
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.grey.shade600,
                                        elevation: 0,
                                        side: BorderSide(
                                          color: Colors.grey.shade300,
                                          width: 1,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            FontAwesomeIcons.xmark,
                                            size: 14,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Decline',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
