import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../student/student_dashboard_screen.dart';
import '../teacher/teacher_dashboard_screen.dart';

enum AuthRole { student, faculty }
enum AuthMode { login, register }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  AuthRole _selectedRole = AuthRole.student;
  AuthMode _selectedMode = AuthMode.login;

  // Student Controllers
  final _studentIdentifierController = TextEditingController();
  final _studentPasswordController = TextEditingController();
  final _studentNameController = TextEditingController();
  final _studentEmailController = TextEditingController();
  final _studentClassRollController = TextEditingController();
  final _studentUniRollController = TextEditingController();
  final _studentRegNoController = TextEditingController();
  final _studentRegYearController = TextEditingController(text: '2025-2026');
  int _studentSemester = 3;
  String _studentDepartment = 'MCA';

  // Faculty Controllers
  final _facultyEmailController = TextEditingController();
  final _facultyPasswordController = TextEditingController();
  final _facultyNameController = TextEditingController();

  int _facultySemester = 3;
  String _facultySubjectCode = 'MCA-301';
  String _facultyDepartment = 'MCA';

  final List<Map<String, String>> _universityDepartments = [
    {'code': 'MCA', 'name': 'Master of Computer Applications (MCA)'},
    {'code': 'MCS', 'name': 'Master of Computer Science (MCS)'},
    {'code': 'MDS', 'name': 'Master of Data Science (MDS)'},
    {'code': 'MTECH', 'name': 'Master in Technology (M.Tech)'},
    {'code': 'MSC', 'name': 'Master in Science (M.Sc)'},
    {'code': 'BTECH', 'name': 'Bachelor in Technology (B.Tech)'},
  ];

  final Map<int, List<Map<String, String>>> _mcaSyllabus = {
    1: [
      {'code': 'MCA-101', 'name': 'Mathematical Foundation'},
      {'code': 'MCA-102', 'name': 'Computer Organization & Architecture'},
      {'code': 'MCA-103', 'name': 'Data Structures with C/C++'},
      {'code': 'MCA-104', 'name': 'Operating Systems'},
      {'code': 'MCA-105', 'name': 'Object-Oriented Programming (Java)'},
      {'code': 'MCA-191', 'name': 'Data Structures Lab'},
      {'code': 'MCA-192', 'name': 'Java Programming Lab'},
      {'code': 'MCA-193', 'name': 'OS & Linux Lab'},
      {'code': 'MCA-194', 'name': 'Soft Skills & Communication'},
      {'code': 'MCA-181', 'name': 'Bridge Course (Computer Basics)'},
    ],
    2: [
      {'code': 'MCA-201', 'name': 'Database Management Systems'},
      {'code': 'MCA-202', 'name': 'Design & Analysis of Algorithms'},
      {'code': 'MCA-203', 'name': 'Software Engineering & TQM'},
      {'code': 'MCA-204', 'name': 'Computer Networks'},
      {'code': 'MCA-205', 'name': 'Web Technologies (HTML/JS/PHP)'},
      {'code': 'MCA-291', 'name': 'DBMS & SQL Lab'},
      {'code': 'MCA-292', 'name': 'Algorithm Lab (Python)'},
      {'code': 'MCA-293', 'name': 'Web Development Lab'},
      {'code': 'MCA-294', 'name': 'Mini Project & Seminar'},
    ],
    3: [
      {'code': 'MCA-301', 'name': 'Artificial Intelligence & Machine Learning'},
      {'code': 'MCA-302', 'name': 'Cloud Computing & DevOps'},
      {'code': 'MCA-303', 'name': 'Information & Cyber Security'},
      {'code': 'MCA-E304A', 'name': 'Mobile Application Development (Flutter)'},
      {'code': 'MCA-E304B', 'name': 'Big Data Analytics'},
      {'code': 'MCA-391', 'name': 'AI & Machine Learning Lab'},
      {'code': 'MCA-392', 'name': 'Cloud & DevOps Lab'},
      {'code': 'MCA-393', 'name': 'Mobile Application Lab'},
      {'code': 'MCA-394', 'name': 'Industrial Training / Internship Viva'},
      {'code': 'MCA-395', 'name': 'Major Project Phase I'},
    ],
    4: [
      {'code': 'MCA-491', 'name': 'Major Project Phase II & Industry Dissertation'},
      {'code': 'MCA-492', 'name': 'Comprehensive Grand Viva Voce'},
    ],
  };

  bool _obscurePassword = true;

  @override
  void dispose() {
    _studentIdentifierController.dispose();
    _studentPasswordController.dispose();
    _studentNameController.dispose();
    _studentEmailController.dispose();
    _studentClassRollController.dispose();
    _studentUniRollController.dispose();
    _studentRegNoController.dispose();
    _studentRegYearController.dispose();
    _facultyEmailController.dispose();
    _facultyPasswordController.dispose();
    _facultyNameController.dispose();
    super.dispose();
  }

  void _handleStudentLogin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final identifier = _studentIdentifierController.text.trim();
    final password = _studentPasswordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      _showSnackBar('Please enter your University Roll/Email and password.', isError: true);
      return;
    }

    final result = await auth.login(identifier, password);

    if (result.success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StudentDashboardScreen()),
      );
    } else if (mounted) {
      _showSnackBar(result.error ?? 'Student login failed. Please check credentials.', isError: true);
    }
  }

  void _handleStudentRegister() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final name = _studentNameController.text.trim();
    final email = _studentEmailController.text.trim();
    final password = _studentPasswordController.text;
    final classRoll = _studentClassRollController.text.trim();
    final uniRoll = _studentUniRollController.text.trim();
    final regNumber = _studentRegNoController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || classRoll.isEmpty || uniRoll.isEmpty || regNumber.isEmpty) {
      _showSnackBar('Please fill in all student profile fields.', isError: true);
      return;
    }

    // 1. Validate Registration Number: 7 to 11 digits
    if (!RegExp(r'^\d{7,11}$').hasMatch(regNumber)) {
      _showSnackBar('Registration Number must be 7 to 11 digits (e.g. 2080033).', isError: true);
      return;
    }

    // 2. Validate University Roll: Exactly 8 digits
    if (!RegExp(r'^\d{8}$').hasMatch(uniRoll)) {
      _showSnackBar('University Roll Number must be exactly 8 digits (e.g. 25000028).', isError: true);
      return;
    }

    final success = await auth.registerStudent(
      name: name,
      email: email,
      password: password,
      classRoll: classRoll,
      universityRoll: uniRoll,
      regNumber: regNumber,
      departmentCode: _studentDepartment,
      semester: _studentSemester,
    );

    if (success && mounted) {
      _showSnackBar('Profile registered successfully! Logging in...', isError: false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StudentDashboardScreen()),
      );
    } else if (mounted) {
      _showSnackBar(auth.errorMessage ?? 'Student registration failed.', isError: true);
    }
  }

  void _handleFacultyLogin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = _facultyEmailController.text.trim();
    final password = _facultyPasswordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please enter your Faculty email and password.', isError: true);
      return;
    }

    final result = await auth.login(email, password);

    if (result.requiresOtp && mounted) {
      _showFacultyOtpBottomSheet(result.email ?? email);
    } else if (result.success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TeacherDashboardScreen()),
      );
    } else if (mounted) {
      String msg = result.error ?? 'Faculty login failed. Check email/password.';
      if (msg.toLowerCase().contains('pending approval') || msg.toLowerCase().contains('pending verification')) {
        msg = 'Your faculty registration is pending verification and approval by the Administrator.';
      } else if (msg.contains('roll number') || msg.contains('No registered account') || msg.contains('Invalid email') || msg.contains('not found')) {
        msg = 'Faculty account not found for this email. Please check your email or register.';
      } else if (msg.toLowerCase().contains('password')) {
        msg = 'Incorrect password for faculty account. Please try again.';
      }
      _showSnackBar(msg, isError: true);
    }
  }

  void _handleFacultyRegister() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final name = _facultyNameController.text.trim();
    final email = _facultyEmailController.text.trim();
    final password = _facultyPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill in your name, email and password.', isError: true);
      return;
    }

    final success = await auth.registerTeacher(
      name: name,
      email: email,
      password: password,
      departmentCode: _facultyDepartment,
      semester: _facultySemester,
      subjectCode: _facultySubjectCode,
    );

    if (success && mounted) {
      if (auth.token != null) {
        _showSnackBar('Faculty registered successfully! Accessing console...', isError: false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TeacherDashboardScreen()),
        );
      } else {
        _showSnackBar('Faculty registration submitted! Awaiting Administrator approval before login.', isError: false);
        setState(() => _selectedMode = AuthMode.login);
      }
    } else if (mounted) {
      _showSnackBar(auth.errorMessage ?? 'Faculty registration failed.', isError: true);
    }
  }

  void _showFacultyOtpBottomSheet(String email) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FacultyOtpSheet(
        email: email,
        onSuccess: () {
          Navigator.pop(ctx);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const TeacherDashboardScreen()),
          );
        },
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        backgroundColor: isError ? AppTheme.statusDanger : AppTheme.seaGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                // Minimalist Emblem
                Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.seaGreenTint,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.seaGreen.withOpacity(0.25), width: 1.2),
                    ),
                    child: const Icon(
                      Icons.school_outlined,
                      size: 28,
                      color: AppTheme.seaGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'AutoAttend',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.charcoal,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Department of Master of Computer Applications',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.charcoalMuted,
                  ),
                ),
                const SizedBox(height: 24),

                // Top Primary Segmented Control: [ Student ] | [ Faculty ]
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.creamCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.creamBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedRole = AuthRole.student),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedRole == AuthRole.student ? AppTheme.charcoal : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _selectedRole == AuthRole.student
                                  ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.school_rounded,
                                  size: 16,
                                  color: _selectedRole == AuthRole.student ? Colors.white : AppTheme.charcoalMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Student',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedRole == AuthRole.student ? Colors.white : AppTheme.charcoalMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedRole = AuthRole.faculty),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedRole == AuthRole.faculty ? AppTheme.charcoal : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _selectedRole == AuthRole.faculty
                                  ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.badge_rounded,
                                  size: 16,
                                  color: _selectedRole == AuthRole.faculty ? Colors.white : AppTheme.charcoalMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Faculty',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedRole == AuthRole.faculty ? Colors.white : AppTheme.charcoalMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Sub-Action Selector: [ Sign In ] | [ Create Account ]
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.creamCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.creamBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedMode = AuthMode.login),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _selectedMode == AuthMode.login ? AppTheme.seaGreen : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: _selectedMode == AuthMode.login
                                  ? [BoxShadow(color: AppTheme.seaGreen.withOpacity(0.25), blurRadius: 4, offset: const Offset(0, 2))]
                                  : null,
                            ),
                            child: Text(
                              'Sign In',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _selectedMode == AuthMode.login ? Colors.white : AppTheme.charcoalMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedMode = AuthMode.register),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _selectedMode == AuthMode.register ? AppTheme.seaGreen : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: _selectedMode == AuthMode.register
                                  ? [BoxShadow(color: AppTheme.seaGreen.withOpacity(0.25), blurRadius: 4, offset: const Offset(0, 2))]
                                  : null,
                            ),
                            child: Text(
                              'Create Account',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _selectedMode == AuthMode.register ? Colors.white : AppTheme.charcoalMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Form Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.creamBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _selectedRole == AuthRole.student
                      ? (_selectedMode == AuthMode.login ? _buildStudentLoginForm(auth) : _buildStudentRegisterForm(auth))
                      : (_selectedMode == AuthMode.login ? _buildFacultyLoginForm(auth) : _buildFacultyRegisterForm(auth)),
                ),
              ],
            ),
          ),
        ),
      );
  }

  // --- 1. STUDENT LOGIN FORM ---
  Widget _buildStudentLoginForm(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Student Sign In',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.charcoal),
        ),
        const SizedBox(height: 2),
        const Text(
          'Sign in with your University Roll or Email to verify presence.',
          style: TextStyle(fontSize: 11, color: AppTheme.charcoalMuted),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _studentIdentifierController,
          style: const TextStyle(fontSize: 13, color: AppTheme.charcoal),
          decoration: const InputDecoration(
            labelText: 'University Roll / Email',
            prefixIcon: Icon(Icons.badge_outlined, size: 18),
            hintText: 'e.g. 120/001/26042 or MCA/2026/042',
          ),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _studentPasswordController,
          obscureText: _obscurePassword,
          style: const TextStyle(fontSize: 13, color: AppTheme.charcoal),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline, size: 18),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 18),

        ElevatedButton(
          onPressed: auth.isLoading ? null : _handleStudentLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.seaGreen,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: auth.isLoading
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Sign In as Student', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  // --- 2. STUDENT REGISTER FORM ---
  Widget _buildStudentRegisterForm(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Student Registration',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.charcoal),
        ),
        const SizedBox(height: 2),
        const Text(
          'Enroll your real device with hardware geofencing.',
          style: TextStyle(fontSize: 11, color: AppTheme.charcoalMuted),
        ),
        const SizedBox(height: 14),

        TextField(
          controller: _studentNameController,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline, size: 18)),
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _studentEmailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined, size: 18)),
        ),
        const SizedBox(height: 10),

        DropdownButtonFormField<String>(
          value: _studentDepartment,
          dropdownColor: Colors.white,
          isExpanded: true,
          style: const TextStyle(fontSize: 12, color: AppTheme.charcoal, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            labelText: 'Department / Course Program',
            prefixIcon: Icon(Icons.school_outlined, size: 18),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
          items: _universityDepartments
              .map((d) => DropdownMenuItem(
                    value: d['code'],
                    child: Text(d['name']!, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _studentDepartment = val);
          },
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _studentUniRollController,
                maxLength: 8,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'University Roll (8 digits)',
                  hintText: 'e.g. 25000028',
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _studentClassRollController,
                maxLength: 8,
                inputFormatters: [LengthLimitingTextInputFormatter(8)],
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Class Roll',
                  hintText: 'e.g. 42',
                  counterText: '',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _studentRegYearController,
                maxLength: 9,
                inputFormatters: [LengthLimitingTextInputFormatter(9)],
                keyboardType: TextInputType.text,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Reg. Year',
                  hintText: 'e.g. 2025-2026',
                  prefixIcon: Icon(Icons.calendar_today_outlined, size: 16),
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _studentSemester,
                dropdownColor: Colors.white,
                style: const TextStyle(fontSize: 13, color: AppTheme.charcoal, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  labelText: 'Semester',
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                items: [1, 2, 3, 4]
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text('Sem $s', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _studentSemester = val ?? 3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _studentRegNoController,
          maxLength: 11,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            labelText: 'Reg Number (7-11 digits)',
            hintText: '2080033',
            counterText: '',
          ),
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _studentPasswordController,
          obscureText: _obscurePassword,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(labelText: 'Create Password', prefixIcon: Icon(Icons.lock_outline, size: 18)),
        ),
        const SizedBox(height: 16),

        ElevatedButton(
          onPressed: auth.isLoading ? null : _handleStudentRegister,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.seaGreen,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: auth.isLoading
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Register Student Profile', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  // --- 3. FACULTY LOGIN FORM ---
  Widget _buildFacultyLoginForm(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Faculty Sign In',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.charcoal),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.seaGreenTint,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.seaGreen.withOpacity(0.3)),
              ),
              child: const Text('🔐 2FA Email Protected', style: TextStyle(color: AppTheme.seaGreenDark, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        const Text(
          'Single-use 6-digit OTP will be dispatched to your email.',
          style: TextStyle(fontSize: 11, color: AppTheme.charcoalMuted),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _facultyEmailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(fontSize: 13, color: AppTheme.charcoal),
          decoration: const InputDecoration(
            labelText: 'Faculty Email',
            prefixIcon: Icon(Icons.alternate_email, size: 18),
            hintText: 'prof.sharma@college.edu',
          ),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _facultyPasswordController,
          obscureText: _obscurePassword,
          style: const TextStyle(fontSize: 13, color: AppTheme.charcoal),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline, size: 18),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 18),

        ElevatedButton(
          onPressed: auth.isLoading ? null : _handleFacultyLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.charcoal,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: auth.isLoading
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Sign In as Faculty (2FA)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  // --- 4. FACULTY REGISTER FORM ---
  Widget _buildFacultyRegisterForm(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Faculty Account Registration',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.charcoal),
        ),
        const SizedBox(height: 2),
        const Text(
          'Create your faculty account for MCA attendance sessions.',
          style: TextStyle(fontSize: 11, color: AppTheme.charcoalMuted),
        ),
        const SizedBox(height: 14),

        TextField(
          controller: _facultyNameController,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(labelText: 'Faculty Full Name', prefixIcon: Icon(Icons.person_outline, size: 18), hintText: 'Prof. R. K. Sharma'),
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _facultyEmailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(labelText: 'Official Email Address', prefixIcon: Icon(Icons.email_outlined, size: 18), hintText: 'faculty@college.edu'),
        ),
        const SizedBox(height: 10),

        DropdownButtonFormField<String>(
          value: _facultyDepartment,
          dropdownColor: Colors.white,
          isExpanded: true,
          style: const TextStyle(fontSize: 12, color: AppTheme.charcoal, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            labelText: 'Department / Course Program',
            prefixIcon: Icon(Icons.business_outlined, size: 18),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
          items: _universityDepartments
              .map((d) => DropdownMenuItem(
                    value: d['code'],
                    child: Text(d['name']!, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _facultyDepartment = val);
          },
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _facultySemester,
                dropdownColor: Colors.white,
                style: const TextStyle(fontSize: 12, color: AppTheme.charcoal, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(labelText: 'Semester', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                items: [1, 2, 3, 4]
                    .map((s) => DropdownMenuItem(value: s, child: Text('Sem $s', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _facultySemester = val;
                      final subjects = _mcaSyllabus[val] ?? [];
                      if (subjects.isNotEmpty) {
                        _facultySubjectCode = subjects[0]['code']!;
                      }
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: _facultySubjectCode,
                dropdownColor: Colors.white,
                isExpanded: true,
                style: const TextStyle(fontSize: 12, color: AppTheme.charcoal, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(labelText: 'Assigned Subject', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                items: (_mcaSyllabus[_facultySemester] ?? [])
                    .map((sub) => DropdownMenuItem(
                          value: sub['code'],
                          child: Text('${sub['code']}: ${sub['name']}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _facultySubjectCode = val);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _facultyPasswordController,
          obscureText: _obscurePassword,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(labelText: 'Create Password', prefixIcon: Icon(Icons.lock_outline, size: 18)),
        ),
        const SizedBox(height: 16),

        ElevatedButton(
          onPressed: auth.isLoading ? null : _handleFacultyRegister,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.charcoal,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: auth.isLoading
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Register Faculty Account', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// --- 2FA OTP BOTTOM SHEET ---
class _FacultyOtpSheet extends StatefulWidget {
  final String email;
  final VoidCallback onSuccess;

  const _FacultyOtpSheet({required this.email, required this.onSuccess});

  @override
  State<_FacultyOtpSheet> createState() => _FacultyOtpSheetState();
}

class _FacultyOtpSheetState extends State<_FacultyOtpSheet> {
  final _otpController = TextEditingController();
  int _secondsRemaining = 300;
  Timer? _timer;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 300);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the full 6-digit OTP code.'), backgroundColor: AppTheme.statusDanger),
      );
      return;
    }

    setState(() => _isVerifying = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.verifyFacultyOtp(widget.email, otp);
    setState(() => _isVerifying = false);

    if (success && mounted) {
      widget.onSuccess();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Invalid or expired OTP.'), backgroundColor: AppTheme.statusDanger),
      );
    }
  }

  void _resendOtp() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.resendFacultyOtp(widget.email);
    if (success && mounted) {
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fresh OTP code dispatched to ${widget.email}'), backgroundColor: AppTheme.seaGreen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    final timerText = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.creamBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.creamBorder, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded, size: 20, color: AppTheme.seaGreen),
              SizedBox(width: 6),
              Text('2FA Security Code', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.charcoal)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Enter the 6-digit OTP code dispatched to:\n${widget.email}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppTheme.charcoalMuted),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 8, color: AppTheme.charcoal),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••••',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.seaGreen, width: 2)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.seaGreen, width: 2)),
            ),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('⏱️ Expires in $timerText', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.charcoalMuted)),
              TextButton(
                onPressed: _secondsRemaining <= 240 ? _resendOtp : null,
                child: const Text('Resend Code', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.seaGreen)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ElevatedButton(
            onPressed: _isVerifying ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.seaGreen,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isVerifying
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Verify & Access Faculty Console', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
