import { prisma } from '../config/database';
import { getKolkataTime } from './geofence_service';

export class SessionService {
  /**
   * Starts a new 15-minute active attendance session for a subject.
   */
  public static async startSession(
    subjectId: string,
    teacherId: string,
    semester: number,
    durationMinutes: number = 15,
    latitude?: number,
    longitude?: number,
    radiusMeters: number = 50.0
  ) {
    const now = new Date();
    const expiresAt = new Date(now.getTime() + durationMinutes * 60 * 1000);

    // 0. Check daily session limit (Maximum 3 sessions per subject per day in Kolkata IST)
    const kolkata = getKolkataTime(now);
    const startOfDay = new Date(`${kolkata.dateString}T00:00:00+05:30`);
    const endOfDay = new Date(`${kolkata.dateString}T23:59:59+05:30`);

    // Count non-empty or currently active sessions conducted today
    const todaySessionsCount = await prisma.activeSession.count({
      where: {
        subjectId,
        createdAt: {
          gte: startOfDay,
          lte: endOfDay,
        },
      },
    });

    if (todaySessionsCount >= 3) {
      throw new Error(
        'Maximum daily limit reached (3 / 3 sessions conducted today for this class). No more sessions can be started today.'
      );
    }

    // 1. Close any older active sessions for this subject
    await prisma.activeSession.updateMany({
      where: {
        subjectId,
        isActive: true,
      },
      data: {
        isActive: false,
      },
    });

    // 2. Create the new 15-min active session
    const session = await prisma.activeSession.create({
      data: {
        subjectId,
        teacherId,
        semester,
        isActive: true,
        createdAt: now,
        expiresAt,
        latitude: latitude !== undefined ? latitude : null,
        longitude: longitude !== undefined ? longitude : null,
        radiusMeters: radiusMeters || 50.0,
      },
      include: {
        subject: true,
      },
    });

    console.log(
      `⏱️ [Session Started] Subject: ${session.subject.name} (${session.subject.code}) | Session #${todaySessionsCount + 1} | Location: ${latitude != null ? `${latitude}, ${longitude}` : 'Campus Default'} (50m) | Expires in ${durationMinutes} mins at ${expiresAt.toLocaleTimeString()}`
    );

    return session;
  }

  /**
   * Returns how many sessions have been conducted today for a specific subject.
   */
  public static async getTodaySessionsCount(subjectIdentifier: string): Promise<number> {
    const now = new Date();
    const kolkata = getKolkataTime(now);
    const startOfDay = new Date(`${kolkata.dateString}T00:00:00+05:30`);
    const endOfDay = new Date(`${kolkata.dateString}T23:59:59+05:30`);

    const subject = await prisma.subject.findFirst({
      where: {
        OR: [
          { id: subjectIdentifier },
          { code: { equals: subjectIdentifier, mode: 'insensitive' } },
        ],
      },
    });

    if (!subject) return 0;

    const count = await prisma.activeSession.count({
      where: {
        subjectId: subject.id,
        createdAt: {
          gte: startOfDay,
          lte: endOfDay,
        },
      },
    });

    return count;
  }

  /**
   * Returns a map of all session counts conducted today by subject code.
   */
  public static async getAllTodaySessionCounts(): Promise<Record<string, number>> {
    const now = new Date();
    const kolkata = getKolkataTime(now);
    const startOfDay = new Date(`${kolkata.dateString}T00:00:00+05:30`);
    const endOfDay = new Date(`${kolkata.dateString}T23:59:59+05:30`);

    const todaySessions = await prisma.activeSession.findMany({
      where: {
        createdAt: {
          gte: startOfDay,
          lte: endOfDay,
        },
      },
      include: {
        subject: true,
      },
    });

    const counts: Record<string, number> = {};
    for (const sess of todaySessions) {
      const code = sess.subject?.code;
      if (code) {
        counts[code] = (counts[code] || 0) + 1;
      }
    }

    return counts;
  }

  /**
   * Retrieves active session for a specific subject (by ID or course code), ensuring it hasn't expired.
   */
  public static async getActiveSession(subjectIdentifier: string) {
    const now = new Date();

    const subject = await prisma.subject.findFirst({
      where: {
        OR: [
          { id: subjectIdentifier },
          { code: { equals: subjectIdentifier, mode: 'insensitive' } },
        ],
      },
    });

    const targetSubjectId = subject ? subject.id : subjectIdentifier;

    const session = await prisma.activeSession.findFirst({
      where: {
        subjectId: targetSubjectId,
        isActive: true,
        expiresAt: {
          gt: now,
        },
      },
      include: {
        subject: {
          include: {
            teacher: {
              include: {
                user: true,
              },
            },
          },
        },
        attendances: {
          include: {
            student: {
              include: {
                user: true,
              },
            },
          },
        },
      },
    });

    // If an active session was found but expired, mark it inactive
    if (!session) {
      await prisma.activeSession.updateMany({
        where: {
          subjectId: targetSubjectId,
          isActive: true,
          expiresAt: {
            lte: now,
          },
        },
        data: {
          isActive: false,
        },
      });
    }

    return session;
  }

  /**
   * Returns all currently active sessions for a student's semester & department.
   */
  public static async getActiveSessionsForStudent(semester: number, departmentId: string) {
    const now = new Date();

    // Auto-expire outdated sessions
    await prisma.activeSession.updateMany({
      where: {
        isActive: true,
        expiresAt: {
          lte: now,
        },
      },
      data: {
        isActive: false,
      },
    });

    const activeSessions = await prisma.activeSession.findMany({
      where: {
        semester,
        isActive: true,
        expiresAt: {
          gt: now,
        },
      },
      include: {
        subject: {
          include: {
            teacher: {
              include: {
                user: true,
              },
            },
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    return activeSessions;
  }

  /**
   * Closes a session manually by the teacher.
   */
  public static async closeSession(sessionId: string) {
    const session = await prisma.activeSession.update({
      where: { id: sessionId },
      data: { isActive: false },
    });
    return session;
  }
}
