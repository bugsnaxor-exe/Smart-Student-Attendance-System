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
  { code: 'MCA-304', name: 'Elective – I (Cloud Computing / ML)', type: 'Theory', credits: 4, weeklyHours: '3+1+0', marks: '100 (70+30)', semester: 3 },
  { code: 'MCA-305', name: 'Elective – II (Cyber Security)', type: 'Theory', credits: 4, weeklyHours: '3+1+0', marks: '100 (70+30)', semester: 3 },
  { code: 'MCA-306', name: 'Elective – III (Mobile Computing)', type: 'Theory', credits: 4, weeklyHours: '3+1+0', marks: '100 (70+30)', semester: 3 },
  { code: 'MCA-311', name: 'Artificial Intelligence Laboratory', type: 'Practical', credits: 3, weeklyHours: '0+0+3', marks: '100', semester: 3 },
  { code: 'MCA-312', name: 'Web-based Programming Laboratory', type: 'Practical', credits: 3, weeklyHours: '0+0+3', marks: '100', semester: 3 },
  { code: 'MCA-313', name: 'Advanced Programming Laboratory-II', type: 'Practical', credits: 3, weeklyHours: '0+0+3', marks: '100', semester: 3 },
  { code: 'MCA-321', name: 'Project–I (Minor Project)', type: 'Project', credits: 3, weeklyHours: '0+0+3', marks: '100', semester: 3 },

  // --- SEMESTER IV ---
  { code: 'MCA-421', name: 'Project–II (Major Capstone Project)', type: 'Project', credits: 16, weeklyHours: '0+0+24', marks: '400', semester: 4 },
  { code: 'MCA-431', name: 'Grand Viva', type: 'Viva', credits: 8, weeklyHours: '-', marks: '200', semester: 4 },
];

async function seedCleanCurriculum() {
  console.log('🏛️ Setting up clean MCA Department and Syllabus Curriculum...');

  // 1. Create or Find Department
  const mcaDept = await prisma.department.upsert({
    where: { code: 'MCA' },
    create: {
      name: 'Master of Computer Applications (MCA)',
      code: 'MCA',
      latitude: parseFloat(process.env.DEFAULT_DEPT_LATITUDE || '22.5726'),
      longitude: parseFloat(process.env.DEFAULT_DEPT_LONGITUDE || '88.3639'),
      radiusMeters: parseFloat(process.env.DEFAULT_GEOFENCE_RADIUS_METERS || '50.0'),
    },
    update: {
      name: 'Master of Computer Applications (MCA)',
      latitude: parseFloat(process.env.DEFAULT_DEPT_LATITUDE || '22.5726'),
      longitude: parseFloat(process.env.DEFAULT_DEPT_LONGITUDE || '88.3639'),
      radiusMeters: parseFloat(process.env.DEFAULT_GEOFENCE_RADIUS_METERS || '50.0'),
    },
  });

  // 2. Populate all 31 subjects
  for (const item of mcaCurriculum) {
    await prisma.subject.upsert({
      where: {
        code_semester_batchYear: {
          code: item.code,
          semester: item.semester,
          batchYear: '2025-2026',
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
  }

  console.log(`✅ Loaded all 31 official MCA subjects into live cloud database with ZERO mock users!`);
}

seedCleanCurriculum()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
