import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../student/student_dashboard_screen.dart';

class StudentRegisterScreen extends StatefulWidget {
  const StudentRegisterScreen({super.key});

  @override
  State<StudentRegisterScreen> createState() => _StudentRegisterScreenState();
}

class _StudentRegisterScreenState extends State<StudentRegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _classRollController = TextEditingController();
  final _regNumberController = TextEditingController();
  final _regYearController = TextEditingController(text: '2025-2026');
  final _deptCodeController = TextEditingController(text: 'MCA');
  int _selectedSemester = 3;

  void _handleRegister() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _classRollController.text.isEmpty ||
        _uniRollController.text.isEmpty ||
        _regNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all mandatory student fields.'),
          backgroundColor: AppTheme.charcoal,
        ),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.registerStudent(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      classRoll: _classRollController.text.trim().toUpperCase(),
      universityRoll: _uniRollController.text.trim(),
      regNumber: _regNumberController.text.trim().toUpperCase(),
      departmentCode: _deptCodeController.text.trim().toUpperCase(),
      semester: _selectedSemester,
    );

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StudentDashboardScreen()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Registration failed.'),
          backgroundColor: AppTheme.statusDanger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      appBar: AppBar(
        title: const Text('Student Enrollment'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enroll Profile',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.charcoal,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Provide your official Class Roll, University Roll, and Registration Number.',
                style: TextStyle(color: AppTheme.charcoalMuted, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // Full Name
              TextField(
                controller: _nameController,
                style: const TextStyle(color: AppTheme.charcoal, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline, color: AppTheme.charcoalMuted, size: 20),
                ),
              ),
              const SizedBox(height: 14),

              // Official Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppTheme.charcoal, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'College Email',
                  prefixIcon: Icon(Icons.email_outlined, color: AppTheme.charcoalMuted, size: 20),
                ),
              ),
              const SizedBox(height: 14),

              // Class Roll & University Roll
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _classRollController,
                      style: const TextStyle(color: AppTheme.charcoal, fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Class Roll',
                        hintText: 'CSE-042',
                        prefixIcon: Icon(Icons.format_list_numbered, color: AppTheme.charcoalMuted, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _uniRollController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppTheme.charcoal, fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'University Roll',
                        hintText: '12000123042',
                        prefixIcon: Icon(Icons.tag, color: AppTheme.charcoalMuted, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Registration Number & Dept Code
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _regNumberController,
                      style: const TextStyle(color: AppTheme.charcoal, fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Registration No',
                        hintText: 'REG-2023-8891',
                        prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.charcoalMuted, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _deptCodeController,
                      style: const TextStyle(color: AppTheme.charcoal, fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Dept',
                        hintText: 'CSE',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _regYearController,
                      keyboardType: TextInputType.text,
                      style: const TextStyle(color: AppTheme.charcoal, fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Reg. Year',
                        hintText: 'e.g. 2025-2026',
                        prefixIcon: Icon(Icons.calendar_today_outlined, color: AppTheme.charcoalMuted, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedSemester,
                      style: const TextStyle(color: AppTheme.charcoal, fontSize: 14, fontWeight: FontWeight.w700),
                      dropdownColor: AppTheme.creamCard,
                      decoration: const InputDecoration(
                        labelText: 'Semester',
                        prefixIcon: Icon(Icons.layers_outlined, color: AppTheme.charcoalMuted, size: 18),
                      ),
                      items: [1, 2, 3, 4]
                          .map((sem) => DropdownMenuItem(
                                value: sem,
                                child: Text('Semester $sem'),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSemester = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Password
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: AppTheme.charcoal, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline, color: AppTheme.charcoalMuted, size: 20),
                ),
              ),
              const SizedBox(height: 26),

              // Submit Button
              ElevatedButton(
                onPressed: auth.isLoading ? null : _handleRegister,
                child: auth.isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Complete Enrollment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
