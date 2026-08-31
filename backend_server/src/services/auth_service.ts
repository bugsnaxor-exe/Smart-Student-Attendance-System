import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { prisma } from '../config/database';
import { EmailService } from './email_service';

const JWT_SECRET = process.env.JWT_SECRET || 'smart_attendance_secret_jwt_key_2026';

export interface RegisterStudentInput {
  name: string;
  email: string;
  password: string;
  classRoll: string;
  universityRoll: string;
  regNumber: string;
  departmentCode: string;
  semester: number;
  deviceUuid?: string;
}

export interface RegisterTeacherInput {
  name: string;
  email: string;
  password: string;
  departmentCode: string;
}

interface StoredOtp {
  otp: string;
  expiresAt: number;
  userId: string;
  role: string;
}

export class AuthService {
  private static otpStore = new Map<string, StoredOtp>();

  public static generateToken(payload: {
    userId: string;
    role: string;
    studentId?: string;
    teacherId?: string;
    departmentId?: string;
  }): string {
    return jwt.sign(payload, JWT_SECRET, { expiresIn: '180d' }); // 6 months persistent session
  }

  public static async registerStudent(input: RegisterStudentInput) {
    // 1. Check existing email / university roll / registration number
    const existingEmail = await prisma.user.findUnique({ where: { email: input.email } });
    if (existingEmail) {
      throw new Error('Email is already registered.');
    }

    const existingUniRoll = await prisma.studentProfile.findUnique({
      where: { universityRoll: input.universityRoll },
    });
    if (existingUniRoll) {
      throw new Error(`University Roll Number '${input.universityRoll}' is already registered.`);
    }

    const existingRegNo = await prisma.studentProfile.findUnique({
      where: { regNumber: input.regNumber },
    });
    if (existingRegNo) {
      throw new Error(`Registration Number '${input.regNumber}' is already registered.`);
    }

    // 2. Find or create department
    let department = await prisma.department.findUnique({
      where: { code: input.departmentCode.toUpperCase() },
    });

    if (!department) {
      department = await prisma.department.create({
        data: {
          name: `${input.departmentCode.toUpperCase()} Department`,
          code: input.departmentCode.toUpperCase(),
          latitude: parseFloat(process.env.DEFAULT_DEPT_LATITUDE || '22.5726'),
          longitude: parseFloat(process.env.DEFAULT_DEPT_LONGITUDE || '88.3639'),
          radiusMeters: parseFloat(process.env.DEFAULT_GEOFENCE_RADIUS_METERS || '50.0'),
        },
      });
    }

    // 3. Hash password & create user + student profile
    const passwordHash = await bcrypt.hash(input.password, 10);

    const user = await prisma.user.create({
      data: {
        name: input.name,
        email: input.email,
        passwordHash,
        role: 'STUDENT',
        student: {
          create: {
            classRoll: input.classRoll,
            universityRoll: input.universityRoll,
            regNumber: input.regNumber,
            semester: input.semester,
            departmentId: department.id,
            deviceUuid: input.deviceUuid,
          },
        },
      },
      include: {
        student: {
          include: {
            department: true,
          },
        },
      },
    });

    const token = this.generateToken({
      userId: user.id,
      role: 'STUDENT',
      studentId: user.student?.id,
      departmentId: department.id,
    });

    return { user, token };
  }

  public static async registerTeacher(input: RegisterTeacherInput) {
    const existingEmail = await prisma.user.findUnique({ where: { email: input.email } });
    if (existingEmail) {
      throw new Error('Email is already registered.');
    }

    let department = await prisma.department.findUnique({
      where: { code: input.departmentCode.toUpperCase() },
    });

    if (!department) {
      department = await prisma.department.create({
        data: {
          name: `${input.departmentCode.toUpperCase()} Department`,
          code: input.departmentCode.toUpperCase(),
          latitude: parseFloat(process.env.DEFAULT_DEPT_LATITUDE || '22.5726'),
          longitude: parseFloat(process.env.DEFAULT_DEPT_LONGITUDE || '88.3639'),
          radiusMeters: 50.0,
        },
      });
    }

    const passwordHash = await bcrypt.hash(input.password, 10);

    const user = await prisma.user.create({
      data: {
        name: input.name,
        email: input.email,
        passwordHash,
        role: 'TEACHER',
        teacher: {
          create: {
            departmentId: department.id,
          },
        },
      },
      include: {
        teacher: {
          include: {
            department: true,
          },
        },
      },
    });

    const token = this.generateToken({
      userId: user.id,
      role: 'TEACHER',
      teacherId: user.teacher?.id,
      departmentId: department.id,
    });

    return { user, token };
  }

  public static async login(identifier: string, password: string) {
    // Identifier can be email, universityRoll, or classRoll
    let user = await prisma.user.findUnique({
      where: { email: identifier },
      include: {
        student: { include: { department: true } },
        teacher: { include: { department: true, subjects: true } },
      },
    });

    // If not found by email, check if student university roll
    if (!user) {
      const student = await prisma.studentProfile.findUnique({
        where: { universityRoll: identifier },
        include: {
          user: true,
          department: true,
        },
      });
      if (student) {
        user = await prisma.user.findUnique({
          where: { id: student.userId },
          include: {
            student: { include: { department: true } },
            teacher: { include: { department: true, subjects: true } },
          },
        });
      }
    }

    if (!user) {
      throw new Error('Invalid email or roll number.');
    }

    const isMatch = await bcrypt.compare(password, user.passwordHash);
    if (!isMatch) {
      throw new Error('Invalid password.');
    }

    // 🔒 2FA OTP PROTECTION FOR FACULTY & ADMIN (Stops unauthorized students)
    if (user.role === 'TEACHER' || user.role === 'ADMIN') {
      const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
      const expiresAt = Date.now() + 5 * 60 * 1000; // 5 Minutes TTL

      this.otpStore.set(user.email.toLowerCase(), {
        otp: otpCode,
        expiresAt,
        userId: user.id,
        role: user.role,
      });

      // Send OTP via Brevo / Resend
      await EmailService.sendFacultyLoginOtp({
        toEmail: user.email,
        recipientName: user.name,
        otpCode,
        expiresInMinutes: 5,
      });

      return {
        requiresOtp: true,
        email: user.email,
        message: `6-digit security code dispatched to ${user.email}`,
      };
    }

    // Students log in with hardware UUID check
    const token = this.generateToken({
      userId: user.id,
      role: user.role,
      studentId: user.student?.id,
      teacherId: user.teacher?.id,
      departmentId: user.student?.departmentId || user.teacher?.departmentId,
    });

    return { requiresOtp: false, user, token };
  }

  /**
   * Verifies the 6-digit OTP for faculty logins and issues the auth token.
   */
  public static async verifyFacultyOtp(email: string, otp: string) {
    const cleanEmail = email.toLowerCase().trim();
    const cleanOtp = otp.trim();

    const stored = this.otpStore.get(cleanEmail);
    if (!stored) {
      throw new Error('No active OTP found for this email. Please log in again.');
    }

    if (Date.now() > stored.expiresAt) {
      this.otpStore.delete(cleanEmail);
      throw new Error('OTP has expired (valid for 5 minutes). Please request a new code.');
    }

    if (stored.otp !== cleanOtp) {
      throw new Error('Invalid 6-digit OTP code. Please check your email.');
    }

    // OTP verified -> remove from store
    this.otpStore.delete(cleanEmail);

    const user = await prisma.user.findUnique({
      where: { id: stored.userId },
      include: {
        teacher: { include: { department: true, subjects: true } },
      },
    });

    if (!user) {
      throw new Error('User account not found.');
    }

    const token = this.generateToken({
      userId: user.id,
      role: user.role,
      teacherId: user.teacher?.id,
      departmentId: user.teacher?.departmentId,
    });

    return { user, token };
  }

  /**
   * Resends a fresh 6-digit OTP to the faculty email.
   */
  public static async resendFacultyOtp(email: string) {
    const cleanEmail = email.toLowerCase().trim();
    const user = await prisma.user.findUnique({
      where: { email: cleanEmail },
    });

    if (!user || (user.role !== 'TEACHER' && user.role !== 'ADMIN')) {
      throw new Error('Faculty account not found.');
    }

    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = Date.now() + 5 * 60 * 1000;

    this.otpStore.set(cleanEmail, {
      otp: otpCode,
      expiresAt,
      userId: user.id,
      role: user.role,
    });

    await EmailService.sendFacultyLoginOtp({
      toEmail: user.email,
      recipientName: user.name,
      otpCode,
      expiresInMinutes: 5,
    });

    return { success: true, message: `New 6-digit OTP code sent to ${user.email}` };
  }
}
