import { google } from 'googleapis';
import * as fs from 'fs';
import * as path from 'path';

export interface AttendanceSheetRow {
  date: string;              // e.g. "2026-08-31"
  classRoll: string;         // e.g. "MCA-26-042"
  universityRoll: string;    // e.g. "12000126042"
  registrationNumber: string;// e.g. "REG-2026-9042"
  studentName: string;       // e.g. "Sayan Banerjee"
  status: 'Full' | 'Half';   // "Full" (P - 2 attendances) or "Half" (H - 1 attendance)
}

export class GoogleSheetsService {
  private static sheetsClient: any = null;
  private static serviceAccountEmail: string | null = null;

  /**
   * Initializes the Google Sheets API client using the Service Account JSON credentials.
   */
  private static getClient() {
    if (this.sheetsClient) {
      return this.sheetsClient;
    }

    const keyPath = process.env.GOOGLE_SERVICE_ACCOUNT_KEY_PATH || './service-account-credentials.json';
    const resolvedPath = path.resolve(process.cwd(), keyPath);

    if (fs.existsSync(resolvedPath)) {
      try {
        const keyFile = JSON.parse(fs.readFileSync(resolvedPath, 'utf8'));
        this.serviceAccountEmail = keyFile.client_email;

        const auth = new google.auth.GoogleAuth({
          keyFile: resolvedPath,
          scopes: ['https://www.googleapis.com/auth/spreadsheets'],
        });

        this.sheetsClient = google.sheets({ version: 'v4', auth });
        console.log(`✅ Google Sheets API initialized with Service Account: ${this.serviceAccountEmail}`);
        return this.sheetsClient;
      } catch (err) {
        console.warn('⚠️ Error loading Google Service Account Key:', err);
      }
    } else {
      console.log(`ℹ️ No live service-account-credentials.json found at ${resolvedPath}. Running in simulated Google Sheets mode.`);
    }

    return null;
  }

  /**
   * Returns the service account email so teachers know which email to grant Editor access to.
   */
  public static getServiceAccountEmail(): string {
    this.getClient();
    return this.serviceAccountEmail || 'attendance-sync-sa@smart-attendance-system.iam.gserviceaccount.com';
  }

  /**
   * Ensures the header row exists in the teacher's Google Sheet tab.
   */
  public static async ensureSheetHeaders(
    spreadsheetId: string,
    tabName: string = 'Attendance'
  ): Promise<boolean> {
    const sheets = this.getClient();
    if (!sheets) {
      console.log(`[Simulated GSheets] Verified headers for Sheet ID: ${spreadsheetId} [Tab: ${tabName}]`);
      return true;
    }

    try {
      const range = `${tabName}!A1:D1`;
      const response = await sheets.spreadsheets.values.get({
        spreadsheetId,
        range,
      });

      const rows = response.data.values;
      if (!rows || rows.length === 0 || rows[0].length === 0) {
        const expectedHeaders = ['Class Roll', 'University Roll', 'Registration Number', 'Student Name'];
        await sheets.spreadsheets.values.update({
          spreadsheetId,
          range: `${tabName}!A1:D1`,
          valueInputOption: 'USER_ENTERED',
          requestBody: {
            values: [expectedHeaders],
          },
        });
        console.log(`✅ Initialized Matrix headers in Google Sheet ID: ${spreadsheetId} [${tabName}]`);
      }
      return true;
    } catch (error: any) {
      console.error(`❌ Error ensuring headers in Google Sheet (${spreadsheetId}):`, error.message);
      return false;
    }
  }

  /**
   * Column index to Sheet letter (0 -> A, 1 -> B, 26 -> AA, etc.)
   */
  private static colIndexToLetter(colIndex: number): string {
    let temp: number;
    let letter = '';
    while (colIndex >= 0) {
      temp = colIndex % 26;
      letter = String.fromCharCode(temp + 65) + letter;
      colIndex = Math.floor(colIndex / 26) - 1;
    }
    return letter;
  }

  /**
   * Appends or updates student attendance in the official Student Matrix Google Sheet.
   * Format:
   * Header (Row 1): [Class Roll | University Roll | Reg No | Student Name | YYYY-MM-DD | ...]
   * Rows 2+:        [Roll       | UniRoll         | Reg   | Name         | P / H (Blank if absent)]
   *
   * 'P' = Full Attendance (2 attendances per class)
   * 'H' = Half Attendance (Late comer manual override - 1 attendance)
   * Blank = Absent
   */
  public static async recordStudentAttendanceInMatrix(
    spreadsheetId: string,
    rowData: AttendanceSheetRow,
    tabName: string = 'Attendance'
  ): Promise<{ success: boolean; message: string }> {
    const sheets = this.getClient();
    const mark = rowData.status === 'Full' ? 'P' : 'H';

    if (!sheets) {
      console.log(
        `📊 [Simulated Matrix GSheets] Sheet: ${spreadsheetId} [${tabName}] | Date: ${rowData.date} | Student: ${rowData.studentName} (${rowData.universityRoll}) -> Mark: '${mark}' (Absent = Blank)`
      );
      return {
        success: true,
        message: `Attendance mark '${mark}' logged successfully (Simulated Matrix Mode).`,
      };
    }

    try {
      // 1. Read all current values from sheet
      const range = `${tabName}!A1:ZZ1000`;
      const response = await sheets.spreadsheets.values.get({
        spreadsheetId,
        range,
      });

      let values: string[][] = response.data.values || [];

      // If empty sheet, initialize header row
      if (values.length === 0 || values[0].length === 0) {
        values = [['Class Roll', 'University Roll', 'Registration Number', 'Student Name']];
      }

      const headers = values[0];

      // 2. Find or create the Date Column (e.g. "2026-08-31")
      let dateColIndex = headers.indexOf(rowData.date);
      if (dateColIndex === -1) {
        dateColIndex = headers.length;
        headers.push(rowData.date);

        // Update header row on Google Sheets
        const headerColLetter = this.colIndexToLetter(dateColIndex);
        await sheets.spreadsheets.values.update({
          spreadsheetId,
          range: `${tabName}!${headerColLetter}1`,
          valueInputOption: 'USER_ENTERED',
          requestBody: {
            values: [[rowData.date]],
          },
        });
      }

      // 3. Find or create Student Row by University Roll (Col index 1) or Class Roll (Col index 0)
      let studentRowIndex = -1;
      for (let r = 1; r < values.length; r++) {
        const row = values[r];
        if (
          (row[1] && row[1].trim() === rowData.universityRoll.trim()) ||
          (row[0] && row[0].trim() === rowData.classRoll.trim())
        ) {
          studentRowIndex = r + 1; // 1-indexed for Sheets
          break;
        }
      }

      // If student not found, append a new student row
      if (studentRowIndex === -1) {
        studentRowIndex = values.length + 1;
        const newRow: string[] = [
          rowData.classRoll,
          rowData.universityRoll,
          rowData.registrationNumber,
          rowData.studentName,
        ];
        // Pad with blanks up to date column
        while (newRow.length < dateColIndex) {
          newRow.push('');
        }
        newRow[dateColIndex] = mark;

        await sheets.spreadsheets.values.append({
          spreadsheetId,
          range: `${tabName}!A:Z`,
          valueInputOption: 'USER_ENTERED',
          insertDataOption: 'INSERT_ROWS',
          requestBody: {
            values: [newRow],
          },
        });
      } else {
        // Update specific cell: Row `studentRowIndex`, Column `dateColIndex`
        const cellLetter = this.colIndexToLetter(dateColIndex);
        const cellRange = `${tabName}!${cellLetter}${studentRowIndex}`;

        await sheets.spreadsheets.values.update({
          spreadsheetId,
          range: cellRange,
          valueInputOption: 'USER_ENTERED',
          requestBody: {
            values: [[mark]],
          },
        });
      }

      console.log(
        `✅ Synced Matrix Google Sheet: ${spreadsheetId} | Cell (${studentRowIndex}, ${dateColIndex}) set to '${mark}' for ${rowData.studentName}`
      );
      return {
        success: true,
        message: `Successfully marked '${mark}' in Google Sheet.`,
      };
    } catch (error: any) {
      console.error(`❌ Failed to update Matrix Google Sheet (${spreadsheetId}):`, error.message);
      return {
        success: false,
        message: `Google Sheets matrix sync failed: ${error.message}`,
      };
    }
  }

  /**
   * Compatibility alias for backward compatibility
   */
  public static async appendAttendanceRow(
    spreadsheetId: string,
    rowData: AttendanceSheetRow,
    tabName: string = 'Attendance'
  ) {
    return this.recordStudentAttendanceInMatrix(spreadsheetId, rowData, tabName);
  }
}

