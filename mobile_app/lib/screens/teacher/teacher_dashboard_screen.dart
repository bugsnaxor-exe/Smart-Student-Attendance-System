import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../auth/login_screen.dart';
import 'manual_override_screen.dart';
import 'manage_sheets_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  String? _selectedSubjectId;
  String? _selectedSubjectName;
  bool _isSessionActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final attendance = Provider.of<AttendanceProvider>(context, listen: false);
      attendance.connectRealTimeStream();

      final subjects = auth.currentUser?.teacher?.subjects;
      if (subjects != null && subjects.isNotEmpty) {
        setState(() {
          _selectedSubjectId = subjects[0]['id'];
          _selectedSubjectName = subjects[0]['name'];
        });
        attendance.fetchTeacherAttendance(_selectedSubjectId!);
      }
    });
  }

  void _handleStartSession() async {
    if (_selectedSubjectId == null) return;
    final attendance = Provider.of<AttendanceProvider>(context, listen: false);

    final success = await attendance.startSession(_selectedSubjectId!, durationMinutes: 15);
    if (success && mounted) {
      setState(() => _isSessionActive = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('15-Minute Attendance Session is LIVE for students.'),
          backgroundColor: AppTheme.seaGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final attendance = Provider.of<AttendanceProvider>(context);
    final subjects = auth.currentUser?.teacher?.subjects ?? [];

    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      appBar: AppBar(
        title: const Text('Faculty Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_outlined, size: 20, color: AppTheme.charcoal),
            tooltip: 'Google Sheets Setup',
            onPressed: () {
              if (_selectedSubjectId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ManageSheetsScreen(
                      subjectId: _selectedSubjectId!,
                      subjectName: _selectedSubjectName ?? 'Subject',
                    ),
                  ),
                );
              }
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Teacher Greeting Header
              Text(
                'Welcome, ${auth.currentUser?.name ?? "Professor"}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.charcoal,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Manage lecture sessions and monitor live student check-ins.',
                style: TextStyle(color: AppTheme.charcoalMuted, fontSize: 13),
              ),
              const SizedBox(height: 18),

              // Subject Dropdown
              if (subjects.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedSubjectId,
                  style: const TextStyle(color: AppTheme.charcoal, fontSize: 14),
                  dropdownColor: AppTheme.creamCard,
                  decoration: const InputDecoration(
                    labelText: 'Active Subject',
                    prefixIcon: Icon(Icons.book_outlined, color: AppTheme.charcoalMuted, size: 20),
                  ),
                  items: subjects.map<DropdownMenuItem<String>>((sub) {
                    return DropdownMenuItem<String>(
                      value: sub['id'],
                      child: Text('${sub['name']} (${sub['code']} - Sem ${sub['semester']})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final chosen = subjects.firstWhere((s) => s['id'] == val);
                      setState(() {
                        _selectedSubjectId = val;
                        _selectedSubjectName = chosen['name'];
                      });
                      attendance.fetchTeacherAttendance(val);
                    }
                  },
                ),
              const SizedBox(height: 14),

              // Session Control Minimalist Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.creamCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.creamBorder, width: 1.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '15-Minute Attendance Window',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.charcoal),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: _isSessionActive ? AppTheme.seaGreenTint : const Color(0xFFF1EDE4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _isSessionActive ? 'ACTIVE' : 'IDLE',
                            style: TextStyle(
                              color: _isSessionActive ? AppTheme.seaGreenDark : AppTheme.charcoalMuted,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Opens a 15-minute countdown for students inside the 50m department radius. Closes automatically.',
                      style: TextStyle(color: AppTheme.charcoalMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: attendance.isLoading ? null : _handleStartSession,
                      icon: const Icon(Icons.play_arrow_outlined, size: 18),
                      label: const Text('Start 15-Min Session'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.seaGreen,
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Quick Actions Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (_selectedSubjectId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ManualOverrideScreen(
                                subjectId: _selectedSubjectId!,
                                subjectName: _selectedSubjectName ?? 'Subject',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.person_add_disabled_outlined, size: 16),
                      label: const Text('Grant Half (Late)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (_selectedSubjectId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ManageSheetsScreen(
                                subjectId: _selectedSubjectId!,
                                subjectName: _selectedSubjectName ?? 'Subject',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.table_view_outlined, size: 16),
                      label: const Text('Google Sheet'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Live Check-ins Feed Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recorded Check-Ins (${attendance.liveTeacherCheckIns.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.charcoal,
                      letterSpacing: -0.2,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18, color: AppTheme.charcoalMuted),
                    onPressed: () {
                      if (_selectedSubjectId != null) {
                        attendance.fetchTeacherAttendance(_selectedSubjectId!);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Check-ins List
              if (attendance.liveTeacherCheckIns.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppTheme.creamCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.creamBorder, width: 1.0),
                  ),
                  child: const Center(
                    child: Text(
                      'No check-ins recorded yet for today.\nStart a session to accept attendance.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.charcoalMuted, fontSize: 13),
                    ),
                  ),
                )
              else
                ...attendance.liveTeacherCheckIns.map((record) {
                  final isFull = record.status == 'Full';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.creamCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.creamBorder, width: 1.0),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isFull ? AppTheme.seaGreenTint : const Color(0xFFFEF3C7),
                          child: Text(
                            record.studentName.isNotEmpty ? record.studentName[0] : 'S',
                            style: TextStyle(
                              color: isFull ? AppTheme.seaGreenDark : const Color(0xFFB45309),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record.studentName,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.charcoal),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'Roll: ${record.classRoll}  •  Uni: ${record.universityRoll}',
                                style: const TextStyle(color: AppTheme.charcoalMuted, fontSize: 11),
                              ),
                              Text(
                                'Reg: ${record.regNumber}',
                                style: const TextStyle(color: AppTheme.charcoalLight, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: isFull ? AppTheme.seaGreenTint : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                record.status,
                                style: TextStyle(
                                  color: isFull ? AppTheme.seaGreenDark : const Color(0xFFB45309),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              record.time,
                              style: const TextStyle(color: AppTheme.charcoalLight, fontSize: 11),
                            ),
                          ],
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
