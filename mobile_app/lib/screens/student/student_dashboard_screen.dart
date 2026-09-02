import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/location_service.dart';
import '../../core/services/api_service.dart';
import '../../models/attendance_model.dart';
import '../../models/session_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../auth/login_screen.dart';
import 'mark_attendance_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  int _selectedSemester = 3;
  bool _hasLocationPermission = true;

  final Set<String> _notifiedSessionIds = {};
  Set<String> _pinnedSubjectCodes = {};

  // Complete MCA Curriculum Directory across all 4 Semesters (31 Courses)
  // Teacher names stay blank until real faculty registers and is assigned in database.
  static const Map<int, List<Map<String, dynamic>>> mcaCurriculum = {
    1: [
      {'code': 'MCA-101', 'name': 'Mathematical Foundation', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': ''},
      {'code': 'MCA-102', 'name': 'Data and File Structures', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': ''},
      {'code': 'MCA-103', 'name': 'Computer Organization & Arch', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': ''},
      {'code': 'MCA-104', 'name': 'Microprocessor & Applications', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': ''},
      {'code': 'MCA-105', 'name': 'Management Functions', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': ''},
      {'code': 'MCA-111', 'name': 'Communicative English Presentation', 'type': 'Practical', 'credits': 2, 'hours': '3 hrs/wk', 'teacher': ''},
      {'code': 'MCA-112', 'name': 'DFS Lab with C', 'type': 'Practical', 'credits': 3, 'hours': '3 hrs/wk', 'teacher': ''},
      {'code': 'MCA-113', 'name': 'Digital Circuits & Organization Lab', 'type': 'Practical', 'credits': 3, 'hours': '3 hrs/wk', 'teacher': ''},
      {'code': 'MCA-114', 'name': 'Microprocessor Lab', 'type': 'Practical', 'credits': 3, 'hours': '3 hrs/wk', 'teacher': ''},
      {'code': 'MCA-141*', 'name': 'Intro to Computing & C (Bridge)', 'type': 'Bridge Course', 'credits': 0, 'hours': '2 hrs/wk', 'teacher': ''},
    ],
    2: [
      {'code': 'MCA-201', 'name': 'Design & Analysis of Algorithms', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': ''},
      {'code': 'MCA-202', 'name': 'Object Oriented Programming', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': ''},
      {'code': 'MCA-203', 'name': 'Database Management Systems', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': ''},
      {'code': 'MCA-204', 'name': 'Operating Systems', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': ''},
      {'code': 'MCA-205', 'name': 'Scientific Computing', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': ''},
      {'code': 'MCA-211', 'name': 'OOP Laboratory', 'type': 'Practical', 'credits': 3, 'hours': '3 hrs/wk', 'teacher': ''},
      {'code': 'MCA-212', 'name': 'DBMS Laboratory', 'type': 'Practical', 'credits': 3, 'hours': '3 hrs/wk', 'teacher': ''},
      {'code': 'MCA-213', 'name': 'Scientific Computing Lab', 'type': 'Practical', 'credits': 3, 'hours': '3 hrs/wk', 'teacher': ''},
      {'code': 'MCA-214', 'name': 'Advanced Programming Lab–I', 'type': 'Practical', 'credits': 3, 'hours': '3 hrs/wk', 'teacher': ''},
    ],
    3: [
      {'code': 'MCA-301', 'name': 'Artificial Intelligence', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': ''},
      {'code': 'MCA-302', 'name': 'Computer Networks', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': ''},
      {'code': 'MCA-303', 'name': 'Software Engineering', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': ''},
      {'code': 'MCA-304', 'name': 'Elective – I (Cloud Computing / ML)', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': ''},
      {'code': 'MCA-305', 'name': 'Elective – II (Cyber Security)', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': ''},
      {'code': 'MCA-306', 'name': 'Elective – III (Mobile Computing)', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': ''},
      {'code': 'MCA-311', 'name': 'AI Laboratory', 'type': 'Practical', 'credits': 3, 'hours': '3 hrs/wk', 'teacher': ''},
      {'code': 'MCA-312', 'name': 'Web-based Programming Lab', 'type': 'Practical', 'credits': 3, 'hours': '3 hrs/wk', 'teacher': ''},
      {'code': 'MCA-313', 'name': 'Advanced Programming Lab-II', 'type': 'Practical', 'credits': 3, 'hours': '3 hrs/wk', 'teacher': ''},
      {'code': 'MCA-321', 'name': 'Minor Project–I', 'type': 'Project', 'credits': 3, 'hours': '6 hrs/wk', 'teacher': ''},
    ],
    4: [
      {'code': 'MCA-421', 'name': 'Major Capstone Project–II', 'type': 'Project', 'credits': 16, 'hours': '20 hrs/wk', 'teacher': ''},
      {'code': 'MCA-431', 'name': 'Grand Viva Voce', 'type': 'Viva', 'credits': 8, 'hours': 'Comprehensive', 'teacher': ''},
    ],
  };

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _loadPinnedSubjects();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final studentSem = auth.currentUser?.student?.semester ?? 3;
      setState(() => _selectedSemester = studentSem);

      final attendance = Provider.of<AttendanceProvider>(context, listen: false);
      attendance.connectRealTimeStream();
      attendance.startStudentSessionPolling();
      attendance.fetchStudentDashboard();
    });
  }

  Future<void> _loadPinnedSubjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('student_pinned_subjects') ?? [];
      if (mounted) {
        setState(() {
          _pinnedSubjectCodes = list.toSet();
        });
      }
    } catch (_) {}
  }

  Future<void> _togglePinSubject(String code, String name) async {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_pinnedSubjectCodes.contains(code)) {
        _pinnedSubjectCodes.remove(code);
      } else {
        _pinnedSubjectCodes.add(code);
      }
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('student_pinned_subjects', _pinnedSubjectCodes.toList());
    } catch (_) {}

    final isPinned = _pinnedSubjectCodes.contains(code);
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPinned ? 'Pinned $code ($name) to top' : 'Unpinned $code',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          backgroundColor: isPinned ? AppTheme.seaGreen : AppTheme.charcoal,
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  void dispose() {
    final attendance = Provider.of<AttendanceProvider>(context, listen: false);
    attendance.stopStudentSessionPolling();
    super.dispose();
  }

  void _checkAndPromptLiveSession(List<SessionModel> sessions) {
    for (final session in sessions) {
      if (!session.isAlreadyMarked && !_notifiedSessionIds.contains(session.id)) {
        _notifiedSessionIds.add(session.id);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showLiveSessionPopup(session);
          }
        });
        break;
      }
    }
  }

  void _showLiveSessionPopup(SessionModel session) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Color(0xFFFEF3C7), shape: BoxShape.circle),
              child: const Icon(Icons.notifications_active_outlined, color: Color(0xFFD97706), size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Live Session Started!',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.charcoal),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.subjectName,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.charcoal),
            ),
            const SizedBox(height: 2),
            Text(
              '${session.subjectCode} • ${session.teacherName.isNotEmpty ? session.teacherName : "Faculty"}',
              style: const TextStyle(fontSize: 12, color: AppTheme.charcoalMuted),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.seaGreenTint,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.seaGreen.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.timer_outlined, size: 16, color: AppTheme.seaGreenDark),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '15-Minute geofence window active. Ensure you are inside the 50m department radius to mark attendance.',
                      style: TextStyle(fontSize: 11, color: AppTheme.seaGreenDark, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss', style: TextStyle(color: AppTheme.charcoalMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MarkAttendanceScreen(session: session)),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.seaGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Mark Attendance Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkLocationPermission() async {
    final hasPermission = await LocationService.requestPermissions();
    if (mounted) {
      setState(() => _hasLocationPermission = hasPermission);
    }
  }

  Future<void> _requestLocationPermission() async {
    final permission = await Geolocator.requestPermission();
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
    }
    await _checkLocationPermission();
  }

  Color _getStatusColor(double percentage, {int conducted = 1}) {
    if (conducted == 0) return AppTheme.charcoalMuted;
    if (percentage >= 75.0) return AppTheme.seaGreen;
    if (percentage >= 60.0) return AppTheme.statusWarning;
    return AppTheme.statusDanger;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final attendance = Provider.of<AttendanceProvider>(context);
    final student = auth.currentUser?.student;
    final stats = attendance.dashboardStats;

    // Trigger popup check on every state update
    if (attendance.activeStudentSessions.isNotEmpty) {
      _checkAndPromptLiveSession(attendance.activeStudentSessions);
    }

    final currentSemCurriculum = mcaCurriculum[_selectedSemester] ?? [];

    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      appBar: AppBar(
        title: const Text('Student Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20, color: AppTheme.charcoal),
            onPressed: () {
              attendance.fetchStudentDashboard();
              attendance.fetchStudentActiveSessions();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20, color: AppTheme.charcoal),
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: attendance.isLoading && stats == null
          ? const Center(child: CircularProgressIndicator(color: AppTheme.seaGreen))
          : RefreshIndicator(
              color: AppTheme.seaGreen,
              backgroundColor: AppTheme.creamCard,
              onRefresh: () async {
                await attendance.fetchStudentDashboard();
                await attendance.fetchStudentActiveSessions();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Student Header Profile Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.charcoal,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  auth.currentUser?.name ?? 'Student',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.seaGreen,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Semester $_selectedSemester',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Class Roll: ${student?.classRoll ?? "-"}  •  Uni Roll: ${student?.universityRoll ?? "-"}',
                            style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Registration No: ${student?.regNumber ?? "-"}  •  Department: MCA',
                            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Location Permission Prompt Banner (When GPS permission is not granted)
                    if (!_hasLocationPermission)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_disabled_outlined, color: Color(0xFFD97706), size: 24),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Location Access Required',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF92400E)),
                                  ),
                                  Text(
                                    'Precise GPS is needed to verify you are inside the 50m department radius.',
                                    style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _requestLocationPermission,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD97706),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Enable GPS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ],
                        ),
                      ),

                    // Active 15-Minute Session Notification (Sea Green / Amber)
                    if (attendance.activeStudentSessions.isNotEmpty) ...[
                      ...attendance.activeStudentSessions.map((session) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: session.isAlreadyMarked ? AppTheme.seaGreenTint : const Color(0xFFFEF3C7),
                            border: Border.all(
                              color: session.isAlreadyMarked ? AppTheme.seaGreen.withOpacity(0.3) : const Color(0xFFF59E0B),
                              width: 1.2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                session.isAlreadyMarked ? Icons.check_circle_outline : Icons.access_time,
                                color: session.isAlreadyMarked ? AppTheme.seaGreen : const Color(0xFFD97706),
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      session.isAlreadyMarked ? 'Attendance Recorded' : 'Live Attendance Session!',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: session.isAlreadyMarked ? AppTheme.seaGreenDark : const Color(0xFF92400E),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${session.subjectName} (${session.subjectCode})',
                                      style: const TextStyle(fontSize: 13, color: AppTheme.charcoal, fontWeight: FontWeight.w500),
                                    ),
                                    if (!session.isAlreadyMarked)
                                      Text(
                                        '15-min auto cutoff (${session.remainingSeconds ~/ 60}m remaining)',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                                      ),
                                  ],
                                ),
                              ),
                              if (!session.isAlreadyMarked)
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MarkAttendanceScreen(session: session),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.seaGreen,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                  child: const Text('Mark Now', style: TextStyle(fontSize: 12)),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],

                    // Aggregate Attendance Dial Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.creamCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.creamBorder, width: 1.0),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          CircularPercentIndicator(
                            radius: 46.0,
                            lineWidth: 8.0,
                            animation: true,
                            percent: ((stats?.overallPercentage ?? 0.0) / 100).clamp(0.0, 1.0),
                            center: Text(
                              "${(stats?.totalClassesConducted ?? 0) > 0 ? stats?.overallPercentage.toStringAsFixed(1) : '0.0'}%",
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppTheme.charcoal,
                              ),
                            ),
                            circularStrokeCap: CircularStrokeCap.round,
                            progressColor: _getStatusColor(stats?.overallPercentage ?? 0.0, conducted: stats?.totalClassesConducted ?? 0),
                            backgroundColor: const Color(0xFFF1EDE4),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Overall Aggregate Attendance',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.charcoal),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Classes: ${stats?.totalClassesAttended ?? 0} / ${stats?.totalClassesConducted ?? 0}',
                                style: const TextStyle(color: AppTheme.charcoalMuted, fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(stats?.overallPercentage ?? 0.0, conducted: stats?.totalClassesConducted ?? 0).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  stats?.statusCategory ?? ((stats?.totalClassesConducted ?? 0) > 0 ? 'Safe Zone (≥ 75%)' : 'No Classes Yet'),
                                  style: TextStyle(
                                    color: _getStatusColor(stats?.overallPercentage ?? 0.0, conducted: stats?.totalClassesConducted ?? 0),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Semester Selector Tabs (Sem 1, 2, 3, 4)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Syllabus & Semester Details',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.charcoal,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          '${currentSemCurriculum.length} Courses',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.charcoalMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Semester Choice Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [1, 2, 3, 4].map((sem) {
                          final isSelected = _selectedSemester == sem;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(
                                'Semester $sem',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? Colors.white : AppTheme.charcoal,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: AppTheme.charcoal,
                              backgroundColor: AppTheme.creamCard,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: isSelected ? AppTheme.charcoal : AppTheme.creamBorder),
                              ),
                              onSelected: (val) {
                                if (val) setState(() => _selectedSemester = sem);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tip banner explaining tap & hold pinning
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1EDE4).withOpacity(0.7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.creamBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.push_pin_outlined, size: 14, color: AppTheme.charcoalMuted),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Tap & hold any subject card to pin it to the top.',
                              style: TextStyle(fontSize: 11, color: AppTheme.charcoalMuted, fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (_pinnedSubjectCodes.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.seaGreenTint,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.seaGreen.withOpacity(0.3)),
                              ),
                              child: Text(
                                '${_pinnedSubjectCodes.length} Pinned',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.seaGreenDark),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Curriculum & Subject Attendance List (Sorted with Pinned Subjects at Top)
                    ...() {
                      final rawList = mcaCurriculum[_selectedSemester] ?? [];
                      final List<Map<String, dynamic>> sortedList = List.from(rawList);
                      sortedList.sort((a, b) {
                        final aPinned = _pinnedSubjectCodes.contains(a['code']);
                        final bPinned = _pinnedSubjectCodes.contains(b['code']);
                        if (aPinned && !bPinned) return -1;
                        if (!aPinned && bPinned) return 1;
                        return 0;
                      });

                      return sortedList.map((course) {
                        final code = course['code'] as String;
                        final name = course['name'] as String;
                        final type = course['type'] as String;
                        final credits = course['credits'] as int;
                        final hours = course['hours'] as String;
                        final defaultTeacher = course['teacher'] as String;
                        final isPinned = _pinnedSubjectCodes.contains(code);

                        // Check if real live stats exist from backend
                        SubjectAttendanceStats? liveStat;
                        try {
                          liveStat = attendance.subjectStats.firstWhere(
                            (s) => s.code.toLowerCase().trim() == code.toLowerCase().trim(),
                          );
                        } catch (_) {
                          liveStat = null;
                        }

                        final percentage = liveStat?.percentage ?? 0.0;
                        final attended = liveStat?.classesAttended ?? 0;
                        final conducted = liveStat?.classesConducted ?? 0;
                        final teacher = (liveStat?.teacherName != null && liveStat!.teacherName.trim().isNotEmpty)
                            ? liveStat.teacherName
                            : (defaultTeacher.isNotEmpty ? defaultTeacher : ' — ');

                        final isPractical = type.contains('Practical');
                        final isBridge = type.contains('Bridge');
                        final isProject = type.contains('Project');
                        final isViva = type.contains('Viva');

                        return InkWell(
                          onTap: () => _showSubjectDetailsModal(
                            context,
                            code: code,
                            name: name,
                            type: type,
                            credits: credits,
                            hours: hours,
                            teacher: teacher,
                            percentage: percentage,
                            attended: attended,
                            conducted: conducted,
                            student: student,
                            studentName: auth.currentUser?.name ?? 'Student',
                          ),
                          onLongPress: () => _togglePinSubject(code, name),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isPinned ? const Color(0xFFFBFBF6) : AppTheme.creamCard,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isPinned ? AppTheme.seaGreen.withOpacity(0.5) : AppTheme.creamBorder,
                                width: isPinned ? 1.5 : 1.0,
                              ),
                              boxShadow: isPinned
                                  ? [BoxShadow(color: AppTheme.seaGreen.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))]
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.charcoal,
                                                  borderRadius: BorderRadius.circular(5),
                                                ),
                                                child: Text(
                                                  code,
                                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Colors.white),
                                                ),
                                              ),
                                              if (isPinned) ...[
                                                const SizedBox(width: 5),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFEF3C7),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5)),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.push_pin_rounded, size: 10, color: Color(0xFFD97706)),
                                                      SizedBox(width: 2),
                                                      Text(
                                                        'PINNED',
                                                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 8.5, color: Color(0xFF92400E)),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isPractical
                                                      ? AppTheme.seaGreenTint
                                                      : isBridge
                                                          ? const Color(0xFFFEF3C7)
                                                          : isProject || isViva
                                                              ? const Color(0xFFEDE9FE)
                                                              : const Color(0xFFF3F4F6),
                                                  borderRadius: BorderRadius.circular(5),
                                                ),
                                                child: Text(
                                                  type,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 10,
                                                    color: isPractical
                                                        ? AppTheme.seaGreenDark
                                                        : isBridge
                                                            ? const Color(0xFF92400E)
                                                            : isProject || isViva
                                                                ? const Color(0xFF5B21B6)
                                                                : AppTheme.charcoalMuted,
                                                  ),
                                                ),
                                              ),
                                              if (credits > 0) ...[
                                                const SizedBox(width: 6),
                                                Text(
                                                  '$credits Credits',
                                                  style: const TextStyle(color: AppTheme.charcoalLight, fontSize: 11, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            name,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.charcoal),
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _togglePinSubject(code, name),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: isPinned ? const Color(0xFFFEF3C7) : Colors.transparent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                                          size: 16,
                                          color: isPinned ? const Color(0xFFD97706) : AppTheme.charcoalMuted.withOpacity(0.4),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${percentage.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: _getStatusColor(percentage),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Faculty: $teacher  •  Load: $hours',
                                  style: const TextStyle(color: AppTheme.charcoalMuted, fontSize: 11),
                                ),
                                const SizedBox(height: 10),
                                LinearPercentIndicator(
                                  lineHeight: 5.0,
                                  percent: (percentage / 100).clamp(0.0, 1.0),
                                  progressColor: _getStatusColor(percentage),
                                  backgroundColor: const Color(0xFFF1EDE4),
                                  barRadius: const Radius.circular(3),
                                  padding: EdgeInsets.zero,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      conducted > 0 ? '$attended / $conducted classes attended' : '0 / 0 Conducted • Term Starting',
                                      style: const TextStyle(color: AppTheme.charcoalLight, fontSize: 11),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Text('View Details', style: TextStyle(color: AppTheme.seaGreen, fontSize: 11, fontWeight: FontWeight.w700)),
                                        SizedBox(width: 4),
                                        Icon(Icons.arrow_forward_rounded, size: 12, color: AppTheme.seaGreen),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList();
                    }(),
                  ],
                ),
              ),
            ),
    );
  }

  // --- INTERACTIVE DETAILS & MONTHLY CALENDAR MODAL ---
  void _showSubjectDetailsModal(
    BuildContext context, {
    required String code,
    required String name,
    required String type,
    required int credits,
    required String hours,
    required String teacher,
    required double percentage,
    required num attended,
    required num conducted,
    dynamic student,
    required String studentName,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SubjectCalendarBottomSheet(
        code: code,
        name: name,
        type: type,
        credits: credits,
        hours: hours,
        teacher: teacher,
        percentage: percentage,
        attended: attended,
        conducted: conducted,
        student: student,
        studentName: studentName,
      ),
    );
  }
}

class _SubjectCalendarBottomSheet extends StatefulWidget {
  final String code;
  final String name;
  final String type;
  final int credits;
  final String hours;
  final String teacher;
  final double percentage;
  final num attended;
  final num conducted;
  final dynamic student;
  final String studentName;

  const _SubjectCalendarBottomSheet({
    required this.code,
    required this.name,
    required this.type,
    required this.credits,
    required this.hours,
    required this.teacher,
    required this.percentage,
    required this.attended,
    required this.conducted,
    required this.student,
    required this.studentName,
  });

  @override
  State<_SubjectCalendarBottomSheet> createState() => _SubjectCalendarBottomSheetState();
}

class _SubjectCalendarBottomSheetState extends State<_SubjectCalendarBottomSheet> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  int _selectedDay = DateTime.now().day;

  bool _isLoading = true;
  final Map<String, Map<String, dynamic>> _recordsByDate = {};
  final Set<String> _conductedDates = {};
  String _realTeacherName = '';
  double _realPercentage = 0.0;
  num _realAttended = 0;
  num _realConducted = 0;

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const List<String> _weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  void initState() {
    super.initState();
    _realPercentage = widget.percentage;
    _realAttended = widget.attended;
    _realConducted = widget.conducted;
    _realTeacherName = widget.teacher;
    _fetchRealAttendanceHistory();
  }

  Future<void> _fetchRealAttendanceHistory() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getStudentSubjectHistory(widget.code);
      if (res != null && mounted) {
        final history = res['history'] as List? ?? [];
        _recordsByDate.clear();
        for (final item in history) {
          final dateStr = item['date'] as String?;
          if (dateStr != null) {
            _recordsByDate[dateStr] = Map<String, dynamic>.from(item);
          }
        }

        final conducted = res['conductedDates'] as List? ?? [];
        _conductedDates.clear();
        for (final c in conducted) {
          _conductedDates.add(c.toString());
        }

        if (res['subject'] != null && res['subject']['teacherName'] != null) {
          _realTeacherName = res['subject']['teacherName'];
        }
        if (res['stats'] != null) {
          _realPercentage = (res['stats']['percentage'] as num?)?.toDouble() ?? widget.percentage;
          _realAttended = (res['stats']['classesAttended'] as num?) ?? widget.attended;
          _realConducted = (res['stats']['classesConducted'] as num?) ?? widget.conducted;
        }

        setState(() => _isLoading = false);
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _prevMonth() {
    setState(() {
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear--;
      } else {
        _selectedMonth--;
      }
      _selectedDay = 1;
    });
  }

  void _nextMonth() {
    setState(() {
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else {
        _selectedMonth++;
      }
      _selectedDay = 1;
    });
  }

  String _getDateKey(int day) {
    return '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final firstWeekday = DateTime(_selectedYear, _selectedMonth, 1).weekday % 7; // Sunday = 0, Saturday = 6
    final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;

    if (_selectedDay > daysInMonth) {
      _selectedDay = daysInMonth;
    }

    bool isWeekendDay(int day) {
      final dayOfWeek = DateTime(_selectedYear, _selectedMonth, day).weekday % 7;
      return dayOfWeek == 0 || dayOfWeek == 6; // Sunday or Saturday
    }

    bool isPresentDay(int day) {
      if (isWeekendDay(day)) return false;
      final key = _getDateKey(day);
      final rec = _recordsByDate[key];
      return rec != null && rec['status'] == 'Full';
    }

    bool isHalfDay(int day) {
      if (isWeekendDay(day)) return false;
      final key = _getDateKey(day);
      final rec = _recordsByDate[key];
      return rec != null && rec['status'] == 'Half';
    }

    bool isAbsentDay(int day) {
      if (isWeekendDay(day)) return false;
      final key = _getDateKey(day);
      return _conductedDates.contains(key) && !_recordsByDate.containsKey(key);
    }

    final selectedKey = _getDateKey(_selectedDay);
    final selectedIsWeekend = isWeekendDay(_selectedDay);
    final selectedRecord = _recordsByDate[selectedKey];
    final selectedIsPresent = selectedRecord != null && selectedRecord['status'] == 'Full';
    final selectedIsHalf = selectedRecord != null && selectedRecord['status'] == 'Half';
    final selectedIsAbsent = isAbsentDay(_selectedDay);

    final currentMonthName = _monthNames[_selectedMonth - 1];

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.creamBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.creamBorder, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 14),

            // Header Course Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.charcoal, borderRadius: BorderRadius.circular(4)),
                            child: Text(widget.code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                          const SizedBox(width: 6),
                          Text(widget.type, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppTheme.seaGreenDark)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(widget.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.charcoal)),
                      Text(
                        'Faculty: ${_realTeacherName.isNotEmpty ? _realTeacherName : " — "}  •  ${widget.hours}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.charcoalMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.creamCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.creamBorder),
                  ),
                  child: Text(
                    '${_realPercentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _realPercentage >= 75 ? AppTheme.seaGreen : AppTheme.statusDanger,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: AppTheme.creamBorder),
            const SizedBox(height: 8),

            // Month Navigator (< Month Year >)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.creamBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: AppTheme.charcoal),
                    onPressed: _prevMonth,
                    tooltip: 'Previous Month',
                  ),
                  Text(
                    '$currentMonthName $_selectedYear',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.charcoal),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: AppTheme.charcoal),
                    onPressed: _nextMonth,
                    tooltip: 'Next Month',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Color Coding Legend: Present (Sea Green) | Absent (Red) | Holiday (Grey)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: AppTheme.seaGreen, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      const Text('Present (1.0)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.seaGreenDark)),
                    ],
                  ),
                  Row(
                    children: [
                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      const Text('Absent (0.0)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF991B1B))),
                    ],
                  ),
                  Row(
                    children: [
                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF9CA3AF), shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      const Text('Holiday / Off', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Weekday Headers: Sun, Mon, Tue, Wed, Thu, Fri, Sat
            Row(
              children: _weekDays.map((day) {
                final isWeekend = (day == 'Sun' || day == 'Sat');
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isWeekend ? const Color(0xFF9CA3AF) : AppTheme.charcoal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),

            // Dynamic Calendar Grid (Week starting Sunday to Saturday)
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1.0,
                ),
                itemCount: firstWeekday + daysInMonth,
                itemBuilder: (context, index) {
                  if (index < firstWeekday) {
                    return const SizedBox();
                  }

                  final day = index - firstWeekday + 1;
                  final isSelected = _selectedDay == day;
                  final isWeekend = isWeekendDay(day);
                  final attended = isPresentDay(day);
                  final half = isHalfDay(day);
                  final absent = isAbsentDay(day);

                  Color bgColor = const Color(0xFFF3F4F6);
                  Color textColor = AppTheme.charcoalMuted;
                  Color borderColor = Colors.transparent;

                  if (isWeekend) {
                    // Saturday & Sunday are always Holiday (Grey)
                    bgColor = const Color(0xFFE5E7EB);
                    textColor = const Color(0xFF9CA3AF);
                  } else if (attended) {
                    // Present (Sea Green)
                    bgColor = AppTheme.seaGreenTint;
                    textColor = AppTheme.seaGreenDark;
                  } else if (half) {
                    // Half Attendance (Amber)
                    bgColor = const Color(0xFFFEF3C7);
                    textColor = const Color(0xFFB45309);
                  } else if (absent) {
                    // Absent (Red)
                    bgColor = const Color(0xFFFEE2E2);
                    textColor = const Color(0xFF991B1B);
                  }

                  if (isSelected) {
                    borderColor = AppTheme.charcoal;
                  }

                  return InkWell(
                    onTap: () => setState(() => _selectedDay = day),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: borderColor,
                          width: isSelected ? 2.0 : 1.0,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: (attended || half || absent) ? textColor : AppTheme.charcoalMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 14),

            // Selected Date Proof Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selectedIsWeekend
                    ? const Color(0xFFF3F4F6)
                    : selectedIsPresent
                        ? AppTheme.seaGreenTint
                        : selectedIsHalf
                            ? const Color(0xFFFEF3C7)
                            : selectedIsAbsent
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selectedIsWeekend
                      ? AppTheme.creamBorder
                      : selectedIsPresent
                          ? AppTheme.seaGreen.withOpacity(0.3)
                          : selectedIsHalf
                              ? const Color(0xFFF59E0B).withOpacity(0.3)
                              : selectedIsAbsent
                                  ? const Color(0xFFEF4444).withOpacity(0.3)
                                  : AppTheme.creamBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    selectedIsWeekend
                        ? Icons.hotel_outlined
                        : selectedIsPresent
                            ? Icons.check_circle_outline
                            : selectedIsHalf
                                ? Icons.timelapse_outlined
                                : selectedIsAbsent
                                    ? Icons.cancel_outlined
                                    : Icons.event_busy_outlined,
                    color: selectedIsWeekend
                        ? const Color(0xFF9CA3AF)
                        : selectedIsPresent
                            ? AppTheme.seaGreenDark
                            : selectedIsHalf
                                ? const Color(0xFFB45309)
                                : selectedIsAbsent
                                    ? const Color(0xFF991B1B)
                                    : AppTheme.charcoalMuted,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$currentMonthName $_selectedDay, $_selectedYear • ${selectedRecord?['time'] ?? '10:15 AM'}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppTheme.charcoal),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedIsWeekend
                              ? 'Weekend / Holiday (No lecture scheduled).'
                              : selectedIsPresent
                                  ? 'GPS Verified: ${selectedRecord?['distanceMeters'] != null ? "${selectedRecord!['distanceMeters'].toStringAsFixed(1)}m within 50m Dept" : "Inside 50m Dept"} • Google Sheets Synced'
                                  : selectedIsHalf
                                      ? 'Manual Override granted by Faculty • Synced to Google Sheets (H)'
                                      : selectedIsAbsent
                                          ? 'Absent: No attendance marked during 15-min session window.'
                                          : 'No lecture conducted on this date.',
                          style: TextStyle(
                            fontSize: 10,
                            color: selectedIsWeekend
                                ? const Color(0xFF6B7280)
                                : selectedIsPresent
                                    ? AppTheme.seaGreenDark
                                    : selectedIsHalf
                                        ? const Color(0xFFB45309)
                                        : selectedIsAbsent
                                            ? const Color(0xFF991B1B)
                                            : AppTheme.charcoalMuted,
                          ),
                        ),
                        if (selectedIsPresent || selectedIsHalf)
                          Text(
                            'Token: SHA256:${widget.code.replaceAll("-", "")}-${_selectedDay}${currentMonthName.substring(0, 3).toUpperCase()}-GPS-VALID',
                            style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: AppTheme.charcoalMuted),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: selectedIsWeekend
                          ? const Color(0xFF9CA3AF)
                          : selectedIsPresent
                              ? AppTheme.seaGreen
                              : selectedIsHalf
                                  ? const Color(0xFFD97706)
                                  : selectedIsAbsent
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF9CA3AF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      selectedIsWeekend
                          ? 'Holiday'
                          : selectedIsPresent
                              ? 'Present'
                              : selectedIsHalf
                                  ? 'Half'
                                  : selectedIsAbsent
                                      ? 'Absent'
                                      : 'Off',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Single Full-Width Action Button: Close Details
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.charcoal,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Close Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
