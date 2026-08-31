import { google } from 'googleapis';
import * as fs from 'fs';
import * as path from 'path';

export interface AttendanceSheetRow {
  date: string;              // e.g. "2026-08-31"
  classRoll: string;         // e.g. "CSE-2023-042"
  universityRoll: string;    // e.g. "12000123042"
  registrationNumber: string;// e.g. "REG-2023-8891"
  studentName: string;       // e.g. "John Doe"
  status: 'Full' | 'Half';   // "Full" or "Half"
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
   * Ensures the header row exists in the teacher's Google Sheet tab:
   * Columns: Date | Class Roll | University Roll | Registration Number | Student Name | Status
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
      // Check if tab exists, and read A1:F1
      const range = `${tabName}!A1:F1`;
      const response = await sheets.spreadsheets.values.get({
        spreadsheetId,
        range,
      });

      const rows = response.data.values;
      if (!rows || rows.length === 0 || rows[0].length === 0) {
        // Write the standard headers
        const expectedHeaders = [
          'Date',
          'Class Roll',
          'University Roll',
          'Registration Number',
          'Student Name',
          'Status',
        ];

        await sheets.spreadsheets.values.update({
          spreadsheetId,
          range: `${tabName}!A1:F1`,
          valueInputOption: 'USER_ENTERED',
          requestBody: {
            values: [expectedHeaders],
          },
        });
        console.log(`✅ Initialized headers in Google Sheet ID: ${spreadsheetId} [${tabName}]`);
      }
      return true;
    } catch (error: any) {
      console.error(`❌ Error ensuring headers in Google Sheet (${spreadsheetId}):`, error.message);
      return false;
    }
  }

  /**
   * Appends an attendance record to the Teacher's Google Sheet.
   * Row format: [Date, Class Roll, University Roll, Registration Number, Student Name, Status]
   */
  public static async appendAttendanceRow(
    spreadsheetId: string,
    rowData: AttendanceSheetRow,
    tabName: string = 'Attendance'
  ): Promise<{ success: boolean; message: string }> {
    const sheets = this.getClient();

    // Prepare exact row values requested
    const values = [
      [
        rowData.date,
        rowData.classRoll,
        rowData.universityRoll,
        rowData.registrationNumber,
        rowData.studentName,
        rowData.status,
      ],
    ];

    if (!sheets) {
      console.log(
        `📊 [Simulated GSheets Append] Sheet: ${spreadsheetId} | Row: [${values[0].join(' | ')}]`
      );
      return {
        success: true,
        message: 'Attendance logged successfully (Dev / Simulated Mode).',
      };
    }

    try {
      await this.ensureSheetHeaders(spreadsheetId, tabName);

      const range = `${tabName}!A:F`;
      await sheets.spreadsheets.values.append({
        spreadsheetId,
        range,
        valueInputOption: 'USER_ENTERED',
        insertDataOption: 'INSERT_ROWS',
        requestBody: {
          values,
        },
      });

      console.log(
        `✅ Successfully synced attendance to Google Sheet: ${spreadsheetId} (${rowData.studentName} - ${rowData.status})`
      );
      return {
        success: true,
        message: 'Successfully recorded in Google Sheets.',
      };
    } catch (error: any) {
      console.error(`❌ Failed to append row to Google Sheet (${spreadsheetId}):`, error.message);
      return {
        success: false,
        message: `Google Sheets sync failed: ${error.message}`,
      };
    }
  }
}
