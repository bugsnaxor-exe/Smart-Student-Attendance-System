import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import http from 'http';
import { WebSocketServer, WebSocket } from 'ws';
import { connectDB } from './config/database';
import { requireAuth, optionalAuth, requireRole } from './middleware/auth_middleware';
import { AuthController } from './controllers/auth_controller';
import { SessionController, registerSessionBroadcaster } from './controllers/session_controller';
import { AttendanceController, registerAttendanceBroadcaster } from './controllers/attendance_controller';
import { OverrideController, registerOverrideBroadcaster } from './controllers/override_controller';
import { GeofenceController } from './controllers/geofence_controller';
import { SheetsController } from './controllers/sheets_controller';
import { SyllabusController } from './controllers/syllabus_controller';
import { AdminFacultyController } from './controllers/admin_faculty_controller';
import { prisma } from './config/database';
import multer from 'multer';

import path from 'path';

dotenv.config();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 20 * 1024 * 1024 }, // 20MB limit
});

const app = express();
const server = http.createServer(app);
const wss = new WebSocketServer({ server, path: '/ws' });

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, '../public')));
app.get('/favicon.ico', (_req, res) => res.status(204).end());

// Real-Time WebSocket Connections Pool
const connectedClients = new Set<WebSocket>();

wss.on('connection', (ws: WebSocket) => {
  connectedClients.add(ws);
  console.log(`🔌 [WebSocket] New client connected. Total clients: ${connectedClients.size}`);

  ws.on('close', () => {
    connectedClients.delete(ws);
    console.log(`🔌 [WebSocket] Client disconnected. Remaining: ${connectedClients.size}`);
  });

  ws.send(JSON.stringify({ type: 'CONNECTED', message: 'Real-time attendance stream connected.' }));
});

// Helper to broadcast to all clients
function broadcastToAll(payload: any) {
  const message = JSON.stringify(payload);
  for (const client of connectedClients) {
    if (client.readyState === WebSocket.OPEN) {
      client.send(message);
    }
  }
}

// Register real-time broadcasters
registerAttendanceBroadcaster(broadcastToAll);
registerSessionBroadcaster(broadcastToAll);
registerOverrideBroadcaster(broadcastToAll);

// Health check & System Info
app.get('/api/status', (req, res) => {
  res.json({
    system: 'Smart Geofenced College Attendance Backend API',
    status: 'ONLINE',
    version: '1.0.0',
    collegeHours: '10:15 AM - 05:00 PM',
    defaultGeofenceRadius: '50 meters',
    activeCutoffWindow: '15 minutes TTL',
    endpoints: {
      auth: ['/api/auth/register-student', '/api/auth/register-teacher', '/api/auth/login', '/api/auth/me'],
      sessions: ['/api/sessions/start', '/api/sessions/active/:subjectId', '/api/sessions/student-active', '/api/sessions/close/:sessionId'],
      attendance: ['/api/attendance/mark', '/api/attendance/student/dashboard', '/api/attendance/teacher/:subjectId'],
      override: ['/api/override/absent/:subjectId', '/api/override/grant-half'],
      geofence: ['/api/geofence/:departmentId'],
      sheets: ['/api/sheets/service-account', '/api/sheets/link/:subjectId'],
    },
  });
});

// --- AUTH ROUTES ---
app.post('/api/auth/register-student', AuthController.registerStudent);
app.post('/api/auth/register-teacher', AuthController.registerTeacher);
app.post('/api/auth/login', AuthController.login);
app.post('/api/auth/verify-otp', AuthController.verifyOtp);
app.post('/api/auth/resend-otp', AuthController.resendOtp);
app.get('/api/auth/me', requireAuth, AuthController.getMe);

// --- SESSION ROUTES (15-Minute Dynamic Window) ---
app.post('/api/sessions/start', optionalAuth, SessionController.startSession);
app.get('/api/sessions/counts-today', SessionController.getTodayCounts);
app.get('/api/sessions/active/:subjectId', SessionController.getActiveSession);
app.get('/api/sessions/student-active', optionalAuth, SessionController.getStudentActiveSessions);
app.get('/api/sessions/student/active', optionalAuth, SessionController.getStudentActiveSessions);
app.post('/api/sessions/close/:sessionId', optionalAuth, SessionController.closeSession);
app.post('/api/sessions/close-subject/:subjectId', optionalAuth, SessionController.closeSessionBySubject);
app.post('/api/sessions/update-location', optionalAuth, SessionController.updateLocation);

// --- ATTENDANCE ROUTES ---
app.post('/api/attendance/mark', requireAuth, AttendanceController.markAttendance);
app.get('/api/attendance/student/dashboard', requireAuth, AttendanceController.getStudentDashboardStats);
app.get('/api/attendance/student/subject-history/:subjectId', requireAuth, AttendanceController.getStudentSubjectAttendanceHistory);
app.get('/api/attendance/teacher/:subjectId', optionalAuth, AttendanceController.getTeacherSubjectAttendance);

// --- TEACHER OVERRIDE ROUTES (Full / Half Attendance) ---
app.get('/api/override/absent/:subjectId', optionalAuth, OverrideController.getAbsentStudentsForSubject);
app.post('/api/override/grant-half', optionalAuth, OverrideController.grantHalfAttendance);
app.post('/api/override/grant-half-matrix', OverrideController.grantHalfAttendanceMatrix);
app.get('/api/students/semester/:semester', OverrideController.getStudentsBySemester);
app.get('/api/override/students/semester/:semester', OverrideController.getStudentsBySemester);

// --- GEOFENCE CONFIG ROUTES ---
app.get('/api/geofence/:departmentId', requireAuth, GeofenceController.getDepartmentGeofence);
app.put('/api/geofence/:departmentId', requireAuth, requireRole(['ADMIN']), GeofenceController.updateDepartmentGeofence);

// --- GOOGLE SHEETS ROUTES ---
app.get('/api/sheets/service-account', requireAuth, SheetsController.getServiceAccountInfo);
app.get('/api/sheets/active-sheet', SheetsController.getActiveSheet);
app.post('/api/sheets/link-sheet', SheetsController.linkSubjectSheet);
app.post('/api/sheets/link/:subjectId', requireAuth, requireRole(['TEACHER', 'ADMIN']), SheetsController.linkSubjectSheet);
app.post('/api/sheets/test-connection', SheetsController.testConnection);

// --- SYLLABUS & CURRICULUM MANAGEMENT ROUTES (AI Extraction & Multi-Batch) ---
app.post('/api/admin/syllabus/parse-pdf', upload.single('syllabusPdf'), SyllabusController.parsePdf);
app.post('/api/admin/syllabus/apply', SyllabusController.applySyllabus);
app.get('/api/admin/syllabus/batches', SyllabusController.getBatches);

// --- FACULTY ADMIN APPROVAL ROUTES ---
app.get('/api/admin/faculty/pending', optionalAuth, AdminFacultyController.getPendingFaculty);
app.post('/api/admin/faculty/approve/:teacherId', optionalAuth, AdminFacultyController.approveFaculty);
app.post('/api/admin/faculty/reject/:teacherId', optionalAuth, AdminFacultyController.rejectFaculty);

// --- DYNAMIC SUBJECTS QUERY ROUTE ---
app.get('/api/subjects', async (req, res) => {
  try {
    const { semester, batchYear } = req.query;
    const where: any = { isActive: true };
    if (semester) where.semester = Number(semester);
    if (batchYear) where.batchYear = String(batchYear);

    const subjects = await prisma.subject.findMany({
      where,
      orderBy: [{ semester: 'asc' }, { code: 'asc' }],
    });
    res.status(200).json({ subjects });
  } catch (err: any) {
    res.status(500).json({ error: 'Failed to fetch subjects.' });
  }
});

const PORT = process.env.PORT || 4000;

server.listen(PORT, async () => {
  await connectDB();
  console.log(`🚀 Smart Attendance Server listening on http://localhost:${PORT}`);
  console.log(`📡 WebSocket Realtime Server ready at ws://localhost:${PORT}/ws`);
});
