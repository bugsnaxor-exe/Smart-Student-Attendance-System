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

      const subject = await prisma.subject.findUnique({
        where: { id: subjectId },
      });

      if (!subject) {
        return res.status(404).json({ error: 'Subject not found.' });
      }

      const teacherId = req.user?.teacherId;
      if (!teacherId || (subject.teacherId !== teacherId && req.user?.role !== 'ADMIN')) {
        return res.status(403).json({ error: 'You are not authorized to start a session for this subject.' });
      }

      const session = await SessionService.startSession(
        subjectId,
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

      // Check if student has already marked attendance for each session today
      const todayDate = new Date().toISOString().split('T')[0];
      const studentAttendancesToday = await prisma.attendanceRecord.findMany({
        where: {
          studentId: student.id,
          date: todayDate,
        },
      });

      const markedSubjectIds = new Set(studentAttendancesToday.map((a) => a.subjectId));

      const sessionsWithMarkedStatus = activeSessions.map((sess) => {
        const remainingSeconds = Math.max(0, Math.floor((sess.expiresAt.getTime() - new Date().getTime()) / 1000));
        return {
          ...sess,
          isAlreadyMarked: markedSubjectIds.has(sess.subjectId),
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
