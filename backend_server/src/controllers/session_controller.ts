import { Response } from 'express';
import { AuthRequest } from '../middleware/auth_middleware';
import { SessionService } from '../services/session_service';
import { prisma } from '../config/database';

type SessionBroadcastCallback = (data: any) => void;
let sessionBroadcastCallback: SessionBroadcastCallback | null = null;

export function registerSessionBroadcaster(callback: SessionBroadcastCallback) {
  sessionBroadcastCallback = callback;
}

// Complete MCA Curriculum Catalog for all 4 Semesters
const MCA_CATALOG: Record<string, { name: string; semester: number }> = {
  'MCA-101': { name: 'Mathematical Foundation', semester: 1 },
  'MCA-102': { name: 'Data and File Structures', semester: 1 },
  'MCA-103': { name: 'Computer Organization & Arch', semester: 1 },
  'MCA-104': { name: 'Microprocessor & Applications', semester: 1 },
  'MCA-105': { name: 'Management Functions', semester: 1 },
  'MCA-111': { name: 'Communicative English Lab', semester: 1 },
  'MCA-112': { name: 'DFS Lab with C', semester: 1 },
  'MCA-113': { name: 'Digital Circuits Lab', semester: 1 },
  'MCA-114': { name: 'Microprocessor Lab', semester: 1 },
  'MCA-141*': { name: 'Intro to Computing & C (Bridge)', semester: 1 },
  'MCA-201': { name: 'Design & Analysis of Algorithms', semester: 2 },
  'MCA-202': { name: 'Object Oriented Programming', semester: 2 },
  'MCA-203': { name: 'Database Management Systems', semester: 2 },
  'MCA-204': { name: 'Operating Systems', semester: 2 },
  'MCA-205': { name: 'Scientific Computing', semester: 2 },
  'MCA-211': { name: 'OOP Laboratory', semester: 2 },
  'MCA-212': { name: 'DBMS Laboratory', semester: 2 },
  'MCA-213': { name: 'Scientific Computing Lab', semester: 2 },
  'MCA-214': { name: 'Advanced Programming Lab–I', semester: 2 },
  'MCA-301': { name: 'Artificial Intelligence', semester: 3 },
  'MCA-302': { name: 'Computer Networks', semester: 3 },
  'MCA-303': { name: 'Software Engineering', semester: 3 },
  'MCA-304': { name: 'Elective – I (Cloud / ML)', semester: 3 },
  'MCA-305': { name: 'Elective – II (Cyber Security)', semester: 3 },
  'MCA-306': { name: 'Elective – III (Mobile Computing)', semester: 3 },
  'MCA-311': { name: 'AI Laboratory', semester: 3 },
  'MCA-312': { name: 'Web-based Programming Lab', semester: 3 },
  'MCA-313': { name: 'Advanced Programming Lab-II', semester: 3 },
  'MCA-321': { name: 'Minor Project–I', semester: 3 },
  'MCA-421': { name: 'Major Capstone Project–II', semester: 4 },
  'MCA-431': { name: 'Grand Viva Voce', semester: 4 },
};

export class SessionController {
  /**
   * Teacher starts a 15-minute active session for a subject.
   * Auto-resolves subject or creates if not yet in database.
   */
  public static async startSession(req: AuthRequest, res: Response) {
    try {
      const { subjectId, durationMinutes = 15, latitude, longitude, radiusMeters = 50.0 } = req.body;
      const parsedLat = latitude !== undefined && latitude !== null && !isNaN(parseFloat(latitude)) ? parseFloat(latitude) : undefined;
      const parsedLng = longitude !== undefined && longitude !== null && !isNaN(parseFloat(longitude)) ? parseFloat(longitude) : undefined;
      const parsedRadius = radiusMeters !== undefined && radiusMeters !== null && !isNaN(parseFloat(radiusMeters)) ? parseFloat(radiusMeters) : 50.0;

      if (!subjectId) {
        return res.status(400).json({ error: 'subjectId is required.' });
      }

      const cleanCode = String(subjectId).trim();

      // Find or create subject
      let subject = await prisma.subject.findFirst({
        where: {
          OR: [
            { id: cleanCode },
            { code: { equals: cleanCode, mode: 'insensitive' } },
            { code: { equals: cleanCode.replace('*', ''), mode: 'insensitive' } },
          ],
        },
      });

      // Resolve valid teacherProfile from database
      let teacherProfile = null;
      if (req.user?.teacherId) {
        teacherProfile = await prisma.teacherProfile.findUnique({
          where: { id: req.user.teacherId },
        });
      }
      if (!teacherProfile && req.user?.userId) {
        teacherProfile = await prisma.teacherProfile.findUnique({
          where: { userId: req.user.userId },
        });
        if (!teacherProfile) {
          let mcaDept = await prisma.department.findFirst();
          if (!mcaDept) {
            mcaDept = await prisma.department.create({
              data: {
                name: 'Master of Computer Applications (MCA)',
                code: 'MCA',
                latitude: 22.5726,
                longitude: 88.3639,
                radiusMeters: 50.0,
              },
            });
          }
          teacherProfile = await prisma.teacherProfile.create({
            data: {
              userId: req.user.userId,
              departmentId: mcaDept.id,
            },
          });
        }
      }
      if (!teacherProfile) {
        teacherProfile = await prisma.teacherProfile.findFirst({
          include: { user: true },
        });
      }

      // If database has 0 teachers (fresh reset), auto-create the official Faculty profile
      if (!teacherProfile) {
        let mcaDept = await prisma.department.findFirst({
          where: {
            OR: [
              { code: 'MCA' },
              { name: { contains: 'Computer Applications', mode: 'insensitive' } },
            ],
          },
        });
        if (!mcaDept) {
          mcaDept = await prisma.department.create({
            data: {
              name: 'Master of Computer Applications (MCA)',
              code: 'MCA',
              latitude: 22.5726,
              longitude: 88.3639,
              radiusMeters: 50.0,
            },
          });
        }

        let facultyUser = await prisma.user.findFirst({
          where: { role: 'TEACHER' },
        });
        if (!facultyUser) {
          const bcrypt = require('bcryptjs');
          const defaultPw = await bcrypt.hash('password123', 10);
          facultyUser = await prisma.user.create({
            data: {
              name: 'Sayantan Dasgupta',
              email: 'sayantan.faculty@smartattend.edu',
              passwordHash: defaultPw,
              role: 'TEACHER',
            },
          });
        }

        teacherProfile = await prisma.teacherProfile.create({
          data: {
            userId: facultyUser.id,
            departmentId: mcaDept.id,
          },
        });
      }

      const teacherId = teacherProfile.id;
      const teacherUser = await prisma.user.findUnique({ where: { id: teacherProfile.userId } });
      const userEmail = (teacherUser?.email || '').toLowerCase().trim();
      const isSuperAdmin = req.user?.role === 'ADMIN' || teacherUser?.role === 'ADMIN' || ['sayantan05072004@gmail.com', 'sayantan.faculty@smartattend.edu'].includes(userEmail);

      // Check if non-admin teacher is approved
      if (!isSuperAdmin && teacherProfile && !teacherProfile.isApproved) {
        return res.status(403).json({
          error: 'Your faculty account is pending verification and approval by the Administrator / HOD.',
        });
      }

      // If subject doesn't exist in DB, auto-create it from catalog
      if (!subject) {
        const catalogEntry = MCA_CATALOG[cleanCode] || MCA_CATALOG[cleanCode.toUpperCase()] || {
          name: cleanCode,
          semester: 3,
        };

        let mcaDept = await prisma.department.findFirst({
          where: {
            OR: [
              { code: 'MCA' },
              { name: { contains: 'Computer Applications', mode: 'insensitive' } },
            ],
          },
        });

        const deptId = mcaDept ? mcaDept.id : (await prisma.department.findFirst())?.id;
        if (!deptId) {
          return res.status(500).json({ error: 'No department found to attach subject.' });
        }

        subject = await prisma.subject.create({
          data: {
            code: cleanCode,
            name: catalogEntry.name,
            semester: catalogEntry.semester,
            departmentId: deptId,
            teacherId,
          },
        });
      }

      // Check subject assignment lock for regular faculty
      if (!isSuperAdmin && teacherProfile) {
        const assignedSubjects = await prisma.subject.findMany({
          where: { teacherId: teacherProfile.id },
        });
        const isAssigned = assignedSubjects.some(
          (s) => s.id === subject!.id || s.code.toLowerCase() === cleanCode.toLowerCase()
        );
        if (!isAssigned) {
          const assignedNames = assignedSubjects.map((s) => s.code).join(', ') || 'None';
          return res.status(403).json({
            error: `Access Denied: You are only authorized to start attendance sessions for your assigned subject (${assignedNames}). Global catalog access is restricted to Administrators.`,
          });
        }
      }

      // If super admin and subject has no teacher assigned yet, attach teacher
      if (isSuperAdmin && !subject.teacherId) {
        try {
          await prisma.subject.update({
            where: { id: subject.id },
            data: { teacherId },
          });
        } catch (err) {
          console.warn('Could not assign subject teacher:', err);
        }
      }

      const session = await SessionService.startSession(
        subject.id,
        teacherId,
        subject.semester,
        durationMinutes,
        parsedLat,
        parsedLng,
        parsedRadius
      );

      // Save teacher's last detected location
      if (teacherId && parsedLat !== undefined && parsedLng !== undefined) {
        await prisma.teacherProfile.update({
          where: { id: teacherId },
          data: {
            lastLatitude: parsedLat,
            lastLongitude: parsedLng,
            lastLocationAt: new Date(),
          },
        }).catch(() => {});
      }

      // Broadcast SESSION_STARTED to all WebSocket clients (Web + Mobile)
      if (sessionBroadcastCallback) {
        sessionBroadcastCallback({
          type: 'SESSION_STARTED',
          session: {
            id: session.id,
            subjectId: session.subjectId,
            subjectName: session.subject.name,
            subjectCode: session.subject.code,
            semester: session.semester,
            remainingSeconds: durationMinutes * 60,
            expiresAt: session.expiresAt.toISOString(),
            latitude: session.latitude,
            longitude: session.longitude,
            radiusMeters: session.radiusMeters,
          },
        });
      }

      const sessionsConductedToday = await SessionService.getTodaySessionsCount(subject.id);

      return res.status(201).json({
        message: `Attendance session started for ${subject.name} (${subject.code}). Auto-expires in ${durationMinutes} minutes.`,
        sessionsConductedToday,
        remainingDailySessions: Math.max(0, 3 - sessionsConductedToday),
        maxDailySessions: 3,
        session: {
          ...session,
          remainingSeconds: durationMinutes * 60,
        },
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }

  /**
   * Get active session for a subject by ID or Course Code (includes live attendee list and remaining seconds).
   */
  public static async getActiveSession(req: AuthRequest, res: Response) {
    try {
      const { subjectId } = req.params;
      const cleanCode = subjectId ? subjectId.trim() : '';

      const session = await SessionService.getActiveSession(cleanCode);
      const sessionsConductedToday = await SessionService.getTodaySessionsCount(cleanCode);

      if (!session) {
        return res.json({
          isActive: false,
          session: null,
          remainingSeconds: 0,
          sessionsConductedToday,
          remainingDailySessions: Math.max(0, 3 - sessionsConductedToday),
          maxDailySessions: 3,
          message: 'No active session found or session has expired.',
        });
      }

      const now = new Date();
      const remainingSeconds = Math.max(0, Math.floor((session.expiresAt.getTime() - now.getTime()) / 1000));

      return res.json({
        isActive: true,
        remainingSeconds,
        sessionsConductedToday,
        remainingDailySessions: Math.max(0, 3 - sessionsConductedToday),
        maxDailySessions: 3,
        session: {
          id: session.id,
          subjectId: session.subjectId,
          subjectCode: session.subject.code,
          subjectName: session.subject.name,
          semester: session.semester,
          createdAt: session.createdAt,
          expiresAt: session.expiresAt,
          attendances: session.attendances,
        },
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }

  /**
   * Returns today's conducted session counts across all subjects.
   */
  public static async getTodayCounts(req: AuthRequest, res: Response) {
    try {
      const counts = await SessionService.getAllTodaySessionCounts();
      return res.json({
        counts,
        maxDailyLimit: 3,
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }

  /**
   * Get all live active sessions available for a student's semester & department.
   */
  public static async getStudentActiveSessions(req: AuthRequest, res: Response) {
    try {
      let student = null;
      if (req.user?.studentId) {
        student = await prisma.studentProfile.findUnique({
          where: { id: req.user.studentId },
        });
      }
      if (!student && req.user?.userId) {
        student = await prisma.studentProfile.findFirst({
          where: { userId: req.user.userId },
        });
      }
      if (!student) {
        student = await prisma.studentProfile.findFirst({
          orderBy: { createdAt: 'desc' },
        });
      }

      if (!student) {
        return res.json({ sessions: [] });
      }

      const activeSessions = await SessionService.getActiveSessionsForStudent(
        student.semester,
        student.departmentId
      );

      // Check if student has already marked attendance for each session
      const studentSessionAttendances = await prisma.attendanceRecord.findMany({
        where: {
          studentId: student.id,
          sessionId: { in: activeSessions.map((s) => s.id) },
        },
      });

      const markedSessionIds = new Set(studentSessionAttendances.map((a) => a.sessionId));

      const sessionsWithMarkedStatus = activeSessions.map((sess) => {
        const remainingSeconds = Math.max(0, Math.floor((sess.expiresAt.getTime() - new Date().getTime()) / 1000));
        return {
          id: sess.id,
          subjectId: sess.subjectId,
          subjectName: sess.subject.name,
          subjectCode: sess.subject.code,
          teacherName: sess.subject.teacher?.user?.name || 'Faculty',
          semester: sess.semester,
          isActive: sess.isActive,
          createdAt: sess.createdAt,
          expiresAt: sess.expiresAt,
          isAlreadyMarked: markedSessionIds.has(sess.id),
          remainingSeconds,
          latitude: sess.latitude,
          longitude: sess.longitude,
          radiusMeters: sess.radiusMeters,
        };
      });

      return res.json({
        sessions: sessionsWithMarkedStatus,
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }

  /**
   * Admin-Only: Manually closes active session by Session ID.
   */
  public static async closeSession(req: AuthRequest, res: Response) {
    try {
      // Security Check: Only Admin (Sayantan Dasgupta) can terminate sessions manually
      const user = req.user?.userId ? await prisma.user.findUnique({ where: { id: req.user.userId } }) : null;
      const isAdmin = req.user?.role === 'ADMIN' || user?.role === 'ADMIN' || user?.email?.toLowerCase() === 'sayantan05072004@gmail.com';

      if (!isAdmin) {
        return res.status(403).json({
          error: 'Forbidden: Active sessions run for the full 15-minute duration. Only the Administrator (Sayantan Dasgupta) can terminate sessions manually.',
        });
      }

      const { sessionId } = req.params;
      const session = await SessionService.closeSession(sessionId);

      // Broadcast SESSION_STOPPED to all clients
      if (sessionBroadcastCallback) {
        sessionBroadcastCallback({
          type: 'SESSION_STOPPED',
          sessionId: session.id,
          subjectId: session.subjectId,
        });
      }

      return res.json({
        message: 'Attendance session closed by Administrator.',
        session,
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }

  /**
   * Admin-Only: Manually closes active session by Course Code / Subject ID.
   */
  public static async closeSessionBySubject(req: AuthRequest, res: Response) {
    try {
      const user = req.user?.userId ? await prisma.user.findUnique({ where: { id: req.user.userId } }) : null;
      const isAdmin = req.user?.role === 'ADMIN' || user?.role === 'ADMIN' || user?.email?.toLowerCase() === 'sayantan05072004@gmail.com';

      if (!isAdmin) {
        return res.status(403).json({
          error: 'Forbidden: Active sessions run for the full 15-minute duration. Only the Administrator (Sayantan Dasgupta) can terminate sessions manually.',
        });
      }

      const { subjectId } = req.params;
      const cleanCode = subjectId ? subjectId.trim() : '';

      const subject = await prisma.subject.findFirst({
        where: {
          OR: [
            { id: cleanCode },
            { code: { equals: cleanCode, mode: 'insensitive' } },
            { code: { equals: cleanCode.replace('*', ''), mode: 'insensitive' } },
          ],
        },
      });

      if (!subject) {
        return res.status(404).json({ error: 'Subject not found.' });
      }

      await prisma.activeSession.updateMany({
        where: {
          subjectId: subject.id,
          isActive: true,
        },
        data: {
          isActive: false,
        },
      });

      // Broadcast SESSION_STOPPED to all clients
      if (sessionBroadcastCallback) {
        sessionBroadcastCallback({
          type: 'SESSION_STOPPED',
          subjectId: subject.id,
          subjectCode: subject.code,
        });
      }

      return res.json({
        success: true,
        message: `Attendance session for ${subject.code} terminated by Administrator.`,
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }

  /**
   * Teacher manually updates or detects location for ongoing or future sessions.
   */
  public static async updateLocation(req: AuthRequest, res: Response) {
    try {
      const { subjectId, sessionId, latitude, longitude, radiusMeters = 50.0 } = req.body;

      if (latitude === undefined || longitude === undefined || isNaN(parseFloat(latitude)) || isNaN(parseFloat(longitude))) {
        return res.status(400).json({ error: 'Valid latitude and longitude are required.' });
      }

      const parsedLat = parseFloat(latitude);
      const parsedLng = parseFloat(longitude);
      const parsedRadius = parseFloat(radiusMeters) || 50.0;

      let targetSession = null;
      if (sessionId) {
        targetSession = await prisma.activeSession.findUnique({
          where: { id: sessionId },
        });
      }

      if (!targetSession && subjectId) {
        targetSession = await SessionService.getActiveSession(subjectId);
      }

      if (targetSession) {
        targetSession = await prisma.activeSession.update({
          where: { id: targetSession.id },
          data: {
            latitude: parsedLat,
            longitude: parsedLng,
            radiusMeters: parsedRadius,
          },
          include: {
            subject: true,
          },
        });
      }

      // If teacher profile exists, update profile
      const teacherId = req.user?.teacherId;
      if (teacherId) {
        await prisma.teacherProfile.update({
          where: { id: teacherId },
          data: {
            lastLatitude: parsedLat,
            lastLongitude: parsedLng,
            lastLocationAt: new Date(),
          },
        }).catch(() => {});
      }

      return res.json({
        success: true,
        message: 'Location updated successfully.',
        latitude: parsedLat,
        longitude: parsedLng,
        radiusMeters: parsedRadius,
        session: targetSession,
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }
}
