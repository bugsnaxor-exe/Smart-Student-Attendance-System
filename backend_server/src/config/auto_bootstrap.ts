import { prisma } from './database';

export const ALL_MCA_SUBJECTS = [
  // Semester 1
  { code: 'MCA-101', name: 'Mathematical Foundation', type: 'Theory', credits: 4, semester: 1 },
  { code: 'MCA-102', name: 'Data Structures with C / Python', type: 'Theory', credits: 4, semester: 1 },
  { code: 'MCA-103', name: 'Computer Organization and Architecture', type: 'Theory', credits: 4, semester: 1 },
  { code: 'MCA-104', name: 'Discrete Mathematics', type: 'Theory', credits: 4, semester: 1 },
  { code: 'MCA-105', name: 'Principles of Management & Accounting', type: 'Theory', credits: 4, semester: 1 },
  { code: 'MCA-111', name: 'Data Structures Laboratory', type: 'Practical', credits: 3, semester: 1 },
  { code: 'MCA-112', name: 'Programming Practice Laboratory', type: 'Practical', credits: 3, semester: 1 },
  { code: 'MCA-113', name: 'Digital Electronics & Microprocessor Lab', type: 'Practical', credits: 3, semester: 1 },
  { code: 'MCA-114', name: 'Business Communication & Soft Skills Lab', type: 'Practical', credits: 3, semester: 1 },
  { code: 'MCA-121', name: 'Bridge Course in Computer Fundamentals', type: 'Bridge Course', credits: 2, semester: 1 },

  // Semester 2
  { code: 'MCA-201', name: 'Design and Analysis of Algorithms', type: 'Theory', credits: 4, semester: 2 },
  { code: 'MCA-202', name: 'Object Oriented Programming with Java', type: 'Theory', credits: 4, semester: 2 },
  { code: 'MCA-203', name: 'Database Management Systems', type: 'Theory', credits: 4, semester: 2 },
  { code: 'MCA-204', name: 'Operating Systems', type: 'Theory', credits: 4, semester: 2 },
  { code: 'MCA-205', name: 'Scientific Computing', type: 'Theory', credits: 4, semester: 2 },
  { code: 'MCA-211', name: 'Object Oriented Programming Laboratory', type: 'Practical', credits: 3, semester: 2 },
  { code: 'MCA-212', name: 'Database Management Systems Laboratory', type: 'Practical', credits: 3, semester: 2 },
  { code: 'MCA-213', name: 'Scientific Computing Laboratory', type: 'Practical', credits: 3, semester: 2 },
  { code: 'MCA-214', name: 'Advanced Programming Laboratory–I', type: 'Practical', credits: 3, semester: 2 },

  // Semester 3
  { code: 'MCA-301', name: 'Artificial Intelligence', type: 'Theory', credits: 4, semester: 3 },
  { code: 'MCA-302', name: 'Computer Networks', type: 'Theory', credits: 4, semester: 3 },
  { code: 'MCA-303', name: 'Software Engineering', type: 'Theory', credits: 4, semester: 3 },
  { code: 'MCA-304', name: 'Elective – I (Cloud Computing / ML)', type: 'Theory', credits: 4, semester: 3 },
  { code: 'MCA-305', name: 'Elective – II (Cyber Security)', type: 'Theory', credits: 4, semester: 3 },
  { code: 'MCA-306', name: 'Elective – III (Mobile Computing)', type: 'Theory', credits: 4, semester: 3 },
  { code: 'MCA-311', name: 'Artificial Intelligence Laboratory', type: 'Practical', credits: 3, semester: 3 },
  { code: 'MCA-312', name: 'Web-based Programming Laboratory', type: 'Practical', credits: 3, semester: 3 },
  { code: 'MCA-313', name: 'Advanced Programming Laboratory-II', type: 'Practical', credits: 3, semester: 3 },
  { code: 'MCA-321', name: 'Project–I (Minor Project)', type: 'Project', credits: 3, semester: 3 },

  // Semester 4
  { code: 'MCA-421', name: 'Project–II (Major Capstone Project)', type: 'Project', credits: 16, semester: 4 },
  { code: 'MCA-431', name: 'Grand Viva', type: 'Viva', credits: 8, semester: 4 },
];

export const UNIVERSITY_DEPARTMENTS = [
  { code: 'MCA', name: 'Master of Computer Applications (MCA)' },
  { code: 'MCS', name: 'Master of Computer Science (MCS)' },
  { code: 'MDS', name: 'Master of Data Science (MDS)' },
  { code: 'MTECH', name: 'Master in Technology (M.Tech)' },
  { code: 'MSC', name: 'Master in Science (M.Sc)' },
  { code: 'BTECH', name: 'Bachelor in Technology (B.Tech)' },
];

export async function autoBootstrapDatabase() {
  try {
    console.log('🔄 [Bootstrap] Checking and initializing database state...');

    // 1. Rename any legacy department codes if present
    const legacyMigrations = [
      { oldCode: 'MSCCS', newCode: 'MCS', newName: 'Master of Computer Science (MCS)' },
      { oldCode: 'MSCDS', newCode: 'MDS', newName: 'Master of Data Science (MDS)' },
      { oldCode: 'BSC', newCode: 'BTECH', newName: 'Bachelor in Technology (B.Tech)' },
    ];

    for (const leg of legacyMigrations) {
      const oldDept = await prisma.department.findUnique({ where: { code: leg.oldCode } });
      if (oldDept) {
        await prisma.department.update({
          where: { code: leg.oldCode },
          data: { code: leg.newCode, name: leg.newName },
        });
        console.log(`🔄 [Bootstrap] Migrated legacy department ${leg.oldCode} -> ${leg.newCode} (${leg.newName})`);
      }
    }

    // 2. Ensure all University Departments exist
    const defaultLat = parseFloat(process.env.DEFAULT_DEPT_LATITUDE || '22.5726');
    const defaultLng = parseFloat(process.env.DEFAULT_DEPT_LONGITUDE || '88.3639');
    const defaultRadius = parseFloat(process.env.DEFAULT_GEOFENCE_RADIUS_METERS || '50.0');

    let mcaDeptId = '';

    for (const dept of UNIVERSITY_DEPARTMENTS) {
      const existing = await prisma.department.findUnique({
        where: { code: dept.code },
      });

      if (!existing) {
        const created = await prisma.department.create({
          data: {
            code: dept.code,
            name: dept.name,
            latitude: defaultLat,
            longitude: defaultLng,
            radiusMeters: defaultRadius,
          },
        });
        if (dept.code === 'MCA') mcaDeptId = created.id;
        console.log(`✅ [Bootstrap] Created department anchor: ${dept.name} [${dept.code}]`);
      } else {
        await prisma.department.update({
          where: { code: dept.code },
          data: { name: dept.name },
        });
        if (dept.code === 'MCA') mcaDeptId = existing.id;
      }
    }

    // 2. Ensure all 31 MCA subjects exist
    for (const subj of ALL_MCA_SUBJECTS) {
      await prisma.subject.upsert({
        where: {
          code_semester_batchYear: {
            code: subj.code,
            semester: subj.semester,
            batchYear: '2025-2026',
          },
        },
        update: {
          name: subj.name,
          type: subj.type,
          credits: subj.credits,
          departmentId: mcaDeptId,
        },
        create: {
          code: subj.code,
          name: subj.name,
          type: subj.type,
          credits: subj.credits,
          semester: subj.semester,
          batchYear: '2025-2026',
          departmentId: mcaDeptId,
        },
      });
    }
    console.log(`✅ [Bootstrap] Verified and synced all ${ALL_MCA_SUBJECTS.length} MCA curriculum subjects.`);

    // 3. Ensure Sayantan Dasgupta Admin account exists and has role ADMIN
    const defaultPasswordHash = '$2a$10$WCRNbFWPdYheHWNkP/FXOO1Eg3Z5UXyu498/1NU9SSTOOPSpKoCD6';
    const adminEmails = [
      'sayantan05072004@gmail.com',
      'sayantan.faculty@smartattend.edu',
    ];

    for (const email of adminEmails) {
      const existing = await prisma.user.findUnique({
        where: { email },
        include: { teacher: true },
      });

      if (!existing) {
        await prisma.user.create({
          data: {
            name: 'Sayantan Dasgupta',
            email,
            passwordHash: defaultPasswordHash,
            role: 'ADMIN',
            teacher: {
              create: {
                departmentId: mcaDeptId,
              },
            },
          },
        });
        console.log(`✅ [Bootstrap] Initialized Admin User: ${email}`);
      } else {
        if (existing.role !== 'ADMIN' || !existing.teacher) {
          await prisma.user.update({
            where: { id: existing.id },
            data: {
              role: 'ADMIN',
              ...(existing.teacher ? {} : { teacher: { create: { departmentId: mcaDeptId } } }),
            },
          });
          console.log(`✅ [Bootstrap] Upgraded ${email} to permanent ADMIN role.`);
        }
      }
    }

    // 4. Ensure all Admin accounts and existing verified teachers are approved
    const adminUsers = await prisma.user.findMany({
      where: {
        OR: [
          { role: 'ADMIN' },
          { email: { in: adminEmails } },
        ],
      },
      select: { id: true },
    });
    const adminUserIds = adminUsers.map((u) => u.id);
    if (adminUserIds.length > 0) {
      await prisma.teacherProfile.updateMany({
        where: {
          userId: { in: adminUserIds },
        },
        data: { isApproved: true, approvedAt: new Date() },
      });
    }

    console.log('🚀 [Bootstrap] Database successfully verified and ready.');
  } catch (err: any) {
    console.error('⚠️ [Bootstrap Error] Could not auto-bootstrap database:', err.message);
  }
}
