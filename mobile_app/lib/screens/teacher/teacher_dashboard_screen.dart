import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';
import '../../models/attendance_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../auth/login_screen.dart';
import 'manage_sheets_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  int _selectedSemester = 3;
  String? _selectedCourseCode = 'MCA-301';
  String? _selectedCourseName = 'Artificial Intelligence';

  bool _isSessionActive = false;
  String? _activeSessionId;
  int _countdownSeconds = 900; // 15 mins
  Timer? _sessionTimer;

  // Session limits (Max 3 per day)
  final Map<String, int> _sessionCountsByCourse = {};

  // Real roster & attendance state
  List<Map<String, dynamic>> _rosterStudents = [];
  bool _isLoadingRoster = false;
  final Map<String, String> _attendanceStatusByUniRoll = {}; // 'P', 'H', or null

  // Google Sheet integration
  final TextEditingController _sheetIdController = TextEditingController();
  bool _isSheetConnected = false;
  String? _sheetTestResult;
  bool _isTestingSheet = false;
  static const String _serviceAccountEmail = 'attendance-sync-sa@smart-attendance-system.iam.gserviceaccount.com';

  // Complete MCA Curriculum Directory (31 Courses across all 4 Semesters)
  static const Map<int, List<Map<String, String>>> _curriculum = {
    1: [
      {'code': 'MCA-101', 'name': 'Mathematical Foundation'},
      {'code': 'MCA-102', 'name': 'Data and File Structures'},
      {'code': 'MCA-103', 'name': 'Computer Organization & Arch'},
      {'code': 'MCA-104', 'name': 'Microprocessor & Applications'},
      {'code': 'MCA-105', 'name': 'Management Functions'},
      {'code': 'MCA-111', 'name': 'Communicative English Lab'},
      {'code': 'MCA-112', 'name': 'DFS Lab with C'},
      {'code': 'MCA-113', 'name': 'Digital Circuits Lab'},
      {'code': 'MCA-114', 'name': 'Microprocessor Lab'},
      {'code': 'MCA-141*', 'name': 'Intro to Computing & C (Bridge)'},
    ],
    2: [
      {'code': 'MCA-201', 'name': 'Design & Analysis of Algorithms'},
      {'code': 'MCA-202', 'name': 'Object Oriented Programming'},
      {'code': 'MCA-203', 'name': 'Database Management Systems'},
      {'code': 'MCA-204', 'name': 'Operating Systems'},
      {'code': 'MCA-205', 'name': 'Scientific Computing'},
      {'code': 'MCA-211', 'name': 'OOP Laboratory'},
      {'code': 'MCA-212', 'name': 'DBMS Laboratory'},
      {'code': 'MCA-213', 'name': 'Scientific Computing Lab'},
      {'code': 'MCA-214', 'name': 'Advanced Programming Lab–I'},
    ],
    3: [
      {'code': 'MCA-301', 'name': 'Artificial Intelligence'},
      {'code': 'MCA-302', 'name': 'Computer Networks'},
      {'code': 'MCA-303', 'name': 'Software Engineering'},
      {'code': 'MCA-304', 'name': 'Elective – I (Cloud / ML)'},
      {'code': 'MCA-305', 'name': 'Elective – II (Cyber Security)'},
      {'code': 'MCA-306', 'name': 'Elective – III (Mobile Computing)'},
      {'code': 'MCA-311', 'name': 'AI Laboratory'},
      {'code': 'MCA-312', 'name': 'Web-based Programming Lab'},
      {'code': 'MCA-313', 'name': 'Advanced Programming Lab-II'},
      {'code': 'MCA-321', 'name': 'Minor Project–I'},
    ],
    4: [
      {'code': 'MCA-421', 'name': 'Major Capstone Project–II'},
      {'code': 'MCA-431', 'name': 'Grand Viva Voce'},
    ],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final attendance = Provider.of<AttendanceProvider>(context, listen: false);
      attendance.connectRealTimeStream();
      _loadStudentsForSemester(_selectedSemester);
      _fetchTodayCheckIns();
    });
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _sheetIdController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentsForSemester(int semester) async {
    setState(() => _isLoadingRoster = true);
    try {
      final res = await ApiService.getStudentsBySemester(semester);
      if (res['students'] != null && mounted) {
        setState(() {
          _rosterStudents = List<Map<String, dynamic>>.from(res['students']);
          _isLoadingRoster = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingRoster = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRoster = false);
    }
  }

  Future<void> _fetchTodayCheckIns() async {
    if (_selectedCourseCode == null) return;
    final attendance = Provider.of<AttendanceProvider>(context, listen: false);
    await attendance.fetchTeacherAttendance(_selectedCourseCode!);
    if (mounted) {
      for (final rec in attendance.liveTeacherCheckIns) {
        _attendanceStatusByUniRoll[rec.universityRoll] = (rec.status == 'Half') ? 'H' : 'P';
      }
      setState(() {});
    }
  }

  void _onSemesterChanged(int newSem) {
    setState(() {
      _selectedSemester = newSem;
      final courses = _curriculum[newSem] ?? [];
      if (courses.isNotEmpty) {
        _selectedCourseCode = courses[0]['code'];
        _selectedCourseName = courses[0]['name'];
      }
    });
    _loadStudentsForSemester(newSem);
    _fetchTodayCheckIns();
  }

  Future<void> _handleStartSession() async {
    if (_selectedCourseCode == null) return;

    final count = _sessionCountsByCourse[_selectedCourseCode!] ?? 0;
    if (count >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Maximum limit reached (3/3 sessions conducted today for $_selectedCourseCode).'),
          backgroundColor: AppTheme.statusDanger,
        ),
      );
      return;
    }

    final attendance = Provider.of<AttendanceProvider>(context, listen: false);
    final success = await attendance.startSession(_selectedCourseCode!, durationMinutes: 15);

    if (success && mounted) {
      _sessionTimer?.cancel();
      setState(() {
        _isSessionActive = true;
        _countdownSeconds = 900;
        _sessionCountsByCourse[_selectedCourseCode!] = count + 1;
      });

      _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_countdownSeconds > 0) {
          if (mounted) setState(() => _countdownSeconds--);
        } else {
          _sessionTimer?.cancel();
          if (mounted) setState(() => _isSessionActive = false);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚡ 15-Min Live Session started for $_selectedCourseCode: $_selectedCourseName! Geofence broadcasted to all students.'),
          backgroundColor: AppTheme.seaGreen,
        ),
      );
    }
  }

  Future<void> _handleStopSession() async {
    _sessionTimer?.cancel();
    final attendance = Provider.of<AttendanceProvider>(context, listen: false);
    if (_activeSessionId != null) {
      await attendance.closeSession(_activeSessionId!);
    }
    setState(() {
      _isSessionActive = false;
      _countdownSeconds = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attendance session closed.'), backgroundColor: AppTheme.charcoal),
    );
  }

  Future<void> _handleGrantHalf(Map<String, dynamic> student) async {
    final uniRoll = student['universityRoll'] ?? '';
    final studentId = student['id'] ?? '';
    final studentName = student['name'] ?? 'Student';

    setState(() {
      _attendanceStatusByUniRoll[uniRoll] = 'H';
    });

    final attendance = Provider.of<AttendanceProvider>(context, listen: false);
    if (_selectedCourseCode != null) {
      await attendance.grantHalfAttendance(_selectedCourseCode!, studentId);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏱️ Half attendance (+1 count) granted for $studentName ($uniRoll).'),
          backgroundColor: const Color(0xFFD97706),
        ),
      );
    }
  }

  Future<void> _testGoogleSheet() async {
    final sheetId = _sheetIdController.text.trim();
    if (sheetId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste a Google Spreadsheet ID first.')),
      );
      return;
    }

    setState(() {
      _isTestingSheet = true;
      _sheetTestResult = null;
    });

    try {
      final res = await ApiService.testSheetConnection(sheetId);
      setState(() {
        _isTestingSheet = false;
        _isSheetConnected = res['connected'] == true;
        _sheetTestResult = res['message'] ?? (res['connected'] == true ? 'Connected successfully!' : 'Connection failed.');
      });
    } catch (e) {
      setState(() {
        _isTestingSheet = false;
        _sheetTestResult = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final attendance = Provider.of<AttendanceProvider>(context);

    final courses = _curriculum[_selectedSemester] ?? [];
    final currentCount = _sessionCountsByCourse[_selectedCourseCode ?? ''] ?? 0;

    final minutes = _countdownSeconds ~/ 60;
    final seconds = _countdownSeconds % 60;
    final timerString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final presentCount = _rosterStudents.where((s) => _attendanceStatusByUniRoll[s['universityRoll']] != null).length;
    final absentStudents = _rosterStudents.where((s) => _attendanceStatusByUniRoll[s['universityRoll']] == null).toList();

    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      appBar: AppBar(
        title: const Row(
          children: [
            Text('AutoAttend', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            SizedBox(width: 6),
            Text('• Faculty Console', style: TextStyle(color: AppTheme.seaGreen, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined, size: 20, color: AppTheme.charcoal),
            tooltip: 'Refresh All Data',
            onPressed: () {
              _loadStudentsForSemester(_selectedSemester);
              _fetchTodayCheckIns();
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
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. TOP WELCOME & BADGES BANNER
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.charcoal,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: AppTheme.seaGreen, borderRadius: BorderRadius.circular(6)),
                              child: const Text('FACULTY CONSOLE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                              child: Text('$_selectedCourseCode', style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 9, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            if (_selectedCourseCode != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ManageSheetsScreen(
                                    subjectId: _selectedCourseCode!,
                                    subjectName: _selectedCourseName ?? 'Subject',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.table_chart_outlined, size: 14, color: Colors.white),
                          label: const Text('Sheets', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white30),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      auth.currentUser?.name ?? 'Faculty Member',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      auth.currentUser?.email ?? 'faculty@college.edu',
                      style: const TextStyle(color: Colors.white60, fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. ATTENDANCE SESSION LAUNCHER CARD
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.creamBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '⚡ Attendance Session Launcher',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.charcoal),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F0),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.creamBorder),
                          ),
                          child: Text(
                            'Sessions: $currentCount / 3',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.seaGreenDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Broadcasts real-time 15-minute GPS attendance window to student mobile apps.',
                      style: TextStyle(color: AppTheme.charcoalMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 12),

                    // Semester Selector Chips
                    const Text('1. SELECT SEMESTER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.charcoalMuted)),
                    const SizedBox(height: 6),
                    Row(
                      children: [1, 2, 3, 4].map((sem) {
                        final isSelected = _selectedSemester == sem;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: InkWell(
                              onTap: _isSessionActive ? null : () => _onSemesterChanged(sem),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.charcoal : const Color(0xFFFAF7F0),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isSelected ? AppTheme.charcoal : AppTheme.creamBorder),
                                ),
                                child: Center(
                                  child: Text(
                                    'Sem $sem',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected ? Colors.white : AppTheme.charcoal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Subject Dropdown
                    const Text('2. SELECT SUBJECT / LECTURE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.charcoalMuted)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedCourseCode,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.charcoal),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: courses.map((c) {
                        return DropdownMenuItem<String>(
                          value: c['code'],
                          child: Text('${c['code']}: ${c['name']}', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: _isSessionActive
                          ? null
                          : (val) {
                              if (val != null) {
                                final matched = courses.firstWhere((c) => c['code'] == val);
                                setState(() {
                                  _selectedCourseCode = val;
                                  _selectedCourseName = matched['name'];
                                });
                                _fetchTodayCheckIns();
                              }
                            },
                    ),
                    const SizedBox(height: 14),

                    // Start / Stop Button
                    ElevatedButton.icon(
                      onPressed: _isSessionActive
                          ? _handleStopSession
                          : (attendance.isLoading || currentCount >= 3 ? null : _handleStartSession),
                      icon: Icon(_isSessionActive ? Icons.stop_circle_outlined : Icons.play_arrow_outlined, size: 18),
                      label: Text(
                        _isSessionActive
                            ? 'Stop Session ($timerString)'
                            : (currentCount >= 3 ? 'Max Daily Limit (3/3 Done)' : 'Start 15-Min Session'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSessionActive
                            ? const Color(0xFFDC2626)
                            : (currentCount >= 3 ? const Color(0xFF9CA3AF) : AppTheme.seaGreen),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                    // Active Session Pulsing Banner
                    if (_isSessionActive) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.seaGreenTint,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.seaGreen.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.seaGreen),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Broadcasting 50m geofence for $_selectedCourseCode • $timerString remaining',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.seaGreenDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. LIVE MATRIX GOOGLE SHEET MIRROR TABLE
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.creamBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '📊 Live Matrix Google Sheet Mirror',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.charcoal),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.seaGreenTint,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Checked In: $presentCount / ${_rosterStudents.length}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.seaGreenDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'P = Present (Full) • H = Half (Override) • — = Absent',
                      style: TextStyle(fontSize: 10, color: AppTheme.charcoalMuted, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),

                    if (_isLoadingRoster)
                      const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                    else if (_rosterStudents.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF7F0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            '🌱 No registered students found for this semester.\nStudents will populate automatically as they register on the mobile app.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: AppTheme.charcoalMuted),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _rosterStudents.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.creamBorder),
                        itemBuilder: (context, index) {
                          final s = _rosterStudents[index];
                          final uniRoll = s['universityRoll'] ?? '';
                          final classRoll = s['classRoll'] ?? '';
                          final name = s['name'] ?? 'Student';
                          final status = _attendanceStatusByUniRoll[uniRoll];

                          Color statusBg = const Color(0xFFF3F4F6);
                          Color statusText = const Color(0xFF9CA3AF);
                          String statusLabel = '—';

                          if (status == 'P') {
                            statusBg = AppTheme.seaGreenTint;
                            statusText = AppTheme.seaGreenDark;
                            statusLabel = 'P';
                          } else if (status == 'H') {
                            statusBg = const Color(0xFFFEF3C7);
                            statusText = const Color(0xFFB45309);
                            statusLabel = 'H';
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAF7F0),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppTheme.creamBorder),
                                  ),
                                  child: Text(
                                    classRoll,
                                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 10, color: AppTheme.charcoal),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.charcoal)),
                                      Text('Uni: $uniRoll', style: const TextStyle(color: AppTheme.charcoalMuted, fontSize: 10)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: statusText),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. LATE COMERS MANUAL OVERRIDE SECTION
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.creamBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('⏱️', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 6),
                        Text(
                          'Late Comers Manual Override (Half Attendance)',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppTheme.charcoal),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Students who missed the 15-min cutoff. Tap "Grant Half (+1)" to log "H" into their Google Sheet cell.',
                      style: TextStyle(color: AppTheme.charcoalMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 10),

                    if (absentStudents.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.seaGreenTint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            '🎉 All students have recorded attendance or been processed.',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.seaGreenDark),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: absentStudents.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final s = absentStudents[index];
                          final name = s['name'] ?? 'Student';
                          final classRoll = s['classRoll'] ?? '';
                          final uniRoll = s['universityRoll'] ?? '';

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF7F0),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.creamBorder),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppTheme.charcoal)),
                                      Text('Roll: $classRoll • Uni: $uniRoll', style: const TextStyle(fontSize: 10, color: AppTheme.charcoalMuted)),
                                    ],
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _handleGrantHalf(s),
                                  icon: const Icon(Icons.timer_outlined, size: 14),
                                  label: const Text('Grant Half (+1)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.charcoal,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    minimumSize: Size.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 5. GOOGLE SHEET CONNECTION CARD
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.creamBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Text('📑', style: TextStyle(fontSize: 16)),
                            SizedBox(width: 6),
                            Text('Google Sheet Connection', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.charcoal)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _isSheetConnected ? AppTheme.seaGreenTint : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _isSheetConnected ? '✅ Connected' : '⚠️ Not Connected',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _isSheetConnected ? AppTheme.seaGreenDark : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Service Account Email
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F0),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.creamBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Service Account Email:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.charcoalMuted)),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(const ClipboardData(text: _serviceAccountEmail));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Service Account Email copied!')),
                                  );
                                },
                                child: const Text('Copy Email 📋', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.seaGreen)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            _serviceAccountEmail,
                            style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.charcoal),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Spreadsheet ID Input
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _sheetIdController,
                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                            decoration: const InputDecoration(
                              hintText: 'Paste Google Spreadsheet ID here',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isTestingSheet ? null : _testGoogleSheet,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.seaGreen,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _isTestingSheet
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('🔍 Test', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),

                    if (_sheetTestResult != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _isSheetConnected ? AppTheme.seaGreenTint : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _sheetTestResult!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _isSheetConnected ? AppTheme.seaGreenDark : const Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
