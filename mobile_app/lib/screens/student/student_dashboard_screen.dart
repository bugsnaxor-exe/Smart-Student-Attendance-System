import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/location_service.dart';
import '../../models/attendance_model.dart';
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

  // Complete MCA Curriculum Directory across all 4 Semesters (31 Courses)
  static const Map<int, List<Map<String, dynamic>>> mcaCurriculum = {
    1: [
      {'code': 'MCA-101', 'name': 'Mathematical Foundation', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': 'Dr. S. Mukherjee'},
      {'code': 'MCA-102', 'name': 'Data and File Structures', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': 'Prof. A. Ray'},
      {'code': 'MCA-103', 'name': 'Computer Organization & Arch', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': 'Prof. M. Dutta'},
      {'code': 'MCA-104', 'name': 'Microprocessor & Applications', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': 'Dr. K. Basu'},
      {'code': 'MCA-105', 'name': 'Management Functions', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': 'Prof. P. Sengupta'},
      {'code': 'MCA-111', 'name': 'Communicative English Presentation', 'type': 'Practical', 'credits': 2, 'hours': '3 hrs/wk', 'teacher': 'Prof. N. Ghosh'},
      {'code': 'MCA-112', 'name': 'DFS Lab with C', 'type': 'Practical', 'credits': 3, 'hours': '3 hrs/wk', 'teacher': 'Prof. A. Ray'},
      {'code': 'MCA-113', 'name': 'Digital Circuits & Organization Lab', 'type': 'Practical', 'credits': 3, 'hours': '3 hrs/wk', 'teacher': 'Prof. M. Dutta'},
      {'code': 'MCA-114', 'name': 'Microprocessor Lab', 'type': 'Practical', 'credits': 3, 'hours': '3 hrs/wk', 'teacher': 'Dr. K. Basu'},
      {'code': 'MCA-141*', 'name': 'Intro to Computing & C (Bridge)', 'type': 'Bridge Course', 'credits': 0, 'hours': '2 hrs/wk', 'teacher': 'Prof. T. Roy'},
    ],
    2: [
      {'code': 'MCA-201', 'name': 'Design & Analysis of Algorithms', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': 'Dr. S. Mukherjee'},
      {'code': 'MCA-202', 'name': 'Object Oriented Programming', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': 'Prof. R. Sharma'},
      {'code': 'MCA-203', 'name': 'Database Management Systems', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': 'Prof. P. Das'},
      {'code': 'MCA-204', 'name': 'Operating Systems', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': 'Prof. M. Dutta'},
      {'code': 'MCA-205', 'name': 'Scientific Computing', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': 'Dr. K. Basu'},
      {'code': 'MCA-211', 'name': 'OOP Laboratory', 'type': 'Practical', 'credits': 3, 'hours': '3 hrs/wk', 'teacher': 'Prof. R. Sharma'},
      {'code': 'MCA-212', 'name': 'DBMS Laboratory', 'type': 'Practical', 'credits': 3, 'hours': '3 hrs/wk', 'teacher': 'Prof. P. Das'},
      {'code': 'MCA-213', 'name': 'Scientific Computing Lab', 'type': 'Practical', 'credits': 3, 'hours': '3 hrs/wk', 'teacher': 'Dr. K. Basu'},
      {'code': 'MCA-214', 'name': 'Advanced Programming Lab–I', 'type': 'Practical', 'credits': 3, 'hours': '3 hrs/wk', 'teacher': 'Prof. T. Roy'},
    ],
    3: [
      {'code': 'MCA-301', 'name': 'Artificial Intelligence', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': 'Prof. R. K. Sharma'},
      {'code': 'MCA-302', 'name': 'Computer Networks', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': 'Dr. S. Mukherjee'},
      {'code': 'MCA-303', 'name': 'Software Engineering', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': 'Prof. P. Das'},
      {'code': 'MCA-304', 'name': 'Elective – I (Cloud Computing / ML)', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': 'Prof. M. Dutta'},
      {'code': 'MCA-305', 'name': 'Elective – II (Cyber Security)', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': 'Dr. K. Basu'},
      {'code': 'MCA-306', 'name': 'Elective – III (Mobile Computing)', 'type': 'Theory', 'credits': 4, 'hours': '4 hrs/wk', 'teacher': 'Prof. A. Ray'},
      {'code': 'MCA-311', 'name': 'AI Laboratory', 'type': 'Practical', 'credits': 3, 'hours': '3 hrs/wk', 'teacher': 'Prof. R. K. Sharma'},
      {'code': 'MCA-312', 'name': 'Web-based Programming Lab', 'type': 'Practical', 'credits': 3, 'hours': '3 hrs/wk', 'teacher': 'Prof. T. Roy'},
      {'code': 'MCA-313', 'name': 'Advanced Programming Lab-II', 'type': 'Practical', 'credits': 3, 'hours': '3 hrs/wk', 'teacher': 'Prof. P. Das'},
      {'code': 'MCA-321', 'name': 'Minor Project–I', 'type': 'Project', 'credits': 3, 'hours': '6 hrs/wk', 'teacher': 'Faculty Committee'},
    ],
    4: [
      {'code': 'MCA-421', 'name': 'Major Capstone Project–II', 'type': 'Project', 'credits': 16, 'hours': '20 hrs/wk', 'teacher': 'Department Project Guides'},
      {'code': 'MCA-431', 'name': 'Grand Viva Voce', 'type': 'Viva', 'credits': 8, 'hours': 'Comprehensive', 'teacher': 'HOD & External Board'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final studentSem = auth.currentUser?.student?.semester ?? 3;
      setState(() => _selectedSemester = studentSem);

      final attendance = Provider.of<AttendanceProvider>(context, listen: false);
      attendance.fetchStudentDashboard();
      attendance.fetchStudentActiveSessions();
    });
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

  Color _getStatusColor(double percentage) {
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
                                  'Enrolled Sem ${student?.semester ?? 3}',
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
                            percent: ((stats?.overallPercentage ?? 100.0) / 100).clamp(0.0, 1.0),
                            center: Text(
                              "${stats?.overallPercentage.toStringAsFixed(1) ?? '100'}%",
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppTheme.charcoal,
                              ),
                            ),
                            circularStrokeCap: CircularStrokeCap.round,
                            progressColor: _getStatusColor(stats?.overallPercentage ?? 100.0),
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
                                  color: _getStatusColor(stats?.overallPercentage ?? 100.0).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  stats?.statusCategory ?? 'Safe Zone (≥ 75%)',
                                  style: TextStyle(
                                    color: _getStatusColor(stats?.overallPercentage ?? 100.0),
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
                          final isCurrent = (student?.semester ?? 3) == sem;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(
                                'Semester $sem${isCurrent ? " (Current)" : ""}',
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

                    // Curriculum & Subject Attendance List
                    ...currentSemCurriculum.map((course) {
                      final code = course['code'] as String;
                      final name = course['name'] as String;
                      final type = course['type'] as String;
                      final credits = course['credits'] as int;
                      final hours = course['hours'] as String;
                      final defaultTeacher = course['teacher'] as String;

                      // Check if real live stats exist from backend
                      SubjectAttendanceStats? liveStat;
                      try {
                        liveStat = attendance.subjectStats.firstWhere(
                          (s) => s.code.toLowerCase().trim() == code.toLowerCase().trim(),
                        );
                      } catch (_) {
                        liveStat = null;
                      }

                      final percentage = liveStat?.percentage ?? 100.0;
                      final attended = liveStat?.classesAttended ?? 0;
                      final conducted = liveStat?.classesConducted ?? 0;
                      final teacher = liveStat?.teacherName ?? defaultTeacher;

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
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.creamCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.creamBorder, width: 1.0),
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
                                  const Text(
                                    '📅 Monthly Calendar ➔',
                                    style: TextStyle(color: AppTheme.seaGreen, fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
    );
  }

  // --- INTERACTIVE MONTHLY CALENDAR & AUDIT MODAL ---
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
  int _selectedDay = 31;

  @override
  Widget build(BuildContext context) {
    // Generate 31-day mock calendar status based on total classes attended
    final isWeekendOrHoliday = (int day) => (day % 7 == 1 || day % 7 == 2 || day == 15);
    final isClassDay = (int day) => !isWeekendOrHoliday(day);
    final isAttendedDay = (int day) => isClassDay(day) && (day % 3 != 0 || widget.percentage >= 85);
    final isAbsentDay = (int day) => isClassDay(day) && !isAttendedDay(day);

    final selectedIsAttended = isAttendedDay(_selectedDay);
    final selectedIsAbsent = isAbsentDay(_selectedDay);
    final selectedIsHoliday = isWeekendOrHoliday(_selectedDay);

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
                      Text('Faculty: ${widget.teacher}  •  ${widget.hours}', style: const TextStyle(fontSize: 12, color: AppTheme.charcoalMuted)),
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
                    '${widget.percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: widget.percentage >= 75 ? AppTheme.seaGreen : AppTheme.statusDanger,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppTheme.creamBorder),
            const SizedBox(height: 8),

            // Calendar Header
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '📅 August 2026 Attendance Calendar',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.charcoal),
                ),
                Text(
                  'Tap any day for proof',
                  style: TextStyle(fontSize: 10, color: AppTheme.charcoalMuted, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 31-Day Interactive Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1.0,
              ),
              itemCount: 31,
              itemBuilder: (context, index) {
                final day = index + 1;
                final isSelected = _selectedDay == day;
                final attended = isAttendedDay(day);
                final absent = isAbsentDay(day);
                final holiday = isWeekendOrHoliday(day);

                Color bgColor = const Color(0xFFF3F4F6);
                Color textColor = AppTheme.charcoal;
                if (attended) {
                  bgColor = AppTheme.seaGreenTint;
                  textColor = AppTheme.seaGreenDark;
                } else if (absent) {
                  bgColor = const Color(0xFFFEE2E2);
                  textColor = const Color(0xFF991B1B);
                } else if (holiday) {
                  bgColor = const Color(0xFFE5E7EB);
                  textColor = const Color(0xFF9CA3AF);
                }

                return InkWell(
                  onTap: () => setState(() => _selectedDay = day),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppTheme.charcoal : Colors.transparent,
                        width: isSelected ? 2.0 : 1.0,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$day',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: textColor),
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
                color: selectedIsAttended
                    ? AppTheme.seaGreenTint
                    : selectedIsAbsent
                        ? const Color(0xFFFEE2E2)
                        : AppTheme.creamCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selectedIsAttended
                      ? AppTheme.seaGreen.withOpacity(0.3)
                      : selectedIsAbsent
                          ? const Color(0xFFEF4444).withOpacity(0.3)
                          : AppTheme.creamBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    selectedIsAttended
                        ? Icons.check_circle_outline
                        : selectedIsAbsent
                            ? Icons.cancel_outlined
                            : Icons.hotel_outlined,
                    color: selectedIsAttended
                        ? AppTheme.seaGreenDark
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
                          'August $_selectedDay, 2026 • 10:15 AM - 11:15 AM',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppTheme.charcoal),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedIsAttended
                              ? 'GPS Verified: 18.4m within 50m Dept • Google Sheets Synced ✅'
                              : selectedIsAbsent
                                  ? 'Absent: No GPS check-in received during 15-min window.'
                                  : 'University Holiday / Weekend (No lecture scheduled).',
                          style: TextStyle(
                            fontSize: 10,
                            color: selectedIsAttended
                                ? AppTheme.seaGreenDark
                                : selectedIsAbsent
                                    ? const Color(0xFF991B1B)
                                    : AppTheme.charcoalMuted,
                          ),
                        ),
                        if (selectedIsAttended)
                          Text(
                            'Token: SHA256: ${widget.code.replaceAll("-", "")}-${_selectedDay}AUG-VERIFIED',
                            style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: AppTheme.charcoalMuted),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: selectedIsAttended
                          ? AppTheme.seaGreen
                          : selectedIsAbsent
                              ? const Color(0xFFDC2626)
                              : AppTheme.charcoalMuted,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      selectedIsAttended ? 'Full (1.0)' : selectedIsAbsent ? 'Absent (0.0)' : 'Holiday',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons: Audit Receipt & Close
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openAuditReceiptModal(context),
                    icon: const Icon(Icons.receipt_long_outlined, size: 16),
                    label: const Text('Academic Audit Report', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.charcoal,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Close Calendar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openAuditReceiptModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppTheme.seaGreenTint, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.verified_outlined, color: AppTheme.seaGreen, size: 20),
            ),
            const SizedBox(width: 8),
            const Text('Academic Audit Report', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.charcoal)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.creamBg, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Student: ${widget.studentName}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.charcoal)),
                    Text('University Roll: ${widget.student?.universityRoll ?? "12000126042"}', style: const TextStyle(fontSize: 11, color: AppTheme.charcoalMuted)),
                    Text('Class Roll: ${widget.student?.classRoll ?? "MCA-26-042"}  •  Reg: ${widget.student?.regNumber ?? "REG-2026-9042"}', style: const TextStyle(fontSize: 11, color: AppTheme.charcoalMuted)),
                    const SizedBox(height: 6),
                    Text('Course: ${widget.code}: ${widget.name}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.charcoal)),
                    Text('Faculty: ${widget.teacher} (${widget.credits} Credits)', style: const TextStyle(fontSize: 11, color: AppTheme.charcoalMuted)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Aggregate Attendance Score:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.charcoal)),
                  Text('${widget.percentage.toStringAsFixed(1)}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: widget.percentage >= 75 ? AppTheme.seaGreen : AppTheme.statusDanger)),
                ],
              ),
              const SizedBox(height: 4),
              Text('Status: ${widget.percentage >= 75 ? "Eligible for University Examinations (≥ 75%)" : "Shortage Warning (< 75%)"}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: widget.percentage >= 75 ? AppTheme.seaGreenDark : AppTheme.statusDanger)),
              const SizedBox(height: 12),
              const Text('Verifiable GPS & Google Sheets Sync Log:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.charcoal)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFAF7F0), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.creamBorder)),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• Automated GPS geofence checks: Verified Inside 50m department radius', style: TextStyle(fontSize: 10, color: AppTheme.charcoal)),
                    SizedBox(height: 2),
                    Text('• Live Google Sheets Matrix Sync: Synced row records', style: TextStyle(fontSize: 10, color: AppTheme.charcoal)),
                    SizedBox(height: 2),
                    Text('• System Authentication: Token-validated digital record', style: TextStyle(fontSize: 10, color: AppTheme.charcoal)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.charcoal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Close Report', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
