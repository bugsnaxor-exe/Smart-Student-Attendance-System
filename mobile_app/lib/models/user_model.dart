class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // "STUDENT", "TEACHER", "ADMIN"
  final StudentDetails? student;
  final TeacherDetails? teacher;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.student,
    this.teacher,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'STUDENT',
      student: json['student'] != null ? StudentDetails.fromJson(json['student']) : null,
      teacher: json['teacher'] != null ? TeacherDetails.fromJson(json['teacher']) : null,
    );
  }
}

class StudentDetails {
  final String id;
  final String classRoll;
  final String universityRoll;
  final String regNumber;
  final int semester;
  final String departmentId;
  final String? departmentName;

  StudentDetails({
    required this.id,
    required this.classRoll,
    required this.universityRoll,
    required this.regNumber,
    required this.semester,
    required this.departmentId,
    this.departmentName,
  });

  factory StudentDetails.fromJson(Map<String, dynamic> json) {
    return StudentDetails(
      id: json['id'] ?? '',
      classRoll: json['classRoll'] ?? '',
      universityRoll: json['universityRoll'] ?? '',
      regNumber: json['regNumber'] ?? '',
      semester: json['semester'] ?? 1,
      departmentId: json['departmentId'] ?? '',
      departmentName: json['department'] != null ? json['department']['name'] : null,
    );
  }
}

class TeacherDetails {
  final String id;
  final String departmentId;
  final String? departmentName;
  final bool isApproved;
  final List<dynamic>? subjects;

  TeacherDetails({
    required this.id,
    required this.departmentId,
    this.departmentName,
    this.isApproved = false,
    this.subjects,
  });

  factory TeacherDetails.fromJson(Map<String, dynamic> json) {
    return TeacherDetails(
      id: json['id'] ?? '',
      departmentId: json['departmentId'] ?? '',
      departmentName: json['department'] != null ? json['department']['name'] : null,
      isApproved: json['isApproved'] == true,
      subjects: json['subjects'],
    );
  }
}
