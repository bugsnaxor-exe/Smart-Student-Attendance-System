import { GoogleGenAI } from '@google/genai';

export interface ParsedSubject {
  semester: number;
  code: string;
  name: string;
  type: string;
  credits: number;
  weeklyHours: string;
  marks: string;
}

export class SyllabusParserService {
  /**
   * Helper to robustly extract text from PDF buffer supporting both pdf-parse v1 & v2.
   */
  private static async extractPdfText(pdfBuffer: Buffer): Promise<string> {
    const pdfParsePkg = require('pdf-parse');
    
    // 1. pdf-parse v2 Class API (e.g. pdf-parse@2.4.5)
    if (pdfParsePkg && typeof pdfParsePkg.PDFParse === 'function') {
      const parser = new pdfParsePkg.PDFParse({ data: pdfBuffer });
      const result = await parser.getText();
      return result?.text || '';
    }
    
    // 2. Default export with PDFParse class
    if (pdfParsePkg?.default && typeof pdfParsePkg.default.PDFParse === 'function') {
      const parser = new pdfParsePkg.default.PDFParse({ data: pdfBuffer });
      const result = await parser.getText();
      return result?.text || '';
    }

    // 3. pdf-parse v1 Functional API (e.g. pdf-parse@1.1.1)
    if (typeof pdfParsePkg === 'function') {
      const data = await pdfParsePkg(pdfBuffer);
      return data?.text || '';
    }

    // 4. Default functional export
    if (typeof pdfParsePkg?.default === 'function') {
      const data = await pdfParsePkg.default(pdfBuffer);
      return data?.text || '';
    }

    throw new Error('Could not initialize PDF parser engine.');
  }

  /**
   * Extracts text from uploaded PDF buffer, then prompts Gemini to extract structured semester-wise subjects.
   */
  public static async parseSyllabusPdf(pdfBuffer: Buffer): Promise<{
    success: boolean;
    departmentName?: string;
    totalCoursesFound: number;
    subjects: ParsedSubject[];
    message?: string;
  }> {
    try {
      // 1. Extract text from PDF buffer
      const fullText = await this.extractPdfText(pdfBuffer);

      if (!fullText.trim()) {
        return {
          success: false,
          totalCoursesFound: 0,
          subjects: [],
          message: 'The uploaded PDF appears to be empty or contains only non-selectable images without text.',
        };
      }

      // Truncate safely if excessively long (take first 60k characters containing curriculum structure)
      const textSample = fullText.slice(0, 60000);

      // 2. Initialize Gemini API Client
      const apiKey = process.env.GEMINI_API_KEY?.trim();
      if (!apiKey) {
        throw new Error('GEMINI_API_KEY is not configured in backend environment variables.');
      }

      const ai = new GoogleGenAI({ apiKey });

      const prompt = `
You are an expert University Curriculum Data Extractor.
Below is the text extracted from an official College / University Syllabus document (e.g. MAKAUT / Autonomous MCA Curriculum).

TASK:
1. Identify all subjects / courses listed across all Semesters (e.g. Semester 1, Semester 2, Semester 3, Semester 4).
2. For each subject, accurately extract:
   - "semester": integer (1, 2, 3, or 4)
   - "code": official course code (e.g., "MCA-101", "MCA-203", "MCA-311")
   - "name": full title of the subject (e.g., "Data and File Structures", "Artificial Intelligence & Machine Learning")
   - "type": "Theory" or "Practical" or "Bridge Course" or "Project" or "Viva"
   - "credits": integer credit value (e.g., 4, 3, 2)
   - "weeklyHours": contact hours format like "3+1+0" or "0+0+3" (default to "3+1+0" for Theory, "0+0+3" for Practical if unspecified)
   - "marks": total evaluation marks like "100 (70+30)" or "100" (default "100 (70+30)" for Theory, "100 (40+60)" for Practical)

RETURN FORMAT:
Return ONLY a valid JSON object matching this exact structure:
{
  "departmentName": "Master of Computer Applications (MCA)",
  "subjects": [
    {
      "semester": 1,
      "code": "MCA-101",
      "name": "Mathematical Foundation",
      "type": "Theory",
      "credits": 4,
      "weeklyHours": "3+1+0",
      "marks": "100 (70+30)"
    }
  ]
}

DO NOT include markdown backticks or commentary. Return ONLY the raw JSON object.

--- EXTRACTED SYLLABUS TEXT ---
${textSample}
`;

      const response = await ai.models.generateContent({
        model: 'gemini-2.5-flash',
        contents: prompt,
      });

      const responseText = response.text || '';
      // Clean possible markdown code fence ```json ... ```
      let cleanJsonStr = responseText.trim();
      if (cleanJsonStr.startsWith('```')) {
        cleanJsonStr = cleanJsonStr.replace(/^```(json)?\n?/, '').replace(/\n?```$/, '').trim();
      }

      const parsedResult = JSON.parse(cleanJsonStr);
      const rawSubjects: any[] = parsedResult.subjects || [];

      const sanitizedSubjects: ParsedSubject[] = rawSubjects
        .map((s) => ({
          semester: Number(s.semester) || 1,
          code: String(s.code || '').trim().toUpperCase(),
          name: String(s.name || '').trim(),
          type: String(s.type || (s.code.includes('11') || s.code.includes('LAB') ? 'Practical' : 'Theory')).trim(),
          credits: Number(s.credits) || (s.type === 'Practical' ? 2 : 4),
          weeklyHours: String(s.weeklyHours || (s.type === 'Practical' ? '0+0+3' : '3+1+0')).trim(),
          marks: String(s.marks || '100 (70+30)').trim(),
        }))
        .filter((s) => s.code.length > 0 && s.name.length > 0);

      return {
        success: true,
        departmentName: parsedResult.departmentName || 'Master of Computer Applications (MCA)',
        totalCoursesFound: sanitizedSubjects.length,
        subjects: sanitizedSubjects,
      };
    } catch (error: any) {
      console.error('❌ SyllabusParserService Error:', error.message);
      return {
        success: false,
        totalCoursesFound: 0,
        subjects: [],
        message: `Failed to extract syllabus: ${error.message}`,
      };
    }
  }
}
