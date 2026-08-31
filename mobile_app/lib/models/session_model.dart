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
    );
  }
}
