import { Request, Response } from 'express';
import { AuthService } from '../services/auth_service';
import { prisma } from '../config/database';
import { AuthRequest } from '../middleware/auth_middleware';

export class AuthController {
  public static async registerStudent(req: Request, res: Response) {
    try {
      const { name, email, password, classRoll, universityRoll, regNumber, departmentCode, semester, deviceUuid } =
        req.body;

      if (!name || !email || !password || !classRoll || !universityRoll || !regNumber || !departmentCode || !semester) {
        return res.status(400).json({ error: 'All fields including Class Roll, University Roll, Reg No, and Semester are required.' });
      }

      const result = await AuthService.registerStudent({
        name,
        email,
        password,
        classRoll,
        universityRoll,
        regNumber,
        departmentCode,
        semester: parseInt(semester, 10),
        deviceUuid,
      });

      return res.status(201).json({
        message: 'Student registration successful.',
        token: result.token,
        user: {
          id: result.user.id,
          name: result.user.name,
          email: result.user.email,
          role: result.user.role,
          student: result.user.student,
        },
      });
    } catch (error: any) {
      return res.status(400).json({ error: error.message });
    }
  }

  public static async registerTeacher(req: Request, res: Response) {
    try {
      const { name, email, password, departmentCode } = req.body;

      if (!name || !email || !password || !departmentCode) {
        return res.status(400).json({ error: 'Name, email, password, and departmentCode are required.' });
      }

      const result = await AuthService.registerTeacher({
        name,
        email,
        password,
        departmentCode,
      });

      return res.status(201).json({
        message: 'Teacher registration successful.',
        token: result.token,
        user: {
          id: result.user.id,
          name: result.user.name,
          email: result.user.email,
          role: result.user.role,
          teacher: result.user.teacher,
        },
      });
    } catch (error: any) {
      return res.status(400).json({ error: error.message });
    }
  }

  public static async login(req: Request, res: Response) {
    try {
      const identifier = (req.body.identifier || req.body.email || req.body.rollNumber || req.body.universityRoll || '').trim();
      const password = req.body.password;

      if (!identifier || !password) {
        return res.status(400).json({ error: 'Email/Roll Number and Password are required.' });
      }

      const result = await AuthService.login(identifier, password);

      if (result.requiresOtp) {
        return res.json({
          requiresOtp: true,
          email: result.email,
          message: result.message,
        });
      }

      return res.json({
        requiresOtp: false,
        message: 'Login successful.',
        token: result.token,
        user: {
          id: result.user!.id,
          name: result.user!.name,
          email: result.user!.email,
          role: result.user!.role,
          student: result.user!.student,
          teacher: result.user!.teacher,
        },
      });
    } catch (error: any) {
      return res.status(401).json({ error: error.message });
    }
  }

  public static async verifyOtp(req: Request, res: Response) {
    try {
      const { email, otp } = req.body;

      if (!email || !otp) {
        return res.status(400).json({ error: 'Email and 6-digit OTP code are required.' });
      }

      const result = await AuthService.verifyFacultyOtp(email, otp);

      return res.json({
        message: '2FA Verification successful. Access granted.',
        token: result.token,
        user: {
          id: result.user.id,
          name: result.user.name,
          email: result.user.email,
          role: result.user.role,
          teacher: result.user.teacher,
        },
      });
    } catch (error: any) {
      return res.status(401).json({ error: error.message });
    }
  }

  public static async resendOtp(req: Request, res: Response) {
    try {
      const { email } = req.body;

      if (!email) {
        return res.status(400).json({ error: 'Email is required.' });
      }

      const result = await AuthService.resendFacultyOtp(email);

      return res.json(result);
    } catch (error: any) {
      return res.status(400).json({ error: error.message });
    }
  }

  public static async getMe(req: AuthRequest, res: Response) {
    try {
      if (!req.user) {
        return res.status(401).json({ error: 'Not authenticated.' });
      }

      const user = await prisma.user.findUnique({
        where: { id: req.user.userId },
        include: {
          student: {
            include: {
              department: true,
            },
          },
          teacher: {
            include: {
              department: true,
              subjects: true,
            },
          },
        },
      });

      if (!user) {
        return res.status(404).json({ error: 'User not found.' });
      }

      return res.json({ user });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }
}
