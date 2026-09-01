import { Response } from 'express';
import { AuthRequest } from '../middleware/auth_middleware';
import { SessionService } from '../services/session_service';
import { prisma } from '../config/database';

type SessionBroadcastCallback = (data: any) => void;
let sessionBroadcastCallback: SessionBroadcastCallback | null = null;

export function registerSessionBroadcaster(callback: SessionBroadcastCallback) {
  sessionBroadcastCallback = callback;
}

export class SessionController {
  /**
   * Teacher starts a 15-minute active session for a subject.
   */
  public static async startSession(req: AuthRequest, res: Response) {
    try {
      const { subjectId, durationMinutes = 15 } = req.body;

      if (!subjectId) {
        return res.status(400).json({ error: 'subjectId is required.' });
      }

      const subject = await prisma.subject.findFirst({
        where: {
          OR: [
            { id: subjectId },
            { code: { equals: subjectId, mode: 'insensitive' } },
          ],
        },
      });

      if (!subject) {
        return res.status(404).json({ error: 'Subject not found.' });
      }

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

      if (subject.teacherId && subject.teacherId !== teacherId && req.user?.role !== 'ADMIN') {
        // Allow faculty to start session
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
          },
        });
      }

      return res.status(201).json({
        message: `Attendance session started for ${subject.name}. Auto-expires in ${durationMinutes} minutes.`,
        session,
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }

  /**
   * Get active session for a subject (includes live attendee list).
   */
  public static async getActiveSession(req: AuthRequest, res: Response) {
    try {
      const { subjectId } = req.params;

      const session = await SessionService.getActiveSession(subjectId);

      if (!session) {
        return res.json({
          isActive: false,
          session: null,
          message: 'No active session found or session has expired.',
        });
      }

      const now = new Date();
      const remainingSeconds = Math.max(0, Math.floor((session.expiresAt.getTime() - now.getTime()) / 1000));

      return res.json({
        isActive: true,
        remainingSeconds,
        session,
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
      const studentId = req.user?.studentId;
      if (!studentId) {
        return res.status(400).json({ error: 'Student profile not found.' });
      }

      const student = await prisma.studentProfile.findUnique({
        where: { id: studentId },
      });

      if (!student) {
        return res.status(404).json({ error: 'Student not found.' });
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
          ...sess,
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
   * Teacher manually closes active session.
   */
  public static async closeSession(req: AuthRequest, res: Response) {
    try {
      const { sessionId } = req.params;
      const session = await SessionService.closeSession(sessionId);
      return res.json({
        message: 'Attendance session closed.',
        session,
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }
}
