import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../../core/theme/app_theme.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final attendance = Provider.of<AttendanceProvider>(context, listen: false);
      attendance.fetchStudentDashboard();
      attendance.fetchStudentActiveSessions();
    });
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
                    // Charcoal Student Header Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.charcoal,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                auth.currentUser?.name ?? 'Student',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.seaGreen,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Sem ${student?.semester ?? 5}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Class Roll: ${student?.classRoll ?? "-"}  •  Uni Roll: ${student?.universityRoll ?? "-"}',
                            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Registration No: ${student?.regNumber ?? "-"}',
                            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Active 15-Minute Session Notification (Sea Green / Charcoal)
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
                                      session.isAlreadyMarked ? 'Attendance Recorded' : 'Live Attendance Session',
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

                    // Minimalist Aggregate Attendance Dial Card
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
                            radius: 48.0,
                            lineWidth: 8.0,
                            animation: true,
                            percent: ((stats?.overallPercentage ?? 100.0) / 100).clamp(0.0, 1.0),
                            center: Text(
                              "${stats?.overallPercentage.toStringAsFixed(1) ?? '100'}%",
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
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
                                'Aggregate Attendance',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.charcoal),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Classes: ${stats?.totalClassesAttended ?? 0} / ${stats?.totalClassesConducted ?? 0}',
                                style: const TextStyle(color: AppTheme.charcoalMuted, fontSize: 13),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(stats?.overallPercentage ?? 100.0).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  stats?.statusCategory ?? 'Safe',
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
                    const SizedBox(height: 22),

                    // Semester Subjects Section
                    const Text(
                      'Enrolled Subjects',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.charcoal,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (attendance.subjectStats.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            'No registered subjects found.',
                            style: TextStyle(color: AppTheme.charcoalMuted),
                          ),
                        ),
                      )
                    else
                      ...attendance.subjectStats.map((sub) {
                        final isPractical = sub.type == 'Practical';
                        final isBridge = sub.type == 'Bridge Course';
                        final isProject = sub.type == 'Project';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.creamCard,
                            borderRadius: BorderRadius.circular(12),
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
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1EDE4),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                sub.code,
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppTheme.charcoal),
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
                                                        : isProject
                                                            ? const Color(0xFFEDE9FE)
                                                            : const Color(0xFFF3F4F6),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                sub.type,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 10,
                                                  color: isPractical
                                                      ? AppTheme.seaGreenDark
                                                      : isBridge
                                                          ? const Color(0xFF92400E)
                                                          : isProject
                                                              ? const Color(0xFF5B21B6)
                                                              : AppTheme.charcoalMuted,
                                                ),
                                              ),
                                            ),
                                            if (sub.credits > 0) ...[
                                              const SizedBox(width: 6),
                                              Text(
                                                '${sub.credits} Credits',
                                                style: const TextStyle(color: AppTheme.charcoalLight, fontSize: 11),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          sub.name,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.charcoal),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${sub.percentage.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: _getStatusColor(sub.percentage),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Faculty: ${sub.teacherName}${sub.weeklyHours != null ? "  •  Weekly: ${sub.weeklyHours}" : ""}',
                                style: const TextStyle(color: AppTheme.charcoalMuted, fontSize: 11),
                              ),
                              const SizedBox(height: 10),
                              LinearPercentIndicator(
                                lineHeight: 5.0,
                                percent: (sub.percentage / 100).clamp(0.0, 1.0),
                                progressColor: _getStatusColor(sub.percentage),
                                backgroundColor: const Color(0xFFF1EDE4),
                                barRadius: const Radius.circular(3),
                                padding: EdgeInsets.zero,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${sub.classesAttended} / ${sub.classesConducted} classes attended',
                                style: const TextStyle(color: AppTheme.charcoalLight, fontSize: 11),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }
}
