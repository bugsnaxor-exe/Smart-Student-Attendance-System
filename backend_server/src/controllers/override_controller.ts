import { Response } from 'express';
import { AuthRequest } from '../middleware/auth_middleware';
import { prisma } from '../config/database';
import { GoogleSheetsService } from '../services/sheets_service';
import { GeofenceService } from '../services/geofence_service';

export class OverrideController {
  /**
   * Returns list of students who have NOT marked attendance for a given subject & date.
   * Teacher can view this list to grant "Half" attendance to latecomers.
   */
  public static async getAbsentStudentsForSubject(req: AuthRequest, res: Response) {
    try {
      const { subjectId } = req.params;
      const { date } = req.query;

      const targetDate = (date as string) || new Date().toISOString().split('T')[0];

      const subject = await prisma.subject.findUnique({
        where: { id: subjectId },
      });

      if (!subject) {
        return res.status(404).json({ error: 'Subject not found.' });
      }

      // 1. Get all students enrolled in this department & semester
      const allStudents = await prisma.studentProfile.findMany({
        where: {
          departmentId: subject.departmentId,
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
          subjectId,
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

      const subject = await prisma.subject.findUnique({
        where: { id: subjectId },
      });

      if (!subject) {
        return res.status(404).json({ error: 'Subject not found.' });
      }

      const student = await prisma.studentProfile.findUnique({
        where: { id: studentId },
        include: {
          user: true,
        },
      });

      if (!student) {
        return res.status(404).json({ error: 'Student not found.' });
      }

      const targetDate = date || new Date().toISOString().split('T')[0];
      const now = new Date();
      const timeValidation = GeofenceService.validateCollegeHours(now);

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
          time: timeValidation.formattedTime,
          status: 'Half',
          syncedToSheet: false,
        },
        update: {
          status: 'Half',
          time: timeValidation.formattedTime,
        },
      });

      // Append row to Teacher's Google Sheet
      // Format: Date | Class Roll | University Roll | Registration Number | Student Name | Status
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

      return res.json({
        message: `Half attendance granted for ${student.user.name} (${student.classRoll}).`,
        status: 'Half',
        date: targetDate,
        time: timeValidation.formattedTime,
        sheetSynced: sheetSyncSuccess,
        attendance: record,
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }
}
