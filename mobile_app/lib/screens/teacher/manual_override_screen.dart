import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/attendance_provider.dart';

class ManualOverrideScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;

  const ManualOverrideScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  State<ManualOverrideScreen> createState() => _ManualOverrideScreenState();
}

class _ManualOverrideScreenState extends State<ManualOverrideScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final attendance = Provider.of<AttendanceProvider>(context, listen: false);
      attendance.fetchAbsentStudents(widget.subjectId);
    });
  }

  void _handleGrantHalf(String studentId, String studentName) async {
    final attendance = Provider.of<AttendanceProvider>(context, listen: false);
    final success = await attendance.grantHalfAttendance(widget.subjectId, studentId);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Granted Half attendance to $studentName. Synced with Google Sheet.'),
          backgroundColor: AppTheme.charcoal,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendance = Provider.of<AttendanceProvider>(context);
    final absentStudents = attendance.absentStudents;

    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      appBar: AppBar(
        title: const Text('Latecomer Override'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Subject Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.creamCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.creamBorder, width: 1.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.subjectName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.charcoal),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Students who missed the 15-minute window are listed below. Tap "Grant Half" to log manual half attendance and push to your Google Sheet.',
                      style: TextStyle(color: AppTheme.charcoalMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Unmarked Students (${absentStudents.length})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.charcoal,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18, color: AppTheme.charcoalMuted),
                    onPressed: () => attendance.fetchAbsentStudents(widget.subjectId),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Expanded(
                child: absentStudents.isEmpty
                    ? const Center(
                        child: Text(
                          'No absent students for today or all have marked attendance.',
                          style: TextStyle(color: AppTheme.charcoalMuted, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        itemCount: absentStudents.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final student = absentStudents[index];
                          return Container(
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
                                  backgroundColor: const Color(0xFFF1EDE4),
                                  child: Text(
                                    student['name']?[0] ?? 'S',
                                    style: const TextStyle(color: AppTheme.charcoal, fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        student['name'] ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.charcoal),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        'Class: ${student['classRoll']}  •  Uni: ${student['universityRoll']}',
                                        style: const TextStyle(color: AppTheme.charcoalMuted, fontSize: 11),
                                      ),
                                      Text(
                                        'Reg: ${student['regNumber']}',
                                        style: const TextStyle(color: AppTheme.charcoalLight, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => _handleGrantHalf(student['id'], student['name']),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.charcoal,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Grant Half', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
