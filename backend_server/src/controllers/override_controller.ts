import { Response } from 'express';
import { AuthRequest } from '../middleware/auth_middleware';
import { prisma } from '../config/database';
import { GoogleSheetsService } from '../services/sheets_service';
import { GeofenceService, getKolkataTime } from '../services/geofence_service';
import { SessionService } from '../services/session_service';

type OverrideBroadcastCallback = (data: any) => void;
let overrideBroadcastCallback: OverrideBroadcastCallback | null = null;

export function registerOverrideBroadcaster(callback: OverrideBroadcastCallback) {
  overrideBroadcastCallback = callback;
}

export class OverrideController {
  /**
   * Returns list of students who have NOT marked attendance for a given subject & date.
   * Teacher can view this list to grant "Half" attendance to latecomers.
   */
  public static async getAbsentStudentsForSubject(req: AuthRequest, res: Response) {
    try {
      const { subjectId } = req.params;
      const { date, sessionId } = req.query;

      const kolkata = getKolkataTime();
      const targetDate = (date as string) || kolkata.dateString;

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

      // 1. Get all students enrolled in this semester
      const allStudents = await prisma.studentProfile.findMany({
        where: {
          semester: subject.semester,
        },
        include: {
          user: true,
        },
        orderBy: {
          classRoll: 'asc',
        },
      });

      // 2. Identify attendance records for THIS SUBJECT on targetDate
      const subjectAttendances = await prisma.attendanceRecord.findMany({
        where: {
          subjectId: subject.id,
          date: targetDate,
        },
      });
      const markedStudentIds = new Set(subjectAttendances.map((a) => a.studentId));

      // 3. Filter for absent students for this subject
      const absentStudents = allStudents
        .filter((student) => !markedStudentIds.has(student.id))
        .map((student) => ({
          id: student.id,
          name: student.user.name,
          email: student.user.email,
          classRoll: student.classRoll,
          universityRoll: student.universityRoll,
          regNumber: student.regNumber,
          semester: student.semester,
        }));

      return res.json({
        subjectName: subject.name,
        subjectCode: subject.code,
        date: targetDate,
        totalEnrolled: allStudents.length,
        totalPresent: markedStudentIds.size,
        totalAbsent: absentStudents.length,
        absentStudents,
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }

  /**
   * Teacher grants "Half Attendance" to a student for a subject.
   * Works whether a session is active or not started yet.
   * Updates database and appends to Google Sheet with status: "Half".
   */
  public static async grantHalfAttendance(req: AuthRequest, res: Response) {
    try {
      const { subjectId, studentId, classRoll, universityRoll, registrationNumber, date, sessionId } = req.body;

      const lookupIdentifiers = [
        studentId,
        classRoll,
        universityRoll,
        registrationNumber,
      ].filter(id => id && id !== 'undefined' && id !== 'null' && typeof id === 'string' && id.trim() !== '');

      if (!subjectId || lookupIdentifiers.length === 0) {
        return res.status(400).json({ error: 'Valid subjectId and student identifier are required.' });
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

      const orConditions: any[] = [];
      for (const id of lookupIdentifiers) {
        orConditions.push({ id });
        orConditions.push({ classRoll: id });
        orConditions.push({ universityRoll: id });
        orConditions.push({ regNumber: id });
      }

      const student = await prisma.studentProfile.findFirst({
        where: {
          OR: orConditions,
        },
        include: {
          user: true,
        },
      });

      if (!student) {
        return res.status(404).json({ error: 'Student not found.' });
      }

      const kolkata = getKolkataTime();
      const targetDate = date || kolkata.dateString;

      // Determine active session if any
      let targetSession = null;
      if (sessionId) {
        targetSession = await prisma.activeSession.findUnique({
          where: { id: sessionId },
        });
      }
      if (!targetSession) {
        targetSession = await SessionService.getActiveSession(subject.id);
      }

      // Create or update attendance record as "Half" for this subject and date
      const existing = await prisma.attendanceRecord.findFirst({
        where: {
          studentId: student.id,
          subjectId: subject.id,
          date: targetDate,
        },
      });

      let record;
      if (existing) {
        record = await prisma.attendanceRecord.update({
          where: { id: existing.id },
          data: {
            status: 'Half',
            time: kolkata.formattedTime,
            ...(targetSession ? { sessionId: targetSession.id } : {}),
          },
        });
      } else {
        record = await prisma.attendanceRecord.create({
          data: {
            sessionId: targetSession ? targetSession.id : null,
            studentId: student.id,
            subjectId: subject.id,
            date: targetDate,
            time: kolkata.formattedTime,
            status: 'Half',
            syncedToSheet: false,
          },
        });
      }

      // Append row to Teacher's Google Sheet
      let sheetSyncSuccess = false;
      let sheetId = subject.googleSheetId || process.env.MASTER_GOOGLE_SHEET_ID || process.env.GOOGLE_SPREADSHEET_ID || '1KN_lGqkfzE7CBdiceE8VEneQ-37vsuGFz2jTvRhsPFk';
      if (!sheetId) {
        const anyConfig = await prisma.subject.findFirst({
          where: { googleSheetId: { not: null } },
          select: { googleSheetId: true }
        });
        if (anyConfig?.googleSheetId) sheetId = anyConfig.googleSheetId;
      }

      if (sheetId) {
        const sheetRes = await GoogleSheetsService.appendAttendanceRow(
          sheetId,
          {
            date: targetDate,
            classRoll: student.classRoll,
            universityRoll: student.universityRoll,
            registrationNumber: student.regNumber,
            studentName: student.user.name,
            status: 'Half',
            subjectCode: subject.code,
            subjectName: subject.name,
            semester: subject.semester,
          },
          subject.sheetTabName || 'Attendance'
        );

        if (sheetRes.success) {
          sheetSyncSuccess = true;
          await prisma.attendanceRecord.update({
            where: { id: record.id },
            data: { syncedToSheet: true },
          });
        }
      }

      // Broadcast real-time event to Web App & Mobile App
      if (overrideBroadcastCallback) {
        overrideBroadcastCallback({
          type: 'STUDENT_CHECK_IN',
          subjectId: subject.id,
          subjectCode: subject.code,
          subjectName: subject.name,
          student: {
            id: student.id,
            name: student.user.name,
            classRoll: student.classRoll,
            universityRoll: student.universityRoll,
            regNumber: student.regNumber,
          },
          status: 'Half',
          date: targetDate,
          time: kolkata.formattedTime,
        });
      }

      return res.json({
        message: `Half attendance granted for ${student.user.name} (${student.classRoll}).`,
        status: 'Half',
        date: targetDate,
        time: kolkata.formattedTime,
        sheetSynced: sheetSyncSuccess,
        attendance: record,
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }

  /**
   * Directly syncs a student's attendance mark to the Matrix Google Sheet from the web portal.
   */
  public static async grantHalfAttendanceMatrix(req: any, res: Response) {
    try {
      const {
        spreadsheetId,
        classRoll,
        universityRoll,
        registrationNumber,
        studentName,
        status = 'Half',
        date,
        subjectCode = 'MCA-301',
        semester,
        sessionId,
      } = req.body;

      const kolkata = getKolkataTime();
      const targetDate = date || kolkata.dateString;

      // Find student and subject to save to PostgreSQL
      const student = await prisma.studentProfile.findFirst({
        where: {
          OR: [
            { universityRoll: universityRoll || 'N/A' },
            { classRoll: classRoll || 'N/A' },
            { regNumber: registrationNumber || 'N/A' },
          ],
        },
        include: { user: true },
      });

      const subject = await prisma.subject.findFirst({
        where: {
          OR: [
            { code: { equals: subjectCode, mode: 'insensitive' } },
            { id: subjectCode },
          ],
        },
      });

      // Determine active session
      let targetSession = null;
      if (sessionId) {
        targetSession = await prisma.activeSession.findUnique({
          where: { id: sessionId },
        });
      }
      if (!targetSession && subject) {
        targetSession = await SessionService.getActiveSession(subject.id);
      }

      // Calculate session number today
      let sessionNumber = 1;
      if (subject) {
        const todaySessions = await prisma.activeSession.findMany({
          where: {
            subjectId: subject.id,
            createdAt: {
              gte: new Date(`${targetDate}T00:00:00+05:30`),
              lte: new Date(`${targetDate}T23:59:59+05:30`),
            },
          },
          orderBy: { createdAt: 'asc' },
        });

        if (targetSession) {
          const idx = todaySessions.findIndex(s => s.id === targetSession.id);
          if (idx !== -1) sessionNumber = idx + 1;
        } else if (todaySessions.length > 0) {
          sessionNumber = todaySessions.length;
        }
      }

      let dbRecord = null;
      if (student && subject) {
        const existing = await prisma.attendanceRecord.findFirst({
          where: {
            studentId: student.id,
            subjectId: subject.id,
            date: targetDate,
          },
        });

        if (existing) {
          dbRecord = await prisma.attendanceRecord.update({
            where: { id: existing.id },
            data: {
              status: status === 'Full' ? 'Full' : 'Half',
              time: kolkata.formattedTime,
              ...(targetSession ? { sessionId: targetSession.id } : {}),
            },
          });
        } else {
          dbRecord = await prisma.attendanceRecord.create({
            data: {
              sessionId: targetSession ? targetSession.id : null,
              studentId: student.id,
              subjectId: subject.id,
              date: targetDate,
              time: kolkata.formattedTime,
              status: status === 'Full' ? 'Full' : 'Half',
              syncedToSheet: false,
            },
          });
        }
      }

      let sheetSyncSuccess = false;
      let sheetMessage = '';

      const targetSpreadsheetId = spreadsheetId || subject?.googleSheetId || process.env.MASTER_GOOGLE_SHEET_ID || '1KN_lGqkfzE7CBdiceE8VEneQ-37vsuGFz2jTvRhsPFk';

      if (targetSpreadsheetId) {
        const sheetRes = await GoogleSheetsService.recordStudentAttendanceInMatrix(
          targetSpreadsheetId,
          {
            date: targetDate,
            classRoll: classRoll || student?.classRoll || 'MCA-26-042',
            universityRoll: universityRoll || student?.universityRoll || '12000126042',
            registrationNumber: registrationNumber || student?.regNumber || 'REG-2026-9042',
            studentName: studentName || student?.user?.name || 'Student',
            status: status === 'Full' ? 'Full' : 'Half',
            subjectCode: subject?.code || subjectCode,
            subjectName: subject?.name,
            semester: subject?.semester || student?.semester || semester || 3,
          }
        );
        sheetSyncSuccess = sheetRes.success;
        sheetMessage = sheetRes.message;
      } else {
        sheetMessage = 'No Google Spreadsheet ID provided.';
      }

      // Broadcast real-time check-in to Mobile App & Web App
      if (overrideBroadcastCallback && (student || classRoll)) {
        overrideBroadcastCallback({
          type: 'STUDENT_CHECK_IN',
          subjectId: subject?.id || '',
          subjectCode: subject?.code || subjectCode,
          subjectName: subject?.name || 'Subject',
          student: {
            id: student?.id || '',
            name: studentName || student?.user?.name || 'Student',
            classRoll: classRoll || student?.classRoll || '',
            universityRoll: universityRoll || student?.universityRoll || '',
            regNumber: registrationNumber || student?.regNumber || '',
          },
          status: status === 'Full' ? 'Full' : 'Half',
          date: targetDate,
          time: kolkata.formattedTime,
        });
      }

      return res.json({
        success: true,
        message: `Attendance mark '${status === 'Full' ? 'P' : 'H'}' recorded for ${studentName}.`,
        sheetSynced: sheetSyncSuccess,
        sheetMessage,
        date: targetDate,
        time: kolkata.formattedTime,
        attendance: dbRecord,
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }

  /**
   * Returns all registered students enrolled in a particular semester from the database.
   */
  public static async getStudentsBySemester(req: any, res: Response) {
    try {
      const semester = parseInt(req.params.semester as string, 10) || 3;
      const students = await prisma.studentProfile.findMany({
        where: { semester },
        include: { user: true },
        orderBy: { classRoll: 'asc' },
      });

      return res.json({
        semester,
        total: students.length,
        students: students.map((s) => ({
          id: s.id,
          name: s.user.name,
          email: s.user.email,
          classRoll: s.classRoll,
          universityRoll: s.universityRoll,
          uniRoll: s.universityRoll,
          regNo: s.regNumber,
          regNumber: s.regNumber,
          semester: s.semester,
        })),
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }
}
