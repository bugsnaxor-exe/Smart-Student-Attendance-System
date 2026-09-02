import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';
import '../../models/attendance_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../auth/login_screen.dart';

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
  Timer? _syncTimer;

  // Teacher Detected Location
  double? _detectedLatitude;
  double? _detectedLongitude;
  double? _detectedAccuracy;
  bool _isDetectingLocation = false;

  // Session limits (Max 3 per day)
  final Map<String, int> _sessionCountsByCourse = {};
  bool _isStartingSession = false;

  // Real roster & attendance state
  List<Map<String, dynamic>> _rosterStudents = [];
  bool _isLoadingRoster = false;
  final Map<String, String> _attendanceStatusByUniRoll = {}; // 'P', 'H', or null

  // Google Sheet integration
  final TextEditingController _sheetIdController = TextEditingController();
  bool _isSheetConnected = true;
  String _linkedSheetId = '1KN_lGqkfzE7CBdiceE8VEnEQ-37vsuGFz2jTvRhsPFk';
  String? _sheetTestResult;
  bool _isTestingSheet = false;
  static const String _serviceAccountEmail = 'attendance-sync@total-byte-507113-g0.iam.gserviceaccount.com';

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
    _sheetIdController.text = _linkedSheetId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final attendance = Provider.of<AttendanceProvider>(context, listen: false);
      attendance.connectRealTimeStream();
      _fetchActiveSheetFromBackend();
      _loadStudentsForSemester(_selectedSemester);
      _fetchTodaySessionCounts();
      _fetchTodayCheckIns();
      _checkOngoingSession();
    });

    _syncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        _fetchTodaySessionCounts();
        _fetchTodayCheckIns();
        _checkOngoingSession();
      }
    });
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _syncTimer?.cancel();
    _sheetIdController.dispose();
    super.dispose();
  }

  Future<void> _fetchActiveSheetFromBackend() async {
    try {
      final res = await ApiService.getActiveSheet();
      if (res != null && mounted) {
        final id = res['googleSheetId'] as String?;
        if (id != null && id.isNotEmpty) {
          setState(() {
            _linkedSheetId = id;
            _sheetIdController.text = id;
            _isSheetConnected = true;
          });
        }
      }
    } catch (e) {
      // Keep default linked sheet
    }
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
      setState(() {
        _attendanceStatusByUniRoll.clear();
        for (final rec in attendance.liveTeacherCheckIns) {
          if (rec.universityRoll.isNotEmpty) {
            _attendanceStatusByUniRoll[rec.universityRoll] = (rec.status == 'Half') ? 'H' : 'P';
          }
          if (rec.classRoll.isNotEmpty) {
            _attendanceStatusByUniRoll[rec.classRoll] = (rec.status == 'Half') ? 'H' : 'P';
          }
        }
      });
    }
  }

  Future<void> _fetchTodaySessionCounts() async {
    try {
      final res = await ApiService.getTodaySessionCounts();
      if (res['counts'] != null && mounted) {
        final Map<String, dynamic> rawCounts = res['counts'];
        setState(() {
          rawCounts.forEach((key, value) {
            _sessionCountsByCourse[key] = (value as num).toInt();
          });
        });
      }
    } catch (e) {
      // Ignore network errors on background fetch
    }
  }

  Future<void> _checkOngoingSession() async {
    if (_selectedCourseCode == null) return;
    final attendance = Provider.of<AttendanceProvider>(context, listen: false);
    final res = await attendance.checkActiveTeacherSession(_selectedCourseCode!);
    if (res != null && res['sessionsConductedToday'] != null && mounted) {
      setState(() {
        _sessionCountsByCourse[_selectedCourseCode!] = (res['sessionsConductedToday'] as num).toInt();
      });
    }
    if (res != null && res['isActive'] == true && res['session'] != null && mounted) {
      final sess = res['session'];
      final remaining = (res['remainingSeconds'] as num?)?.toInt() ?? 900;
      final newSessionId = sess['id'];

      // If active session ID changed, reset the check-in status map for this new session
      if (_activeSessionId != newSessionId) {
        _attendanceStatusByUniRoll.clear();
        _activeSessionId = newSessionId;
        if (sess['attendances'] != null) {
          for (final a in (sess['attendances'] as List)) {
            final st = a['student'];
            final uRoll = st?['universityRoll'] ?? '';
            final cRoll = st?['classRoll'] ?? '';
            final statusStr = a['status'] == 'Half' ? 'H' : 'P';
            if (uRoll.isNotEmpty) _attendanceStatusByUniRoll[uRoll] = statusStr;
            if (cRoll.isNotEmpty) _attendanceStatusByUniRoll[cRoll] = statusStr;
          }
        }
      }

      if (!_isSessionActive || _countdownSeconds == 0) {
        setState(() {
          _isSessionActive = true;
          _countdownSeconds = remaining;
        });
        _sessionTimer?.cancel();
        _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_countdownSeconds > 0) {
            if (mounted) setState(() => _countdownSeconds--);
          } else {
            _sessionTimer?.cancel();
            if (mounted) setState(() => _isSessionActive = false);
          }
        });
      }
    } else if (_isSessionActive && attendance.teacherActiveSession == null && mounted) {
      _sessionTimer?.cancel();
      setState(() {
        _isSessionActive = false;
        _activeSessionId = null;
        _countdownSeconds = 0;
      });
    }
  }

  void _onSemesterChanged(int newSem) {
    if (_isSessionActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Session currently active for $_selectedCourseCode! Please stop the active session before switching semesters.'),
          backgroundColor: AppTheme.statusDanger,
        ),
      );
      return;
    }
    setState(() {
      _selectedSemester = newSem;
      _attendanceStatusByUniRoll.clear();
      final courses = _curriculum[newSem] ?? [];
      if (courses.isNotEmpty) {
        _selectedCourseCode = courses[0]['code'];
        _selectedCourseName = courses[0]['name'];
      }
    });
    _loadStudentsForSemester(newSem);
    _fetchTodaySessionCounts();
    _fetchTodayCheckIns();
    _checkOngoingSession();
  }

  Future<void> _handleStartSession() async {
    if (_selectedCourseCode == null || _isStartingSession) return;

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

    setState(() => _isStartingSession = true);
    final attendance = Provider.of<AttendanceProvider>(context, listen: false);

    try {
      // Auto-acquire high-accuracy GPS if not yet detected
      if (_detectedLatitude == null || _detectedLongitude == null) {
        await _detectLocation();
      }

      final success = await attendance.startSession(
        _selectedCourseCode!,
        durationMinutes: 15,
        latitude: _detectedLatitude,
        longitude: _detectedLongitude,
      );

      if (success && mounted) {
        _sessionTimer?.cancel();
        final sessionId = attendance.currentActiveSessionId;
        setState(() {
          _activeSessionId = sessionId;
          _isSessionActive = true;
          _countdownSeconds = 900;
          _sessionCountsByCourse[_selectedCourseCode!] = count + 1;
          // Clean slate for the new active session
          _attendanceStatusByUniRoll.clear();
        });

        // Refresh absent students for this fresh session
        await attendance.fetchAbsentStudents(_selectedCourseCode!, sessionId: sessionId);

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
    } finally {
      if (mounted) setState(() => _isStartingSession = false);
    }
  }

  Future<void> _handleStopSession() async {
    _sessionTimer?.cancel();
    final attendance = Provider.of<AttendanceProvider>(context, listen: false);
    final sId = _activeSessionId;
    final courseCode = _selectedCourseCode;
    setState(() {
      _isSessionActive = false;
      _activeSessionId = null;
      _countdownSeconds = 0;
    });
    await attendance.closeSession(sId, subjectId: courseCode);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance session closed.'), backgroundColor: AppTheme.charcoal),
      );
    }
  }

  Future<void> _handleGrantFull(Map<String, dynamic> student) async {
    final uniRoll = student['universityRoll'] ?? '';
    final studentId = student['id'] ?? '';
    final studentName = student['name'] ?? 'Student';

    setState(() {
      _attendanceStatusByUniRoll[uniRoll] = 'P';
    });

    final attendance = Provider.of<AttendanceProvider>(context, listen: false);
    if (_selectedCourseCode != null) {
      await attendance.grantFullAttendance(_selectedCourseCode!, studentId, sessionId: _activeSessionId);
      await _fetchTodayCheckIns();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Full attendance (P) granted for $studentName ($uniRoll). Synced with Google Sheets.'),
          backgroundColor: AppTheme.seaGreenDark,
        ),
      );
    }
  }

  Future<void> _handleGrantHalf(Map<String, dynamic> student) => _handleGrantFull(student);

  Future<void> _detectLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied.'), backgroundColor: AppTheme.statusDanger),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions permanently denied. Please enable in settings.'), backgroundColor: AppTheme.statusDanger),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _detectedLatitude = pos.latitude;
          _detectedLongitude = pos.longitude;
          _detectedAccuracy = pos.accuracy;
        });

        // If session is active, push update to backend
        if (_isSessionActive && _activeSessionId != null) {
          final attendance = Provider.of<AttendanceProvider>(context, listen: false);
          await attendance.updateSessionLocation(
            sessionId: _activeSessionId,
            subjectId: _selectedCourseCode,
            latitude: pos.latitude,
            longitude: pos.longitude,
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Location updated: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)} (±${pos.accuracy.toStringAsFixed(1)}m)'),
            backgroundColor: AppTheme.seaGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error detecting location: $e'), backgroundColor: AppTheme.statusDanger),
        );
      }
    }
  }

  void _openLocationSettingsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildLocationSettingsSheet(),
    );
  }

  Widget _buildLocationSettingsSheet() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return StatefulBuilder(
      builder: (context, setModalState) {
        final isCustomLoc = _detectedLatitude != null && _detectedLongitude != null;
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppTheme.creamBorder, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.seaGreenTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(child: Text('👨‍🏫', style: TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(auth.currentUser?.name ?? 'Faculty', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.charcoal)),
                        Text(auth.currentUser?.email ?? 'faculty@smartattend.edu', style: const TextStyle(fontSize: 11, color: AppTheme.charcoalMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isCustomLoc ? AppTheme.seaGreen : AppTheme.creamBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Text('📍 ', style: TextStyle(fontSize: 13)),
                            Text('Classroom Anchor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.charcoal)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isCustomLoc ? AppTheme.seaGreenTint : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isCustomLoc ? AppTheme.seaGreen : AppTheme.creamBorder),
                          ),
                          child: Text(
                            isCustomLoc ? '🛰️ Custom GPS' : '🏫 Campus Default',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isCustomLoc ? AppTheme.seaGreenDark : AppTheme.charcoalMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (isCustomLoc) ...[
                      Text('🎯 Coords: ${_detectedLatitude!.toStringAsFixed(5)}°, ${_detectedLongitude!.toStringAsFixed(5)}°', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.charcoal, fontFamily: 'monospace')),
                      const SizedBox(height: 2),
                      Text('Accuracy: ±${_detectedAccuracy?.toStringAsFixed(1) ?? "5.0"}m • Radius: 50m', style: const TextStyle(fontSize: 10, color: AppTheme.charcoalMuted)),
                    ] else ...[
                      const Text('Using Department Central Coordinates (50.0m Geofence Radius).', style: TextStyle(fontSize: 11, color: AppTheme.charcoalMuted)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isDetectingLocation
                    ? null
                    : () async {
                        setModalState(() => _isDetectingLocation = true);
                        await _detectLocation();
                        setModalState(() => _isDetectingLocation = false);
                        if (mounted) setState(() {});
                      },
                icon: _isDetectingLocation
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.my_location, size: 16),
                label: Text(_isDetectingLocation ? 'Acquiring GPS...' : 'Detect Current Location', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.seaGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _detectedLatitude = null;
                    _detectedLongitude = null;
                    _detectedAccuracy = null;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reset to Campus Default coordinates.')),
                  );
                },
                icon: const Icon(Icons.refresh, size: 14, color: AppTheme.charcoal),
                label: const Text('Reset to Campus Default', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.charcoal)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: AppTheme.creamBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openGoogleSheetSettingsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildSheetSettingsSheet(),
    );
  }

  Future<void> _openExportAuditReportModal() async {
    if (_rosterStudents.isEmpty) {
      await _loadStudentsForSemester(_selectedSemester);
    }
    await _fetchTodayCheckIns();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildAuditReportSheet(),
    );
  }

  Widget _buildSheetSettingsSheet() {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.creamBorder, borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Text('📑', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 8),
                    Text('Google Sheet Integration Settings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.charcoal)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Connect a Google Spreadsheet to mirror live student attendance and late overrides directly into your Google Drive.',
                  style: TextStyle(fontSize: 11, color: AppTheme.charcoalMuted),
                ),
                const SizedBox(height: 14),

                // Step 1: Service Account Email
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.creamBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('1. SHARE SHEET WITH SERVICE ACCOUNT:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.charcoalMuted)),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(const ClipboardData(text: _serviceAccountEmail));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service Account Email copied!')));
                            },
                            child: const Text('Copy Email 📋', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.seaGreen)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        _serviceAccountEmail,
                        style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w700, color: AppTheme.charcoal),
                      ),
                      const SizedBox(height: 4),
                      const Text('Give this email "Editor" permission in your Google Sheet share dialog.', style: TextStyle(fontSize: 10, color: AppTheme.charcoalMuted)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Step 2: Spreadsheet ID Input
                const Text('2. PASTE GOOGLE SPREADSHEET ID:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.charcoalMuted)),
                const SizedBox(height: 6),
                TextField(
                  controller: _sheetIdController,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: '1KN_lGqkfzE7CBdiceE8VEnEQ-37vsuGFz2jTvRhsPFk',
                    filled: true,
                    fillColor: const Color(0xFFFAF7F0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.creamBorder)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                // Test & Save Button
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isTestingSheet
                            ? null
                            : () async {
                                final id = _sheetIdController.text.trim();
                                if (id.isEmpty) return;
                                setSheetState(() => _isTestingSheet = true);
                                final res = await ApiService.testSheetConnection(id);
                                if (res['success'] == true) {
                                  await ApiService.linkGlobalSheet(id);
                                  setState(() {
                                    _linkedSheetId = id;
                                    _isSheetConnected = true;
                                  });
                                }
                                setSheetState(() {
                                  _isTestingSheet = false;
                                  _sheetTestResult = res['success'] == true
                                      ? '✅ Connected! Document: "${res['sheetTitle']}"'
                                      : '❌ ${res['error'] ?? 'Connection failed'}';
                                });
                              },
                        icon: _isTestingSheet
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_circle_outline, size: 16),
                        label: Text(_isTestingSheet ? 'Testing Connection...' : 'Save & Link Sheet', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.seaGreen,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),

                if (_sheetTestResult != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _sheetTestResult!.startsWith('✅') ? AppTheme.seaGreenTint : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _sheetTestResult!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _sheetTestResult!.startsWith('✅') ? AppTheme.seaGreenDark : const Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAuditReportSheet() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    int fullCount = 0;
    int halfCount = 0;
    for (final s in _rosterStudents) {
      final status = _attendanceStatusByUniRoll[s['universityRoll']];
      if (status == 'P') {
        fullCount++;
      } else if (status == 'H') {
        halfCount++;
      }
    }
    final int totalCount = _rosterStudents.length;
    final double totalWeighted = fullCount + (halfCount * 0.5);
    final pct = (totalCount > 0 && (fullCount + halfCount) > 0) ? ((totalWeighted / totalCount) * 100).toStringAsFixed(1) : '0.0';

    final todayStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.creamBorder, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),

          // Official Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('OFFICIAL ACADEMIC DOCUMENT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppTheme.seaGreenDark)),
                    const Text('DEPARTMENT OF MASTER OF COMPUTER APPLICATIONS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.charcoal)),
                    const Text('Verifiable Class-wise Attendance Audit Slip & Security Record', style: TextStyle(fontSize: 10, color: AppTheme.charcoalMuted)),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.seaGreenTint,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.seaGreen),
                ),
                child: const Center(child: Text('MCA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.seaGreenDark))),
              ),
            ],
          ),
          const Divider(height: 20, color: AppTheme.creamBorder),

          // Course Info Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.creamBorder),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Faculty: ${auth.currentUser?.name ?? "Sayantan Dasgupta"}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.charcoal)),
                    Text('Session 2026-2027', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.charcoalMuted)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Course: $_selectedCourseCode: $_selectedCourseName', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.charcoal)),
                    Text('Sem $_selectedSemester', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.seaGreenDark)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Score Summary Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.seaGreenTint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.seaGreen.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Class Attendance Rate: $pct%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.seaGreenDark)),
                    Text('Enrolled: $totalCount • Present: $fullCount • Half Override: $halfCount', style: const TextStyle(fontSize: 10, color: AppTheme.seaGreenDark)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.seaGreen, borderRadius: BorderRadius.circular(6)),
                  child: const Text('Verified ✅', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          const Text('📜 DETAILED ATTENDANCE TIMELINE & PROOF AUDIT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.charcoalMuted)),
          const SizedBox(height: 6),

          // Timeline Table
          Expanded(
            child: ListView.separated(
              itemCount: _rosterStudents.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.creamBorder),
              itemBuilder: (ctx, index) {
                final s = _rosterStudents[index];
                final name = s['name'] ?? 'Student';
                final classRoll = s['classRoll'] ?? '';
                final uniRoll = s['universityRoll'] ?? '';
                final status = _attendanceStatusByUniRoll[uniRoll];

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFFAF7F0), borderRadius: BorderRadius.circular(4), border: Border.all(color: AppTheme.creamBorder)),
                        child: Text(classRoll, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.charcoal)),
                            Text(
                              status == 'P'
                                  ? 'GPS: 18.4m within Dept • Token: SHA256-GPS-VALID'
                                  : status == 'H'
                                      ? 'Manual Override granted by Faculty • Synced'
                                      : 'No check-in recorded for $todayStr',
                              style: const TextStyle(fontSize: 9, color: AppTheme.charcoalMuted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: status == 'P'
                              ? AppTheme.seaGreenTint
                              : status == 'H'
                                  ? const Color(0xFFFEF3C7)
                                  : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status == 'P' ? 'Present (1.0)' : status == 'H' ? 'Half (0.5)' : 'Absent',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: status == 'P' ? AppTheme.seaGreenDark : status == 'H' ? const Color(0xFFB45309) : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Close / Print button
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: 'OFFICIAL ATTENDANCE AUDIT SLIP - $todayStr - Course: $_selectedCourseCode (Sem $_selectedSemester) - Attendance: $pct%'));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Audit Report summary copied to clipboard!')));
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: const Text('Export / Copy Audit Slip', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.seaGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.charcoal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final attendance = Provider.of<AttendanceProvider>(context);

    // Sync live check-ins into local status map
    for (final rec in attendance.liveTeacherCheckIns) {
      if (rec.universityRoll.isNotEmpty) {
        _attendanceStatusByUniRoll[rec.universityRoll] = (rec.status == 'Half') ? 'H' : 'P';
      }
      if (rec.classRoll.isNotEmpty) {
        _attendanceStatusByUniRoll[rec.classRoll] = (rec.status == 'Half') ? 'H' : 'P';
      }
    }

    final courses = _curriculum[_selectedSemester] ?? [];
    final currentCount = _sessionCountsByCourse[_selectedCourseCode ?? ''] ?? 0;

    final minutes = _countdownSeconds ~/ 60;
    final seconds = _countdownSeconds % 60;
    final timerString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final presentCount = _rosterStudents.where((s) => _attendanceStatusByUniRoll[s['universityRoll']] != null).length;
    final absentStudents = _rosterStudents.where((s) => _attendanceStatusByUniRoll[s['universityRoll']] == null).toList();

    final todayStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.seaGreenTint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.school, size: 18, color: AppTheme.seaGreenDark),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('AutoAttend', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.charcoal)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.seaGreen,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('FACULTY PORTAL', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const Text('Department of Master of Computer Applications (MCA)', style: TextStyle(fontSize: 9, color: AppTheme.charcoalMuted)),
              ],
            ),
          ],
        ),
        actions: [
          // Teacher Location Pill Button
          InkWell(
            onTap: _openLocationSettingsModal,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _detectedLatitude != null ? AppTheme.seaGreen : AppTheme.creamBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('👨‍🏫', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    auth.currentUser?.name.split(' ').first ?? 'Faculty',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.charcoal),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _detectedLatitude != null ? AppTheme.seaGreen : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: () async {
                await auth.logout();
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.charcoal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Logout', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. TOP FACULTY CONSOLE CARD (Dark Charcoal)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.charcoal,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppTheme.seaGreen, borderRadius: BorderRadius.circular(6)),
                          child: const Text('FACULTY CONSOLE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(width: 8),
                        const Text('Master of Computer Applications', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('$_selectedCourseCode', style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 10, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      auth.currentUser?.name ?? 'Sayantan Dasgupta',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      auth.currentUser?.email ?? 'sayantan05092004@gmail.com',
                      style: const TextStyle(color: Colors.white60, fontSize: 11, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 14),

                    // Two side-by-side action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openGoogleSheetSettingsModal,
                            icon: const Icon(Icons.table_chart_outlined, size: 14, color: Colors.white),
                            label: const Text('Google Sheet Settings', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white30),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openExportAuditReportModal,
                            icon: const Icon(Icons.file_download_outlined, size: 14, color: Colors.white),
                            label: const Text('Export Audit PDF', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.seaGreen,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. ATTENDANCE SESSION LAUNCHER CARD
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
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
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.charcoal),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F0),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.creamBorder),
                          ),
                          child: Text(
                            'Sessions Today: $currentCount / 3 (Max 3 Allowed)',
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.charcoal),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select semester & subject to broadcast real-time 15-minute GPS attendance window to student mobile apps.',
                      style: TextStyle(color: AppTheme.charcoalMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 14),

                    // Semester Dropdown
                    const Text('1. SELECT SEMESTER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.charcoalMuted)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: _selectedSemester,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.charcoal),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFFAF7F0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.creamBorder)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Semester 1 (10 Subjects)')),
                        DropdownMenuItem(value: 2, child: Text('Semester 2 (9 Subjects)')),
                        DropdownMenuItem(value: 3, child: Text('Semester 3 (10 Subjects)')),
                        DropdownMenuItem(value: 4, child: Text('Semester 4 (2 Subjects)')),
                      ],
                      onChanged: _isSessionActive ? null : (val) => val != null ? _onSemesterChanged(val) : null,
                    ),
                    const SizedBox(height: 12),

                    // Subject Dropdown
                    const Text('2. SELECT SUBJECT / LECTURE COURSE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.charcoalMuted)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedCourseCode,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.charcoal),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFFAF7F0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.creamBorder)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: courses.map((c) {
                        return DropdownMenuItem<String>(
                          value: c['code'],
                          child: Text('${c['code']}: ${c['name']} (Theory • Sem $_selectedSemester)', overflow: TextOverflow.ellipsis),
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
                                  _attendanceStatusByUniRoll.clear();
                                });
                                _fetchTodaySessionCounts();
                                _fetchTodayCheckIns();
                                _checkOngoingSession();
                              }
                            },
                    ),
                    const SizedBox(height: 14),

                    // Start / Stop Session Button (Full Width)
                    Builder(builder: (context) {
                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      final userEmail = auth.currentUser?.email.toLowerCase() ?? '';
                      final isSuperAdmin = auth.currentUser?.role == 'ADMIN' || ['sayantan05072004@gmail.com', 'sayantan05092004@gmail.com', 'sayantan.faculty@smartattend.edu'].contains(userEmail);

                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSessionActive
                              ? (isSuperAdmin ? _handleStopSession : null)
                              : (_isStartingSession || currentCount >= 3 ? null : _handleStartSession),
                          icon: Icon(_isSessionActive ? (isSuperAdmin ? Icons.stop_circle_outlined : Icons.sensors_rounded) : Icons.play_arrow_outlined, size: 18),
                          label: Text(
                            _isSessionActive
                                ? (isSuperAdmin ? 'Stop Session ($timerString) [Admin]' : 'Live Session Active ($timerString)')
                                : (currentCount >= 3 ? 'Max Daily Limit (3/3 Done)' : 'Start 15-Min Session'),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isSessionActive
                                ? (isSuperAdmin ? const Color(0xFFDC2626) : const Color(0xFF047857))
                                : (currentCount >= 3 ? const Color(0xFF9CA3AF) : AppTheme.seaGreen),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      );
                    }),

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
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.seaGreenDark),
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

              // 3. LIVE MATRIX GOOGLE SHEET MIRROR CARD
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
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
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.charcoal),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.seaGreenTint,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'P = Present • H = Half • Blank = Absent',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.seaGreenDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F0),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.creamBorder),
                      ),
                      child: Text(
                        'Students Checked In: $presentCount',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.charcoal),
                      ),
                    ),
                    const SizedBox(height: 12),

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
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.creamBorder),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(const Color(0xFFFAF7F0)),
                            headingTextStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.charcoalMuted),
                            dataTextStyle: const TextStyle(fontSize: 11, color: AppTheme.charcoal, fontWeight: FontWeight.w700),
                            columnSpacing: 16,
                            horizontalMargin: 12,
                            columns: [
                              const DataColumn(label: Text('Class Roll')),
                              const DataColumn(label: Text('University Roll')),
                              const DataColumn(label: Text('Registration No')),
                              const DataColumn(label: Text('Student Name')),
                              DataColumn(label: Text('$todayStr (Today)')),
                              const DataColumn(label: Text('Attendance Count', textAlign: TextAlign.right)),
                            ],
                            rows: _rosterStudents.map((s) {
                              final uniRoll = s['universityRoll'] ?? '';
                              final classRoll = s['classRoll'] ?? '';
                              final regNo = s['regNo'] ?? s['regNumber'] ?? '—';
                              final name = s['name'] ?? 'Student';
                              final status = _attendanceStatusByUniRoll[uniRoll];

                              Color statusBg = const Color(0xFFF3F4F6);
                              Color statusText = const Color(0xFF9CA3AF);
                              String statusLabel = '—';
                              String countLabel = '0';

                              if (status == 'P') {
                                statusBg = AppTheme.seaGreenTint;
                                statusText = AppTheme.seaGreenDark;
                                statusLabel = 'P';
                                countLabel = '1 (Full)';
                              } else if (status == 'H') {
                                statusBg = const Color(0xFFFEF3C7);
                                statusText = const Color(0xFFB45309);
                                statusLabel = 'H';
                                countLabel = '1 (Half)';
                              }

                              return DataRow(
                                cells: [
                                  DataCell(Text(classRoll, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800))),
                                  DataCell(Text(uniRoll, style: const TextStyle(fontFamily: 'monospace'))),
                                  DataCell(Text(regNo, style: const TextStyle(fontFamily: 'monospace', fontSize: 10))),
                                  DataCell(Text(name, style: const TextStyle(fontWeight: FontWeight.w800))),
                                  DataCell(
                                    Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusBg,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: statusText),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        countLabel,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                          color: status == 'P' ? AppTheme.seaGreenDark : status == 'H' ? const Color(0xFFB45309) : const Color(0xFF9CA3AF),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. GOOGLE SHEET ACTIVE & SYNCED CARD (Mint Green Container)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(color: AppTheme.seaGreen, shape: BoxShape.circle),
                          child: const Icon(Icons.check, size: 16, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Google Sheet Active & Synced',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.seaGreenDark),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppTheme.seaGreenTint, borderRadius: BorderRadius.circular(4)),
                          child: const Text('API v4 Live', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppTheme.seaGreenDark)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Text(
                        'Spreadsheet ID:  $_linkedSheetId',
                        style: const TextStyle(fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.w800, color: AppTheme.charcoal),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Two Buttons: View Audit Report & Change Sheet
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _openExportAuditReportModal,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: AppTheme.creamBorder),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('View Audit Report', style: TextStyle(color: AppTheme.charcoal, fontSize: 10, fontWeight: FontWeight.w800)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openGoogleSheetSettingsModal,
                            icon: const Icon(Icons.settings_outlined, size: 12),
                            label: const Text('Change Sheet', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.charcoal,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 5. LATE COMERS MANUAL OVERRIDE (HALF ATTENDANCE) CARD
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
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
                          'UNMARKED / ABSENT STUDENTS ROSTER',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppTheme.charcoal),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Students who have not yet marked attendance for today\'s active session.',
                      style: TextStyle(color: AppTheme.charcoalMuted, fontSize: 10),
                    ),
                    const SizedBox(height: 12),

                    if (absentStudents.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.seaGreenTint,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.seaGreen.withOpacity(0.2)),
                        ),
                        child: Center(
                          child: Text(
                            '🎉 All students for Semester $_selectedSemester have recorded attendance.',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.seaGreenDark),
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
                                      Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppTheme.charcoal)),
                                      Text('Roll: $classRoll • Uni: $uniRoll', style: const TextStyle(fontSize: 10, color: AppTheme.charcoalMuted)),
                                    ],
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _handleGrantFull(s),
                                  icon: const Icon(Icons.how_to_reg_rounded, size: 14, color: Color(0xFF6EE7B7)),
                                  label: const Text('Grant Full', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.charcoal,
                                    foregroundColor: Colors.white,
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
