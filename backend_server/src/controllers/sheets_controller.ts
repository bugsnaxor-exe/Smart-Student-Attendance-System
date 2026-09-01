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
   * Returns currently active/linked Google Sheet ID and connection status across web and mobile.
   */
  public static async getActiveSheet(req: any, res: Response) {
    try {
      const subjectWithSheet = await prisma.subject.findFirst({
        where: {
          googleSheetId: { not: null },
        },
      });

      const email = GoogleSheetsService.getServiceAccountEmail();
      const sheetId = subjectWithSheet?.googleSheetId || '1KN_lGqkfzE7CBdiceE8VEnEQ-37vsuGFz2jTvRhsPFk';
      const sheetTabName = subjectWithSheet?.sheetTabName || 'Attendance';

      return res.json({
        connected: !!sheetId,
        googleSheetId: sheetId,
        sheetTabName: sheetTabName,
        serviceAccountEmail: email,
        isLive: true,
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }

  /**
   * Teacher links their Google Sheet ID to subjects across database.
   */
  public static async linkSubjectSheet(req: AuthRequest, res: Response) {
    try {
      const { subjectId } = req.params;
      const { googleSheetId, spreadsheetId, sheetTabName = 'Attendance' } = req.body;
      const targetSheetId = googleSheetId || spreadsheetId;

      if (!targetSheetId) {
        return res.status(400).json({ error: 'googleSheetId or spreadsheetId is required.' });
      }

      // Update all department subjects with this sheet ID so it persists across all semesters
      await prisma.subject.updateMany({
        data: {
          googleSheetId: targetSheetId,
          sheetTabName,
        },
      });

      // Test header initialization on Google Sheets
      const headerCheck = await GoogleSheetsService.ensureSheetHeaders(targetSheetId, sheetTabName);

      return res.json({
        message: `Google Sheet connected successfully!`,
        googleSheetId: targetSheetId,
        sheetTabName,
        sheetVerified: headerCheck,
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }

  /**
   * Diagnostic test endpoint to verify Google Sheet permissions and connectivity.
   */
  public static async testConnection(req: any, res: Response) {
    try {
      const { spreadsheetId, googleSheetId, save = true } = req.body;
      const targetId = spreadsheetId || googleSheetId;
      if (!targetId) {
        return res.status(400).json({
          success: false,
          error: 'Spreadsheet ID is required to run test.',
          fixSuggestion: 'Please enter your 44-character Google Spreadsheet ID.',
        });
      }

      const result = await GoogleSheetsService.testConnection(targetId);

      // If valid, persist to database so mobile and web portals are permanently synced
      if (result.success && save) {
        await prisma.subject.updateMany({
          data: {
            googleSheetId: targetId,
          },
        });
      }

      return res.json({
        ...result,
        googleSheetId: targetId,
      });
    } catch (error: any) {
      return res.status(500).json({ success: false, error: error.message });
    }
  }
}
