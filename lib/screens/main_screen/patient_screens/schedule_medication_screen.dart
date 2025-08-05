import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hemophilia_manager/services/firestore.dart';
import 'package:hemophilia_manager/services/notification_service.dart';
import 'package:hemophilia_manager/services/app_notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ScheduleMedicationScreen extends StatefulWidget {
  const ScheduleMedicationScreen({super.key});

  @override
  State<ScheduleMedicationScreen> createState() =>
      _ScheduleMedicationScreenState();
}

class _ScheduleMedicationScreenState extends State<ScheduleMedicationScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService();
  final AppNotificationService _appNotificationService =
      AppNotificationService();
  String _medType = 'IV Injection';
  final List<String> _medTypes = ['IV Injection', 'Subcutaneous', 'Oral'];
  final TextEditingController _doseController = TextEditingController();
  final TextEditingController _medicationNameController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  TimeOfDay _selectedTime = TimeOfDay(hour: 9, minute: 0);
  bool _notification = true;
  String _frequency = 'Daily';
  final List<String> _frequencies = [
    'Daily',
    'Every 2 days',
    'Every 3 days',
    'Weekly',
    'As needed',
  ];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Schedule Medication',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.schedule, color: Colors.white, size: 24),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Schedule your medication',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Set reminders for your medication intake',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildCustomInput(
                      controller: _medicationNameController,
                      label: 'Medication Name',
                      icon: Icons.medical_services_outlined,
                      hintText: 'e.g., Factor VIII, Desmopressin',
                    ),
                    SizedBox(height: 16),

                    _buildDropdownField(
                      value: _medType,
                      items: _medTypes,
                      label: 'Administration Type',
                      icon: Icons.local_hospital,
                      onChanged: (val) {
                        if (val != null) setState(() => _medType = val);
                      },
                    ),
                    SizedBox(height: 16),

                    _buildCustomInput(
                      controller: _doseController,
                      label: 'Dosage',
                      icon: Icons.colorize,
                      hintText: 'e.g., 1000 IU, 250 mg',
                    ),
                    SizedBox(height: 16),

                    _buildTimeSelector(),
                    SizedBox(height: 16),

                    _buildDropdownField(
                      value: _frequency,
                      items: _frequencies,
                      label: 'Frequency',
                      icon: Icons.repeat,
                      onChanged: (val) {
                        if (val != null) setState(() => _frequency = val);
                      },
                    ),
                    SizedBox(height: 16),

                    _buildNotificationToggle(),
                    SizedBox(height: 16),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Additional Notes (Optional)',
                          hintText: 'Any special instructions or notes...',
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          prefixIcon: Icon(
                            Icons.note_outlined,
                            color: Colors.blueAccent,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                      ),
                    ),

                    SizedBox(height: 32),

                    // Set Schedule Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveSchedule,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: _isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(Icons.schedule, size: 20),
                        label: Text(
                          _isLoading ? 'Setting Schedule...' : 'Set Schedule',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hintText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String value,
    required List<String> items,
    required String label,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildTimeSelector() {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: _selectedTime,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: Colors.blueAccent,
                  onPrimary: Colors.white,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() => _selectedTime = picked);
        }
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, color: Colors.blueAccent, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reminder Time',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _selectedTime.format(context),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationToggle() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _notification ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _notification ? Colors.blue.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _notification ? Colors.blueAccent : Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications, color: Colors.white, size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Push Notifications',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Get reminded when it\'s time to take your medication',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Switch(
            value: _notification,
            onChanged: (val) => setState(() => _notification = val),
            activeColor: Colors.blueAccent,
          ),
        ],
      ),
    );
  }

  Future<void> _saveSchedule() async {
    // Validate form
    if (_medicationNameController.text.trim().isEmpty) {
      _showErrorDialog('Please enter the medication name');
      return;
    }

    if (_doseController.text.trim().isEmpty) {
      _showErrorDialog('Please enter the dosage');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorDialog('User not logged in');
        return;
      }

      // Save to Firestore
      final scheduleId = await _firestoreService.saveMedicationSchedule(
        uid: user.uid,
        medicationName: _medicationNameController.text.trim(),
        dosage: _doseController.text.trim(),
        administrationType: _medType,
        frequency: _frequency,
        reminderTime: _selectedTime,
        notificationEnabled: _notification,
        notes: _notesController.text.trim(),
      );

      // Schedule notification if enabled
      if (_notification) {
        try {
          await _notificationService.initialize();
          final permissionsGranted = await _notificationService
              .requestPermissions();

          if (!permissionsGranted) {
            _showInfoDialog(
              'Notification Warning',
              'Notification permissions were not granted. You may not receive medication reminders. Please enable notifications in your device settings.',
            );
          }

          // Generate a unique notification ID based on the schedule ID hash
          final notificationId = scheduleId.hashCode;

          print('Scheduling notification with ID: $notificationId');

          if (_frequency == 'Daily') {
            // Schedule daily repeating notification
            print('Scheduling daily repeating notification...');
            await _notificationService.scheduleRepeatingMedicationReminder(
              id: notificationId,
              title: 'Medication Reminder',
              body:
                  'Time to take ${_medicationNameController.text.trim()} (${_doseController.text.trim()})',
              time: _selectedTime,
              repeatInterval: RepeatInterval.daily,
              payload: 'medication_reminder:$scheduleId',
            );
            print(
              'Daily repeating notification scheduled for ${_selectedTime.format(context)}',
            );
          } else {
            // For other frequencies, schedule individual notifications
            print(
              'Scheduling individual notification for frequency: $_frequency',
            );
            final today = DateTime.now();
            final scheduledTime = DateTime(
              today.year,
              today.month,
              today.day,
              _selectedTime.hour,
              _selectedTime.minute,
            );

            // If the time has passed today, schedule for tomorrow
            final finalScheduledTime = scheduledTime.isBefore(today)
                ? scheduledTime.add(Duration(days: 1))
                : scheduledTime;

            print('Calculated scheduled time: $finalScheduledTime');
            print('Current time: $today');
            print(
              'Time difference: ${finalScheduledTime.difference(today).inMinutes} minutes',
            );

            await _notificationService.scheduleMedicationReminder(
              id: notificationId,
              title: 'Medication Reminder',
              body:
                  'Time to take ${_medicationNameController.text.trim()} (${_doseController.text.trim()})',
              scheduledTime: finalScheduledTime,
              payload: 'medication_reminder:$scheduleId',
            );
            print('Single notification scheduled for: $finalScheduledTime');
          }

          // Debug: Check pending notifications
          await _notificationService.debugPendingNotifications();

          // Show a test notification to confirm notifications are working
          try {
            await _notificationService.showImmediateNotification(
              id: 99999,
              title: 'Medication Schedule Created',
              body:
                  'Your medication reminder for ${_medicationNameController.text.trim()} has been set up successfully!',
              payload: 'schedule_created:$scheduleId',
            );
          } catch (e) {
            print('Failed to show confirmation notification: $e');
            // Don't fail the entire process if confirmation notification fails
          }

          // Also create a notification in our AppNotificationService for the in-app notifications
          try {
            await _appNotificationService.notifyMedicationReminder(
              recipientId: user.uid,
              medicationName: _medicationNameController.text.trim(),
              dosage: _doseController.text.trim(),
              scheduledTime:
                  DateTime.now(), // This is just for creating the notification record
            );
          } catch (e) {
            print('Failed to create in-app notification: $e');
            // Don't fail the entire process if in-app notification fails
          }
        } catch (e) {
          print('Error scheduling notification: $e');
          // Don't fail the entire operation if notification fails
          _showInfoDialog(
            'Notification Warning',
            'Your medication was scheduled successfully, but there was an issue setting up notifications. Please check your notification settings and ensure you have granted permission for notifications and exact alarms. You can try rescheduling the medication to fix this issue.',
          );
        }
      }

      // Show success dialog
      _showSuccessDialog();
    } catch (e) {
      _showErrorDialog('Failed to schedule medication: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.info, color: Colors.blue, size: 24),
              ),
              SizedBox(width: 12),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error, color: Colors.red, size: 24),
              ),
              SizedBox(width: 12),
              Text('Error'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, color: Colors.green, size: 24),
              ),
              SizedBox(width: 12),
              Text('Schedule Set!'),
            ],
          ),
          content: Text(
            'Your medication reminder has been scheduled successfully. You\'ll receive notifications at the specified time.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _doseController.dispose();
    _medicationNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

// TODO: Add calendar integration for medication reminders
