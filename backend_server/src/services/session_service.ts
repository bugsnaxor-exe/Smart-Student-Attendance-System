import { prisma } from '../config/database';

export class SessionService {
  /**
   * Starts a new 15-minute active attendance session for a subject.
   */
  public static async startSession(
    subjectId: string,
    teacherId: string,
    semester: number,
    durationMinutes: number = 15
  ) {
    const now = new Date();
    const expiresAt = new Date(now.getTime() + durationMinutes * 60 * 1000);

    // 0. Check daily session limit (Maximum 3 sessions per subject per day)
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
    const endOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);

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
        'Maximum daily limit reached (3 / 3 sessions conducted today for this class). No more sessions can be started.'
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
      },
      include: {
        subject: true,
      },
    });

    console.log(
      `⏱️ [Session Started] Subject: ${session.subject.name} (${session.subject.code}) | Expires in ${durationMinutes} mins at ${expiresAt.toLocaleTimeString()}`
    );

    return session;
  }

  /**
   * Retrieves active session for a specific subject, ensuring it hasn't expired.
   */
  public static async getActiveSession(subjectId: string) {
    const now = new Date();

    const session = await prisma.activeSession.findFirst({
      where: {
        subjectId,
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
          subjectId,
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
