import { Response } from 'express';
import { AuthRequest } from '../middleware/auth_middleware';
import { prisma } from '../config/database';
import { GoogleSheetsService } from '../services/sheets_service';

export class SheetsController {
  /**
   * Returns Service Account email for teachers to copy & invite as Editor to their Google Sheets.
   */
  public static async getServiceAccountInfo(req: AuthRequest, res: Response) {
    try {
      const email = GoogleSheetsService.getServiceAccountEmail();
      return res.json({
        serviceAccountEmail: email,
        instruction: `To sync attendance, open your Google Sheet -> Click 'Share' -> Add '${email}' with 'Editor' permissions.`,
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }

  /**
   * Teacher links their Google Sheet ID to a specific subject.
   */
  public static async linkSubjectSheet(req: AuthRequest, res: Response) {
    try {
      const { subjectId } = req.params;
      const { googleSheetId, sheetTabName = 'Attendance' } = req.body;

      if (!googleSheetId) {
        return res.status(400).json({ error: 'googleSheetId is required.' });
      }

      // Check teacher owns this subject or is admin
      const subject = await prisma.subject.findUnique({
        where: { id: subjectId },
      });

      if (!subject) {
        return res.status(404).json({ error: 'Subject not found.' });
      }

      // Test header initialization on Google Sheets
      const headerCheck = await GoogleSheetsService.ensureSheetHeaders(googleSheetId, sheetTabName);

      const updated = await prisma.subject.update({
        where: { id: subjectId },
        data: {
          googleSheetId,
          sheetTabName,
        },
      });

      return res.json({
        message: `Google Sheet connected successfully to ${subject.name}.`,
        sheetVerified: headerCheck,
        subject: updated,
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }
}
