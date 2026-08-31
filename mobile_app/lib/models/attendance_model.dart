class SubjectAttendanceStats {
  final String subjectId;
  final String code;
  final String name;
  final String type; // Theory, Practical, Bridge Course, Project, Viva
  final int credits;
  final String? weeklyHours;
  final String? marks;
  final String teacherName;
  final int classesConducted;
  final double classesAttended;
  final double percentage;
  final String statusCategory; // "Safe", "Warning", "Defaulter"

  SubjectAttendanceStats({
    required this.subjectId,
    required this.code,
    required this.name,
    this.type = 'Theory',
    this.credits = 4,
    this.weeklyHours,
    this.marks,
    required this.teacherName,
    required this.classesConducted,
    required this.classesAttended,
    required this.percentage,
    required this.statusCategory,
  });

  factory SubjectAttendanceStats.fromJson(Map<String, dynamic> json) {
    return SubjectAttendanceStats(
      subjectId: json['subjectId'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'Theory',
      credits: json['credits'] ?? 4,
      weeklyHours: json['weeklyHours'],
      marks: json['marks'],
      teacherName: json['teacherName'] ?? '',
      classesConducted: json['classesConducted'] ?? 0,
      classesAttended: (json['classesAttended'] is int)
          ? (json['classesAttended'] as int).toDouble()
          : (json['classesAttended'] ?? 0.0),
      percentage: (json['percentage'] is int)
          ? (json['percentage'] as int).toDouble()
          : (json['percentage'] ?? 0.0),
      statusCategory: json['statusCategory'] ?? 'Safe',
    );
  }
}

class DashboardStats {
  final double overallPercentage;
  final int totalClassesConducted;
  final double totalClassesAttended;
  final String statusCategory;

  DashboardStats({
    required this.overallPercentage,
    required this.totalClassesConducted,
    required this.totalClassesAttended,
    required this.statusCategory,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      overallPercentage: (json['overallPercentage'] is int)
          ? (json['overallPercentage'] as int).toDouble()
          : (json['overallPercentage'] ?? 0.0),
      totalClassesConducted: json['totalClassesConducted'] ?? 0,
      totalClassesAttended: (json['totalClassesAttended'] is int)
          ? (json['totalClassesAttended'] as int).toDouble()
          : (json['totalClassesAttended'] ?? 0.0),
      statusCategory: json['statusCategory'] ?? 'Safe',
    );
  }
}

class StudentAttendanceCheckIn {
  final String id;
  final String studentName;
  final String classRoll;
  final String universityRoll;
  final String regNumber;
  final String status; // "Full" or "Half"
  final String time;
  final double? distanceMeters;
  final bool syncedToSheet;

  StudentAttendanceCheckIn({
    required this.id,
    required this.studentName,
    required this.classRoll,
    required this.universityRoll,
    required this.regNumber,
    required this.status,
    required this.time,
    this.distanceMeters,
    required this.syncedToSheet,
  });

  factory StudentAttendanceCheckIn.fromJson(Map<String, dynamic> json) {
    return StudentAttendanceCheckIn(
      id: json['id'] ?? '',
      studentName: json['studentName'] ?? '',
      classRoll: json['classRoll'] ?? '',
      universityRoll: json['universityRoll'] ?? '',
      regNumber: json['regNumber'] ?? '',
      status: json['status'] ?? 'Full',
      time: json['time'] ?? '',
      distanceMeters: json['distanceMeters'] != null ? (json['distanceMeters'] as num).toDouble() : null,
      syncedToSheet: json['syncedToSheet'] ?? false,
    );
  }
}
