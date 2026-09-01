class SessionModel {
  final String id;
  final String subjectId;
  final String subjectName;
  final String subjectCode;
  final String teacherName;
  final int semester;
  final bool isActive;
  final bool isAlreadyMarked;
  final int remainingSeconds;
  final DateTime createdAt;
  final DateTime expiresAt;
  final double? latitude;
  final double? longitude;
  final double? radiusMeters;

  SessionModel({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.subjectCode,
    required this.teacherName,
    required this.semester,
    required this.isActive,
    this.isAlreadyMarked = false,
    this.remainingSeconds = 0,
    required this.createdAt,
    required this.expiresAt,
    this.latitude,
    this.longitude,
    this.radiusMeters,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'] ?? '',
      subjectId: json['subjectId'] ?? '',
      subjectName: json['subject'] != null ? json['subject']['name'] : (json['subjectName'] ?? ''),
      subjectCode: json['subject'] != null ? json['subject']['code'] : (json['subjectCode'] ?? ''),
      teacherName: json['subject'] != null && json['subject']['teacher'] != null && json['subject']['teacher']['user'] != null
          ? json['subject']['teacher']['user']['name']
          : 'Teacher',
      semester: json['semester'] ?? 1,
      isActive: json['isActive'] ?? false,
      isAlreadyMarked: json['isAlreadyMarked'] ?? false,
      remainingSeconds: json['remainingSeconds'] ?? 0,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : DateTime.now(),
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      radiusMeters: json['radiusMeters'] != null ? (json['radiusMeters'] as num).toDouble() : null,
    );
  }
}
