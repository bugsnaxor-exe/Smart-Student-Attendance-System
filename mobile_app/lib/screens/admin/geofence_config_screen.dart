import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';

class GeofenceConfigScreen extends StatefulWidget {
  final String departmentId;
  final String departmentName;

  const GeofenceConfigScreen({
    super.key,
    required this.departmentId,
    required this.departmentName,
  });

  @override
  State<GeofenceConfigScreen> createState() => _GeofenceConfigScreenState();
}

class _GeofenceConfigScreenState extends State<GeofenceConfigScreen> {
  final _latController = TextEditingController(text: AppConstants.defaultDeptLatitude.toString());
  final _lonController = TextEditingController(text: AppConstants.defaultDeptLongitude.toString());
  final _radiusController = TextEditingController(text: AppConstants.defaultGeofenceRadiusMeters.toString());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      appBar: AppBar(
        title: const Text('Department Geofence'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Configure ${widget.departmentName}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.charcoal,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Set the central GPS coordinates and allowable radius for student verification.',
                style: TextStyle(color: AppTheme.charcoalMuted, fontSize: 13),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.creamCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.creamBorder, width: 1.0),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _latController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: AppTheme.charcoal, fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Department Latitude',
                        prefixIcon: Icon(Icons.north, color: AppTheme.charcoalMuted, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _lonController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: AppTheme.charcoal, fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Department Longitude',
                        prefixIcon: Icon(Icons.east, color: AppTheme.charcoalMuted, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _radiusController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: AppTheme.charcoal, fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Geofence Radius (Meters)',
                        hintText: '50.0',
                        prefixIcon: Icon(Icons.radar, color: AppTheme.charcoalMuted, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Department geofence settings updated successfully!'),
                      backgroundColor: AppTheme.seaGreen,
                    ),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Save Department Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
