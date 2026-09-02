import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';

class ManageSheetsScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;

  const ManageSheetsScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  State<ManageSheetsScreen> createState() => _ManageSheetsScreenState();
}

class _ManageSheetsScreenState extends State<ManageSheetsScreen> {
  final _sheetIdController = TextEditingController();
  final _tabNameController = TextEditingController(text: 'Attendance');
  String _serviceAccountEmail = 'Loading...';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchServiceAccountInfo();
  }

  void _fetchServiceAccountInfo() async {
    try {
      final res = await ApiService.getServiceAccountInfo();
      if (res['serviceAccountEmail'] != null) {
        setState(() {
          _serviceAccountEmail = res['serviceAccountEmail'];
        });
      }
    } catch (e) {
      setState(() {
        _serviceAccountEmail = 'attendance-sync@total-byte-507113-g0.iam.gserviceaccount.com';
      });
    }
  }

  void _handleLinkSheet() async {
    if (_sheetIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a Google Sheet ID.'),
          backgroundColor: AppTheme.charcoal,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await ApiService.linkTeacherSheet(
        widget.subjectId,
        _sheetIdController.text.trim(),
        tabName: _tabNameController.text.trim(),
      );

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Google Sheet connected successfully!'),
            backgroundColor: AppTheme.seaGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppTheme.statusDanger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      appBar: AppBar(
        title: const Text('Google Sheets Sync'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sync ${widget.subjectName}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.charcoal,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Attendance records auto-append with Date, Class Roll, University Roll, Reg No, Name, and Status.',
                style: TextStyle(color: AppTheme.charcoalMuted, fontSize: 13),
              ),
              const SizedBox(height: 18),

              // Service Account Box
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
                    const Row(
                      children: [
                        Icon(Icons.share_outlined, color: AppTheme.seaGreen, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Step 1: Share Google Sheet',
                          style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.charcoal, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Open your Google Sheet -> Click Share -> Add the service account email as Editor:',
                      style: TextStyle(color: AppTheme.charcoalMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F3EB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              _serviceAccountEmail,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.charcoal),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 18, color: AppTheme.charcoal),
                            tooltip: 'Copy Email',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _serviceAccountEmail));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Service Account Email copied!'),
                                  backgroundColor: AppTheme.charcoal,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Connect Sheet Card
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
                    const Text(
                      'Step 2: Enter Google Sheet ID',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.charcoal),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _sheetIdController,
                      style: const TextStyle(color: AppTheme.charcoal, fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Google Sheet ID',
                        hintText: 'e.g. 1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms',
                        prefixIcon: Icon(Icons.table_chart_outlined, color: AppTheme.charcoalMuted, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tabNameController,
                      style: const TextStyle(color: AppTheme.charcoal, fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Worksheet Tab Name',
                        hintText: 'Attendance',
                        prefixIcon: Icon(Icons.tab_outlined, color: AppTheme.charcoalMuted, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _isLoading ? null : _handleLinkSheet,
                child: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Connect & Verify Google Sheet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
