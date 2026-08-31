import bcrypt from 'bcryptjs';
import { prisma } from './database';

const mcaCurriculum = [
  // --- SEMESTER I ---
  { code: 'MCA-101', name: 'Mathematical Foundation', type: 'Theory', credits: 4, weeklyHours: '3+1+0', marks: '100 (70+30)', semester: 1 },
  { code: 'MCA-102', name: 'Data and File Structures', type: 'Theory', credits: 4, weeklyHours: '3+1+0', marks: '100 (70+30)', semester: 1 },
  { code: 'MCA-103', name: 'Computer Organization and Architecture', type: 'Theory', credits: 4, weeklyHours: '3+1+0', marks: '100 (70+30)', semester: 1 },
  { code: 'MCA-104', name: 'Microprocessor and its Applications', type: 'Theory', credits: 4, weeklyHours: '3+1+0', marks: '100 (70+30)', semester: 1 },
  { code: 'MCA-105', name: 'Introduction to Management Functions', type: 'Theory', credits: 4, weeklyHours: '3+1+0', marks: '100 (70+30)', semester: 1 },
  { code: 'MCA-111', name: 'Communicative English and Business Presentation', type: 'Practical', credits: 2, weeklyHours: '0+0+2', marks: '50', semester: 1 },
  { code: 'MCA-112', name: 'Data and File Structures Laboratory with C', type: 'Practical', credits: 3, weeklyHours: '0+0+3', marks: '100', semester: 1 },
  { code: 'MCA-113', name: 'Digital Circuits and Computer Organization Laboratory', type: 'Practical', credits: 3, weeklyHours: '0+0+3', marks: '100', semester: 1 },
  { code: 'MCA-114', name: 'Microprocessor and its Applications Laboratory', type: 'Practical', credits: 3, weeklyHours: '0+0+3', marks: '100', semester: 1 },
  { code: 'MCA-141*', name: 'Introduction to Computing and C Programming (Bridge)', type: 'Bridge Course', credits: 0, weeklyHours: '2+0+2', marks: '100 (40+10+50)', semester: 1 },

  // --- SEMESTER II ---
  { code: 'MCA-201', name: 'Design and Analysis of Algorithms', type: 'Theory', credits: 4, weeklyHours: '3+1+0', marks: '100 (70+30)', semester: 2 },
  { code: 'MCA-202', name: 'Object Oriented Programming', type: 'Theory', credits: 4, weeklyHours: '3+1+0', marks: '100 (70+30)', semester: 2 },
  { code: 'MCA-203', name: 'Database Management Systems', type: 'Theory', credits: 4, weeklyHours: '3+1+0', marks: '100 (70+30)', semester: 2 },
  { code: 'MCA-204', name: 'Operating Systems', type: 'Theory', credits: 4, weeklyHours: '3+1+0', marks: '100 (70+30)', semester: 2 },
  { code: 'MCA-205', name: 'Scientific Computing', type: 'Theory', credits: 4, weeklyHours: '3+1+0', marks: '100 (70+30)', semester: 2 },
  { code: 'MCA-211', name: 'Object Oriented Programming Laboratory', type: 'Practical', credits: 3, weeklyHours: '0+0+3', marks: '100', semester: 2 },
  { code: 'MCA-212', name: 'Database Management Systems Laboratory', type: 'Practical', credits: 3, weeklyHours: '0+0+3', marks: '100', semester: 2 },
  { code: 'MCA-213', name: 'Scientific Computing Laboratory', type: 'Practical', credits: 3, weeklyHours: '0+0+3', marks: '100', semester: 2 },
  { code: 'MCA-214', name: 'Advanced Programming Laboratory–I', type: 'Practical', credits: 3, weeklyHours: '0+0+3', marks: '100', semester: 2 },

  // --- SEMESTER III ---
  { code: 'MCA-301', name: 'Artificial Intelligence', type: 'Theory', credits: 4, weeklyHours: '3+1+0', marks: '100 (70+30)', semester: 3 },
  { code: 'MCA-302', name: 'Computer Networks', type: 'Theory', credits: 4, weeklyHours: '3+1+0', marks: '100 (70+30)', semester: 3 },
  { code: 'MCA-303', name: 'Software Engineering', type: 'Theory', credits: 4, weeklyHours: '3+1+0', marks: '100 (70+30)', semester: 3 },
  { code: 'MCA-304', name: 'Elective – I', type: 'Theory', credits: 4, weeklyHours: '3+1+0', marks: '100 (70+30)', semester: 3 },
  { code: 'MCA-305', name: 'Elective – II', type: 'Theory', credits: 4, weeklyHours: '3+1+0', marks: '100 (70+30)', semester: 3 },
  { code: 'MCA-306', name: 'Elective – III', type: 'Theory', credits: 4, weeklyHours: '3+1+0', marks: '100 (70+30)', semester: 3 },
  { code: 'MCA-311', name: 'Artificial Intelligence Laboratory', type: 'Practical', credits: 3, weeklyHours: '0+0+3', marks: '100', semester: 3 },
  { code: 'MCA-312', name: 'Web-based Programming Laboratory', type: 'Practical', credits: 3, weeklyHours: '0+0+3', marks: '100', semester: 3 },
  { code: 'MCA-313', name: 'Advanced Programming Laboratory-II', type: 'Practical', credits: 3, weeklyHours: '0+0+3', marks: '100', semester: 3 },
  { code: 'MCA-321', name: 'Project–I', type: 'Project', credits: 3, weeklyHours: '0+0+3', marks: '100', semester: 3 },

  // --- SEMESTER IV ---
  { code: 'MCA-421', name: 'Project–II (Major Capstone)', type: 'Project', credits: 16, weeklyHours: '0+0+24', marks: '400', semester: 4 },
  { code: 'MCA-431', name: 'Grand Viva', type: 'Viva', credits: 8, weeklyHours: '-', marks: '200', semester: 4 },
];

export async function seedMCACurriculum() {
  console.log('📚 Populating Official MCA Semester-wise Curriculum...');

  // 1. Create or Find MCA Department
  const mcaDept = await prisma.department.upsert({
    where: { code: 'MCA' },
    create: {
      name: 'Master of Computer Applications (MCA)',
      code: 'MCA',
      latitude: 22.5726,
      longitude: 88.3639,
      radiusMeters: 50.0,
    },
    update: {
      name: 'Master of Computer Applications (MCA)',
    },
  });

  // 2. Create Faculty Members
  const passwordHash = await bcrypt.hash('Teacher@123', 10);

  const teacher1 = await prisma.user.upsert({
    where: { email: 'prof.sharma@college.edu' },
    create: {
      name: 'Prof. R. K. Sharma',
      email: 'prof.sharma@college.edu',
      passwordHash,
      role: 'TEACHER',
      teacher: { create: { departmentId: mcaDept.id } },
    },
    update: {},
    include: { teacher: true },
  });

  const teacher2 = await prisma.user.upsert({
    where: { email: 'dr.ananya.sen@college.edu' },
    create: {
      name: 'Dr. Ananya Sen',
      email: 'dr.ananya.sen@college.edu',
      passwordHash,
      role: 'TEACHER',
      teacher: { create: { departmentId: mcaDept.id } },
    },
    update: {},
    include: { teacher: true },
  });

  const teacherList = [teacher1.teacher!, teacher2.teacher!];

  // 3. Seed All Subjects across Semesters I to IV
  let subjectCount = 0;
  for (let i = 0; i < mcaCurriculum.length; i++) {
    const item = mcaCurriculum[i];
    const assignedTeacher = teacherList[i % teacherList.length];

    await prisma.subject.upsert({
      where: {
        code_semester_teacherId: {
          code: item.code,
          semester: item.semester,
          teacherId: assignedTeacher.id,
        },
      },
      create: {
        code: item.code,
        name: item.name,
        type: item.type,
        credits: item.credits,
        weeklyHours: item.weeklyHours,
        marks: item.marks,
        semester: item.semester,
        departmentId: mcaDept.id,
        teacherId: assignedTeacher.id,
        googleSheetId: `sheet_${item.code.toLowerCase().replace(/[^a-z0-9]/g, '_')}`,
        sheetTabName: 'Attendance',
      },
      update: {
        name: item.name,
        type: item.type,
        credits: item.credits,
        weeklyHours: item.weeklyHours,
        marks: item.marks,
      },
    });
    subjectCount++;
  }

  // 4. Create Students for Semester 1, 2, 3
  const studentPasswordHash = await bcrypt.hash('Student@123', 10);

  // MCA Semester 1 Student
  await prisma.user.upsert({
    where: { email: 'mca.sem1@college.edu' },
    create: {
      name: 'Sayan Banerjee (Sem 1)',
      email: 'mca.sem1@college.edu',
      passwordHash: studentPasswordHash,
      role: 'STUDENT',
      student: {
        create: {
          classRoll: 'MCA-26-042',
          universityRoll: '12000126042',
          regNumber: 'REG-2026-9042',
          departmentId: mcaDept.id,
          semester: 1,
        },
      },
    },
    update: {},
  });

  // MCA Semester 2 Student
  await prisma.user.upsert({
    where: { email: 'mca.sem2@college.edu' },
    create: {
      name: 'Priya Das (Sem 2)',
      email: 'mca.sem2@college.edu',
      passwordHash: studentPasswordHash,
      role: 'STUDENT',
      student: {
        create: {
          classRoll: 'MCA-25-018',
          universityRoll: '12000125018',
          regNumber: 'REG-2025-8818',
          departmentId: mcaDept.id,
          semester: 2,
        },
      },
    },
    update: {},
  });

  // MCA Semester 3 Student
  await prisma.user.upsert({
    where: { email: 'mca.sem3@college.edu' },
    create: {
      name: 'Aakash Roy (Sem 3)',
      email: 'mca.sem3@college.edu',
      passwordHash: studentPasswordHash,
      role: 'STUDENT',
      student: {
        create: {
          classRoll: 'MCA-24-007',
          universityRoll: '12000124007',
          regNumber: 'REG-2024-7707',
          departmentId: mcaDept.id,
          semester: 3,
        },
      },
    },
    update: {},
  });

  console.log(`✅ Successfully seeded ${subjectCount} official MCA courses across Semester 1, 2, 3, and 4!`);
  console.log('  🏛️ Department: Master of Computer Applications (Code: MCA)');
  console.log('  👨‍🏫 Faculty: prof.sharma@college.edu, dr.ananya.sen@college.edu (Password: Teacher@123)');
  console.log('  🎓 Sem 1 Student: 12000126042 | Password: Student@123 (MCA-101 to MCA-141)');
  console.log('  🎓 Sem 2 Student: 12000125018 | Password: Student@123 (MCA-201 to MCA-214)');
  console.log('  🎓 Sem 3 Student: 12000124007 | Password: Student@123 (MCA-301 to MCA-321)');
}

seedMCACurriculum().catch(console.error).finally(() => prisma.$disconnect());
