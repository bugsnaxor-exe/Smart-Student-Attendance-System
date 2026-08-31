import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/location_provider.dart';
import '../../models/session_model.dart';

class MarkAttendanceScreen extends StatefulWidget {
  final SessionModel session;

  const MarkAttendanceScreen({super.key, required this.session});

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.session.remainingSeconds;
    _startCountdown();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final loc = Provider.of<LocationProvider>(context, listen: false);
      loc.refreshLocation();
    });
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _handleMarkAttendance() async {
    final loc = Provider.of<LocationProvider>(context, listen: false);
    final attendance = Provider.of<AttendanceProvider>(context, listen: false);

    if (loc.currentPosition == null) {
      await loc.refreshLocation();
    }

    if (loc.isMockDetected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fake GPS app detected. Mock locations are strictly prohibited.'),
          backgroundColor: AppTheme.statusDanger,
        ),
      );
      return;
    }

    if (!loc.isInsideGeofence) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are ${loc.distanceToDept}m away. Must be within 50m of department.'),
          backgroundColor: AppTheme.statusDanger,
        ),
      );
      return;
    }

    final success = await attendance.markAttendance(
      subjectId: widget.session.subjectId,
      position: loc.currentPosition!,
      isMockLocation: loc.isMockDetected,
    );

    if (success && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.creamCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          icon: const Icon(Icons.check_circle_outline, color: AppTheme.seaGreen, size: 52),
          title: const Text(
            'Attendance Recorded',
            style: TextStyle(color: AppTheme.charcoal, fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Full attendance successfully registered for ${widget.session.subjectName} and synced with the department sheet.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.charcoalMuted, fontSize: 13),
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Return to dashboard
                },
                child: const Text('Return to Portal'),
              ),
            ),
          ],
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(attendance.errorMessage ?? 'Failed to mark attendance.'),
          backgroundColor: AppTheme.statusDanger,
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocationProvider>(context);
    final attendance = Provider.of<AttendanceProvider>(context);
    final isExpired = _remainingSeconds <= 0;

    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      appBar: AppBar(
        title: const Text('Geofence Verification'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Session Details Minimalist Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.creamCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.creamBorder, width: 1.0),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.session.subjectName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: AppTheme.charcoal,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${widget.session.subjectCode}  •  ${widget.session.teacherName}',
                      style: const TextStyle(color: AppTheme.charcoalMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 12),

                    // Countdown Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isExpired ? Colors.red.shade50 : AppTheme.seaGreenTint,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isExpired ? Colors.red.shade200 : AppTheme.seaGreen.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: isExpired ? AppTheme.statusDanger : AppTheme.seaGreen,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isExpired ? 'Session Closed' : 'Cutoff Window: ${_formatTime(_remainingSeconds)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: isExpired ? AppTheme.statusDanger : AppTheme.seaGreenDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Minimalist Geofence Radar
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer Radar Ring
                        Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: loc.isInsideGeofence
                                ? AppTheme.seaGreen.withOpacity(0.08)
                                : AppTheme.statusDanger.withOpacity(0.08),
                          ),
                        ),
                        // Middle Ring
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: loc.isInsideGeofence
                                ? AppTheme.seaGreen.withOpacity(0.15)
                                : AppTheme.statusDanger.withOpacity(0.15),
                          ),
                        ),
                        // Central Dot
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: loc.isInsideGeofence ? AppTheme.seaGreen : AppTheme.statusDanger,
                          ),
                          child: Icon(
                            loc.isInsideGeofence ? Icons.near_me_outlined : Icons.location_off_outlined,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    if (loc.isChecking)
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.seaGreen)),
                          SizedBox(width: 10),
                          Text('Scanning multi-sample GPS (3 samples)...', style: TextStyle(color: AppTheme.charcoalMuted, fontSize: 13)),
                        ],
                      )
                    else if (loc.isMockDetected)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: const Text(
                          '⚠️ Fake/Mock GPS Detected. Attendance blocked.',
                          style: TextStyle(color: AppTheme.statusDanger, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      )
                    else
                      Column(
                        children: [
                          Text(
                            loc.isInsideGeofence ? 'Inside 50m Department Perimeter' : 'Outside Geofence',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: loc.isInsideGeofence ? AppTheme.seaGreen : AppTheme.statusDanger,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Current Distance: ${loc.distanceToDept} meters (Limit: 50m)',
                            style: const TextStyle(color: AppTheme.charcoalMuted, fontSize: 13),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const Spacer(),

              // Re-scan Button
              OutlinedButton.icon(
                onPressed: loc.isChecking ? null : () => loc.refreshLocation(),
                icon: const Icon(Icons.my_location, size: 18),
                label: const Text('Re-scan Exact Location'),
              ),
              const SizedBox(height: 12),

              // Primary Action Button
              ElevatedButton(
                onPressed: (isExpired || !loc.isInsideGeofence || attendance.isLoading || loc.isMockDetected)
                    ? null
                    : _handleMarkAttendance,
                child: attendance.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        isExpired
                            ? 'Session Closed'
                            : !loc.isInsideGeofence
                                ? 'Move Inside 50m Perimeter'
                                : 'Mark Full Attendance',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
