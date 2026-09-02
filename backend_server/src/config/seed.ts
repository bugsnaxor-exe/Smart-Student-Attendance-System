import bcrypt from 'bcryptjs';
import { prisma } from './database';

async function seed() {
  console.log('🌱 Seeding Smart Attendance System Database...');

  // 1. Create or Find Department
  const dept = await prisma.department.upsert({
    where: { code: 'CSE' },
    create: {
      name: 'Computer Science & Engineering',
      code: 'CSE',
      latitude: 22.5726,
      longitude: 88.3639,
      radiusMeters: 50.0,
    },
    update: {},
  });

  // 2. Create Demo Teacher
  const teacherPasswordHash = await bcrypt.hash('Teacher@123', 10);
  const teacherUser = await prisma.user.upsert({
    where: { email: 'prof.sharma@college.edu' },
    create: {
      name: 'Prof. R. K. Sharma',
      email: 'prof.sharma@college.edu',
      passwordHash: teacherPasswordHash,
      role: 'TEACHER',
      teacher: {
        create: {
          departmentId: dept.id,
        },
      },
    },
    update: {},
    include: { teacher: true },
  });

  // 3. Create Demo Subjects for Teacher
  if (teacherUser.teacher) {
    await prisma.subject.upsert({
      where: {
        code_semester_batchYear: {
          code: 'CS501',
          semester: 5,
          batchYear: '2025-2026',
        },
      },
      create: {
        code: 'CS501',
        name: 'Operating Systems',
        semester: 5,
        batchYear: '2025-2026',
        departmentId: dept.id,
        teacherId: teacherUser.teacher.id,
        googleSheetId: 'sample_subject_sheet_id_cs501',
        sheetTabName: 'Attendance',
      },
      update: {},
    });

    await prisma.subject.upsert({
      where: {
        code_semester_batchYear: {
          code: 'CS502',
          semester: 5,
          batchYear: '2025-2026',
        },
      },
      create: {
        code: 'CS502',
        name: 'Database Management Systems',
        semester: 5,
        departmentId: dept.id,
        teacherId: teacherUser.teacher.id,
        googleSheetId: 'sample_subject_sheet_id_cs502',
        sheetTabName: 'Attendance',
      },
      update: {},
    });
  }

  // 4. Create Demo Students
  const studentPasswordHash = await bcrypt.hash('Student@123', 10);

  // Student 1 (Sayan Banerjee)
  await prisma.user.upsert({
    where: { email: 'sayan.banerjee@college.edu' },
    create: {
      name: 'Sayan Banerjee',
      email: 'sayan.banerjee@college.edu',
      passwordHash: studentPasswordHash,
      role: 'STUDENT',
      student: {
        create: {
          classRoll: 'CSE-042',
          universityRoll: '12000123042',
          regNumber: 'REG-2023-8891',
          departmentId: dept.id,
          semester: 5,
        },
      },
    },
    update: {},
  });

  // Student 2 (Jane Smith)
  await prisma.user.upsert({
    where: { email: 'jane.smith@college.edu' },
    create: {
      name: 'Jane Smith',
      email: 'jane.smith@college.edu',
      passwordHash: studentPasswordHash,
      role: 'STUDENT',
      student: {
        create: {
          classRoll: 'CSE-015',
          universityRoll: '12000123015',
          regNumber: 'REG-2023-8864',
          departmentId: dept.id,
          semester: 5,
        },
      },
    },
    update: {},
  });

  // Student 3 (Rahul Verma)
  await prisma.user.upsert({
    where: { email: 'rahul.verma@college.edu' },
    create: {
      name: 'Rahul Verma',
      email: 'rahul.verma@college.edu',
      passwordHash: studentPasswordHash,
      role: 'STUDENT',
      student: {
        create: {
          classRoll: 'CSE-008',
          universityRoll: '12000123008',
          regNumber: 'REG-2023-8857',
          departmentId: dept.id,
          semester: 5,
        },
      },
    },
    update: {},
  });

  console.log('✅ Database seeded successfully!');
  console.log('  👨‍🏫 Faculty Account: prof.sharma@college.edu | Password: Teacher@123');
  console.log('  🎓 Student Account: 12000123042 (or sayan.banerjee@college.edu) | Password: Student@123');
  console.log('  🎓 Latecomer Student: 12000123015 (Jane Smith) | Password: Student@123');
}

seed().catch(console.error).finally(() => prisma.$disconnect());
