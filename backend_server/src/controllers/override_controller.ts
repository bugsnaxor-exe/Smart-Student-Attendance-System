import { Response } from 'express';
import { AuthRequest } from '../middleware/auth_middleware';
import { prisma } from '../config/database';
import { GoogleSheetsService } from '../services/sheets_service';
import { GeofenceService, getKolkataTime } from '../services/geofence_service';

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
      const { date } = req.query;

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

      // 1. Get all students enrolled in this department & semester
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

      // 2. Get students who already marked attendance today
      const markedAttendances = await prisma.attendanceRecord.findMany({
        where: {
          subjectId: subject.id,
          date: targetDate,
        },
      });

      const markedStudentIds = new Set(markedAttendances.map((a) => a.studentId));

      // 3. Filter for absent students
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
        totalPresent: markedAttendances.length,
        totalAbsent: absentStudents.length,
        absentStudents,
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }

  /**
   * Teacher grants "Half Attendance" to a latecomer student.
   * Updates database and appends to Google Sheet with status: "Half".
   */
  public static async grantHalfAttendance(req: AuthRequest, res: Response) {
    try {
      const { subjectId, studentId, date } = req.body;

      if (!subjectId || !studentId) {
        return res.status(400).json({ error: 'subjectId and studentId are required.' });
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

      const student = await prisma.studentProfile.findFirst({
        where: {
          OR: [
            { id: studentId },
            { classRoll: studentId },
            { universityRoll: studentId },
          ],
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

      // Create or update attendance record as "Half"
      const record = await prisma.attendanceRecord.upsert({
        where: {
          studentId_subjectId_date: {
            studentId: student.id,
            subjectId: subject.id,
            date: targetDate,
          },
        },
        create: {
          studentId: student.id,
          subjectId: subject.id,
          date: targetDate,
          time: kolkata.formattedTime,
          status: 'Half',
          syncedToSheet: false,
        },
        update: {
          status: 'Half',
          time: kolkata.formattedTime,
        },
      });

      // Append row to Teacher's Google Sheet
      let sheetSyncSuccess = false;
      if (subject.googleSheetId) {
        const sheetRes = await GoogleSheetsService.appendAttendanceRow(
          subject.googleSheetId,
          {
            date: targetDate,
            classRoll: student.classRoll,
            universityRoll: student.universityRoll,
            registrationNumber: student.regNumber,
            studentName: student.user.name,
            status: 'Half',
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

      let dbRecord = null;
      if (student && subject) {
        dbRecord = await prisma.attendanceRecord.upsert({
          where: {
            studentId_subjectId_date: {
              studentId: student.id,
              subjectId: subject.id,
              date: targetDate,
            },
          },
          create: {
            studentId: student.id,
            subjectId: subject.id,
            date: targetDate,
            time: kolkata.formattedTime,
            status: status === 'Full' ? 'Full' : 'Half',
            syncedToSheet: false,
          },
          update: {
            status: status === 'Full' ? 'Full' : 'Half',
            time: kolkata.formattedTime,
          },
        });
      }

      let sheetSyncSuccess = false;
      let sheetMessage = '';

      if (spreadsheetId) {
        const sheetRes = await GoogleSheetsService.recordStudentAttendanceInMatrix(
          spreadsheetId,
          {
            date: targetDate,
            classRoll: classRoll || student?.classRoll || 'MCA-26-042',
            universityRoll: universityRoll || student?.universityRoll || '12000126042',
            registrationNumber: registrationNumber || student?.regNumber || 'REG-2026-9042',
            studentName: studentName || student?.user?.name || 'Student',
            status: status === 'Full' ? 'Full' : 'Half',
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
          regNo: s.regNumber,
          semester: s.semester,
        })),
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }
}
