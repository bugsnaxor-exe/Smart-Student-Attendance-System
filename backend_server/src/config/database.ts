import { PrismaClient } from '@prisma/client';
import { autoBootstrapDatabase } from './auto_bootstrap';

export const prisma = new PrismaClient();

export async function connectDB() {
  try {
    await prisma.$connect();
    console.log('✅ SQLite/PostgreSQL Database connected successfully via Prisma.');
    await autoBootstrapDatabase();
  } catch (error) {
    console.error('❌ Failed to connect to database:', error);
  }
}
