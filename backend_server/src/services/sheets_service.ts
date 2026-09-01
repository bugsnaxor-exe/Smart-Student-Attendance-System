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
  subjectCode?: string;      // e.g. "MCA-301"
  subjectName?: string;      // e.g. "Artificial Intelligence"
  semester?: number;         // e.g. 3
  sessionNumber?: number;    // e.g. 1, 2, 3
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

    // 1. Check for inline JSON string in GOOGLE_SERVICE_ACCOUNT_JSON (.env / Render)
    let inlineJson = process.env.GOOGLE_SERVICE_ACCOUNT_JSON?.trim();
    if (inlineJson) {
      // Check if it's base64 encoded
      if (!inlineJson.startsWith('{') && !inlineJson.startsWith('"') && inlineJson.length > 100) {
        try {
          inlineJson = Buffer.from(inlineJson, 'base64').toString('utf8');
        } catch (e) {}
      }

      try {
        const credentials = JSON.parse(inlineJson);
        if (credentials.client_email && (credentials.private_key || credentials.private_key_id)) {
          this.serviceAccountEmail = credentials.client_email;

          const auth = new google.auth.GoogleAuth({
            credentials,
            scopes: ['https://www.googleapis.com/auth/spreadsheets'],
          });

          this.sheetsClient = google.sheets({ version: 'v4', auth });
          console.log(`✅ Google Sheets API initialized from GOOGLE_SERVICE_ACCOUNT_JSON with email: ${this.serviceAccountEmail}`);
          return this.sheetsClient;
        } else if (credentials.client_email) {
          this.serviceAccountEmail = credentials.client_email;
          console.warn('⚠️ GOOGLE_SERVICE_ACCOUNT_JSON has client_email but is missing private_key.');
        }
      } catch (err: any) {
        console.warn('⚠️ Error parsing GOOGLE_SERVICE_ACCOUNT_JSON (must be a valid JSON key object):', err.message);
      }
    }

    // 2. Fallback to service-account-credentials.json file
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
      } catch (err: any) {
        console.warn('⚠️ Error loading Google Service Account Key:', err.message);
      }
    } else {
      console.log(`ℹ️ No live service-account-credentials.json found at ${resolvedPath}.`);
    }

    return null;
  }

  /**
   * Returns the service account email so teachers know which email to grant Editor access to.
   */
  public static getServiceAccountEmail(): string {
    this.getClient();
    return (
      process.env.GOOGLE_SERVICE_ACCOUNT_EMAIL ||
      this.serviceAccountEmail ||
      'attendance-sync-sa@smart-attendance-system.iam.gserviceaccount.com'
    );
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
      // 0. Auto-resolve tab name from Google Spreadsheet metadata
      let resolvedTab = tabName;
      try {
        const meta = await sheets.spreadsheets.get({ spreadsheetId });
        const existingTabs = meta.data.sheets || [];
        const hasTab = existingTabs.some((s: any) => s.properties?.title === tabName);
        if (!hasTab && existingTabs.length > 0 && existingTabs[0].properties?.title) {
          resolvedTab = existingTabs[0].properties.title;
        }
      } catch (metaErr: any) {
        console.warn(`Could not inspect spreadsheet metadata: ${metaErr.message}`);
      }

      // 1. Read all current values from sheet
      const range = `${resolvedTab}!A1:ZZ1000`;
      const response = await sheets.spreadsheets.values.get({
        spreadsheetId,
        range,
      });

      let values: string[][] = response.data.values || [];

      // If empty sheet, initialize header row
      if (values.length === 0 || values[0].length === 0) {
        values = [['Class Roll', 'University Roll', 'Registration Number', 'Student Name']];
        await sheets.spreadsheets.values.update({
          spreadsheetId,
          range: `${resolvedTab}!A1:D1`,
          valueInputOption: 'USER_ENTERED',
          requestBody: {
            values: [['Class Roll', 'University Roll', 'Registration Number', 'Student Name']],
          },
        });
      }

      const headers = values[0];

      // 2. Find or create the Date & Subject Column (e.g. "2026-09-01 [MCA-301 • Sem 3]")
      const subjectTag = rowData.subjectCode
        ? ` [${rowData.subjectCode}${rowData.semester ? ` • Sem ${rowData.semester}` : ''}]`
        : '';
      const targetDateHeader = `${rowData.date}${subjectTag}`;

      let dateColIndex = -1;
      for (let i = 0; i < headers.length; i++) {
        const h = headers[i]?.trim();
        if (
          h === targetDateHeader ||
          (rowData.subjectCode && h.startsWith(rowData.date) && h.includes(rowData.subjectCode))
        ) {
          dateColIndex = i;
          break;
        }
      }

      if (dateColIndex === -1 && !rowData.subjectCode) {
        dateColIndex = headers.indexOf(rowData.date);
      }

      if (dateColIndex === -1) {
        dateColIndex = headers.length;
        headers.push(targetDateHeader);

        // Update header row on Google Sheets
        const headerColLetter = this.colIndexToLetter(dateColIndex);
        await sheets.spreadsheets.values.update({
          spreadsheetId,
          range: `${resolvedTab}!${headerColLetter}1`,
          valueInputOption: 'USER_ENTERED',
          requestBody: {
            values: [[targetDateHeader]],
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
          range: `${resolvedTab}!A:Z`,
          valueInputOption: 'USER_ENTERED',
          insertDataOption: 'INSERT_ROWS',
          requestBody: {
            values: [newRow],
          },
        });
      } else {
        // Update specific cell: Row `studentRowIndex`, Column `dateColIndex`
        const cellLetter = this.colIndexToLetter(dateColIndex);
        const cellRange = `${resolvedTab}!${cellLetter}${studentRowIndex}`;

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
        `✅ Synced Matrix Google Sheet: ${spreadsheetId} [${resolvedTab}] | Cell (${studentRowIndex}, ${dateColIndex}) set to '${mark}' for ${rowData.studentName} on ${rowData.date}`
      );
      return {
        success: true,
        message: `Successfully marked '${mark}' in Google Sheet [${resolvedTab}] on ${rowData.date}.`,
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
    const result = await this.recordStudentAttendanceInMatrix(spreadsheetId, rowData, tabName);

    // Mirror to Master Admin Sheet (Sayantan Dasgupta's Google Sheet) if configured
    const masterSheetId = process.env.MASTER_GOOGLE_SHEET_ID?.trim();
    if (masterSheetId && masterSheetId !== spreadsheetId) {
      this.recordStudentAttendanceInMatrix(masterSheetId, rowData, 'MasterAttendance').catch((err) => {
        console.warn('⚠️ Master Google Sheet Mirror sync warning:', err.message);
      });
    }

    return result;
  }

  /**
   * Diagnostic test method that inspects Google Sheet permissions and connectivity.
   */
  public static async testConnection(spreadsheetId: string): Promise<{
    success: boolean;
    serviceAccountEmail: string | null;
    isLiveClient: boolean;
    sheetTitle?: string;
    tabs?: string[];
    error?: string;
    fixSuggestion?: string;
  }> {
    const sheets = this.getClient();
    const email = this.getServiceAccountEmail();

    if (!sheets) {
      return {
        success: false,
        serviceAccountEmail: email,
        isLiveClient: false,
        error: 'No Google Cloud Service Account credentials JSON found on the server.',
        fixSuggestion:
          'Please place service-account-credentials.json in your backend_server directory or set GOOGLE_SERVICE_ACCOUNT_JSON in .env / Render Environment Variables.',
      };
    }

    try {
      const meta = await sheets.spreadsheets.get({ spreadsheetId });
      const sheetTitle = meta.data.properties?.title || 'Untitled Spreadsheet';
      const tabs = (meta.data.sheets || []).map((s: any) => s.properties?.title || 'Unknown');

      const primaryTab = tabs[0] || 'Sheet1';
      await sheets.spreadsheets.values.update({
        spreadsheetId,
        range: `${primaryTab}!A1:D1`,
        valueInputOption: 'USER_ENTERED',
        requestBody: {
          values: [['Class Roll', 'University Roll', 'Registration Number', 'Student Name']],
        },
      });

      return {
        success: true,
        serviceAccountEmail: email,
        isLiveClient: true,
        sheetTitle,
        tabs,
      };
    } catch (err: any) {
      let fix = 'Please verify that the Google Spreadsheet is shared with the Service Account email as Editor.';
      if (err.message.includes('403') || err.message.includes('permission') || err.message.includes('PERMISSION_DENIED')) {
        fix = `Permission Denied. Open your Google Sheet -> Click 'Share' -> Add '${email}' with 'Editor' permissions.`;
      } else if (err.message.includes('404') || err.message.includes('not found') || err.message.includes('NOT_FOUND')) {
        fix = 'Spreadsheet ID not found. Please verify the ID from your Google Sheet URL: /d/[ID]/edit';
      } else if (err.message.includes('API has not been used') || err.message.includes('disabled')) {
        fix = 'Google Sheets API is disabled. Please enable "Google Sheets API" in your Google Cloud Console.';
      }

      return {
        success: false,
        serviceAccountEmail: email,
        isLiveClient: true,
        error: err.message,
        fixSuggestion: fix,
      };
    }
  }
}

