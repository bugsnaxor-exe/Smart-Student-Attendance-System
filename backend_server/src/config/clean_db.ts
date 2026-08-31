import { prisma } from './database';

async function cleanDatabase() {
  console.log('🧹 Cleaning demo accounts and dummy attendance data...');

  // Delete all mock attendance records and active sessions
  await prisma.attendanceRecord.deleteMany({});
  await prisma.activeSession.deleteMany({});

  // Delete student and teacher profiles
  await prisma.studentProfile.deleteMany({});
  await prisma.teacherProfile.deleteMany({});

  // Delete all demo users
  await prisma.user.deleteMany({});

  console.log('✨ All demo accounts, mock student profiles, and dummy attendance records have been permanently cleared!');
  console.log('🚀 The database is now 100% clean and ready for real students & faculty to register and log in.');
}

cleanDatabase()
  .catch((e) => {
    console.error('❌ Error cleaning database:', e);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
