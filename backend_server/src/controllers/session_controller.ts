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
      const { subjectId, durationMinutes = 15 } = req.body;

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

      let teacherId = req.user?.teacherId;
      if (!teacherId) {
        const anyTeacher = await prisma.teacherProfile.findFirst({
          include: { user: true },
        });
        if (anyTeacher) {
          teacherId = anyTeacher.id;
        }
      }

      if (!teacherId) {
        return res.status(403).json({ error: 'Only registered teachers can start an attendance session.' });
      }

      // If subject doesn't exist in DB, auto-create it from catalog
      if (!subject) {
        const catalogEntry = MCA_CATALOG[cleanCode] || MCA_CATALOG[cleanCode.toUpperCase()] || {
          name: cleanCode,
          semester: 3,
        };

        const mcaDept = await prisma.department.findFirst({
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

      if (subject.teacherId && subject.teacherId !== teacherId && req.user?.role !== 'ADMIN') {
        await prisma.subject.update({
          where: { id: subject.id },
          data: { teacherId },
        });
      } else if (!subject.teacherId && teacherId) {
        await prisma.subject.update({
          where: { id: subject.id },
          data: { teacherId },
        });
      }

      const session = await SessionService.startSession(
        subject.id,
        teacherId,
        subject.semester,
        durationMinutes
      );

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
          },
        });
      }

      return res.status(201).json({
        message: `Attendance session started for ${subject.name} (${subject.code}). Auto-expires in ${durationMinutes} minutes.`,
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

      if (!session) {
        return res.json({
          isActive: false,
          session: null,
          remainingSeconds: 0,
          message: 'No active session found or session has expired.',
        });
      }

      const now = new Date();
      const remainingSeconds = Math.max(0, Math.floor((session.expiresAt.getTime() - now.getTime()) / 1000));

      return res.json({
        isActive: true,
        remainingSeconds,
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
   * Teacher manually closes active session by Session ID.
   */
  public static async closeSession(req: AuthRequest, res: Response) {
    try {
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
        message: 'Attendance session closed.',
        session,
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }

  /**
   * Teacher manually closes active session by Course Code / Subject ID.
   */
  public static async closeSessionBySubject(req: AuthRequest, res: Response) {
    try {
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
        message: `Active session for ${subject.name} (${subject.code}) stopped.`,
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }
}
