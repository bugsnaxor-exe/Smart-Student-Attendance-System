import { Request, Response } from 'express';
import { prisma } from '../config/database';
import { SyllabusParserService, ParsedSubject } from '../services/syllabus_parser_service';

export class SyllabusController {
  /**
   * POST /api/admin/syllabus/parse-pdf
   * Accepts multipart PDF upload and returns AI-parsed subjects preview.
   */
  public static async parsePdf(req: Request, res: Response): Promise<void> {
    try {
      if (!req.file || !req.file.buffer) {
        res.status(400).json({ error: 'Please upload a valid syllabus PDF file.' });
        return;
      }

      const result = await SyllabusParserService.parseSyllabusPdf(req.file.buffer);

      if (!result.success) {
        res.status(422).json({
          error: result.message || 'Unable to parse syllabus from the provided PDF file.',
        });
        return;
      }

      res.status(200).json({
        message: `Successfully extracted ${result.totalCoursesFound} courses from syllabus PDF.`,
        departmentName: result.departmentName,
        totalCourses: result.totalCoursesFound,
        subjects: result.subjects,
      });
    } catch (error: any) {
      console.error('❌ SyllabusController.parsePdf error:', error);
      res.status(500).json({ error: 'Internal server error while processing syllabus PDF.' });
    }
  }

  /**
   * POST /api/admin/syllabus/apply
   * Commits the reviewed subject list to the database under the given batchYear.
   */
  public static async applySyllabus(req: Request, res: Response): Promise<void> {
    try {
      const { batchYear, departmentCode = 'MCA', subjects } = req.body;

      if (!batchYear || typeof batchYear !== 'string' || !batchYear.trim()) {
        res.status(400).json({ error: 'A valid Academic Registration Year (e.g. "2026-2027") is required.' });
        return;
      }

      if (!Array.isArray(subjects) || subjects.length === 0) {
        res.status(400).json({ error: 'A non-empty list of subjects is required.' });
        return;
      }

      const cleanBatchYear = batchYear.trim();

      // Find or create target department
      let dept = await prisma.department.findUnique({
        where: { code: departmentCode },
      });

      if (!dept) {
        dept = await prisma.department.create({
          data: {
            code: departmentCode,
            name: 'Master of Computer Applications',
            latitude: parseFloat(process.env.DEFAULT_DEPT_LATITUDE || '22.5726'),
            longitude: parseFloat(process.env.DEFAULT_DEPT_LONGITUDE || '88.3639'),
            radiusMeters: parseFloat(process.env.DEFAULT_GEOFENCE_RADIUS_METERS || '50.0'),
          },
        });
      }

      const upsertedList = [];

      for (const sub of subjects as ParsedSubject[]) {
        const cleanCode = String(sub.code).trim().toUpperCase();
        const cleanName = String(sub.name).trim();
        const sem = Number(sub.semester) || 1;
        const credits = Number(sub.credits) || 4;
        const type = String(sub.type || 'Theory').trim();
        const weeklyHours = String(sub.weeklyHours || (type === 'Practical' ? '0+0+3' : '3+1+0')).trim();
        const marks = String(sub.marks || '100 (70+30)').trim();

        if (!cleanCode || !cleanName) continue;

        const record = await prisma.subject.upsert({
          where: {
            code_semester_batchYear: {
              code: cleanCode,
              semester: sem,
              batchYear: cleanBatchYear,
            },
          },
          update: {
            name: cleanName,
            type,
            credits,
            weeklyHours,
            marks,
            isActive: true,
          },
          create: {
            code: cleanCode,
            name: cleanName,
            semester: sem,
            type,
            credits,
            weeklyHours,
            marks,
            batchYear: cleanBatchYear,
            isActive: true,
            departmentId: dept.id,
          },
        });

        upsertedList.push(record);
      }

      res.status(200).json({
        message: `Curriculum for Academic Year ${cleanBatchYear} applied successfully!`,
        batchYear: cleanBatchYear,
        totalSubjectsSaved: upsertedList.length,
        subjects: upsertedList,
      });
    } catch (error: any) {
      console.error('❌ SyllabusController.applySyllabus error:', error);
      res.status(500).json({ error: error.message || 'Failed to save syllabus to database.' });
    }
  }

  /**
   * GET /api/admin/syllabus/batches
   * Returns list of available batch years and subject counts.
   */
  public static async getBatches(req: Request, res: Response): Promise<void> {
    try {
      const subjects = await prisma.subject.findMany({
        select: {
          batchYear: true,
          semester: true,
          id: true,
        },
      });

      const batchMap: Record<string, { batchYear: string; totalSubjects: number; semesters: number[] }> = {};

      for (const s of subjects) {
        const b = s.batchYear || '2025-2026';
        if (!batchMap[b]) {
          batchMap[b] = { batchYear: b, totalSubjects: 0, semesters: [] };
        }
        batchMap[b].totalSubjects++;
        if (!batchMap[b].semesters.includes(s.semester)) {
          batchMap[b].semesters.push(s.semester);
        }
      }

      const batchList = Object.values(batchMap).sort((a, b) => b.batchYear.localeCompare(a.batchYear));

      res.status(200).json({
        batches: batchList,
      });
    } catch (error: any) {
      console.error('❌ SyllabusController.getBatches error:', error);
      res.status(500).json({ error: 'Failed to retrieve syllabus batches.' });
    }
  }
}
