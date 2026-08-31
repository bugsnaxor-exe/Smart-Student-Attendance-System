import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import http from 'http';
import { WebSocketServer, WebSocket } from 'ws';
import { connectDB } from './config/database';
import { requireAuth, requireRole } from './middleware/auth_middleware';
import { AuthController } from './controllers/auth_controller';
import { SessionController } from './controllers/session_controller';
import { AttendanceController, registerAttendanceBroadcaster } from './controllers/attendance_controller';
import { OverrideController } from './controllers/override_controller';
import { GeofenceController } from './controllers/geofence_controller';
import { SheetsController } from './controllers/sheets_controller';

import path from 'path';

dotenv.config();

const app = express();
const server = http.createServer(app);
const wss = new WebSocketServer({ server, path: '/ws' });

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, '../public')));

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

// Register real-time broadcaster
registerAttendanceBroadcaster((payload: any) => {
  const message = JSON.stringify(payload);
  for (const client of connectedClients) {
    if (client.readyState === WebSocket.OPEN) {
      client.send(message);
    }
  }
});

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
app.get('/api/auth/me', requireAuth, AuthController.getMe);

// --- SESSION ROUTES (15-Minute Dynamic Window) ---
app.post('/api/sessions/start', requireAuth, requireRole(['TEACHER', 'ADMIN']), SessionController.startSession);
app.get('/api/sessions/active/:subjectId', requireAuth, SessionController.getActiveSession);
app.get('/api/sessions/student-active', requireAuth, SessionController.getStudentActiveSessions);
app.post('/api/sessions/close/:sessionId', requireAuth, requireRole(['TEACHER', 'ADMIN']), SessionController.closeSession);

// --- ATTENDANCE ROUTES ---
app.post('/api/attendance/mark', requireAuth, AttendanceController.markAttendance);
app.get('/api/attendance/student/dashboard', requireAuth, AttendanceController.getStudentDashboardStats);
app.get('/api/attendance/student/subject-history/:subjectId', requireAuth, AttendanceController.getStudentSubjectAttendanceHistory);
app.get('/api/attendance/teacher/:subjectId', requireAuth, requireRole(['TEACHER', 'ADMIN']), AttendanceController.getTeacherSubjectAttendance);

// --- TEACHER OVERRIDE ROUTES (Full / Half Attendance) ---
app.get('/api/override/absent/:subjectId', requireAuth, requireRole(['TEACHER', 'ADMIN']), OverrideController.getAbsentStudentsForSubject);
app.post('/api/override/grant-half', requireAuth, requireRole(['TEACHER', 'ADMIN']), OverrideController.grantHalfAttendance);

// --- GEOFENCE CONFIG ROUTES ---
app.get('/api/geofence/:departmentId', requireAuth, GeofenceController.getDepartmentGeofence);
app.put('/api/geofence/:departmentId', requireAuth, requireRole(['ADMIN']), GeofenceController.updateDepartmentGeofence);

// --- GOOGLE SHEETS ROUTES ---
app.get('/api/sheets/service-account', requireAuth, SheetsController.getServiceAccountInfo);
app.post('/api/sheets/link/:subjectId', requireAuth, requireRole(['TEACHER', 'ADMIN']), SheetsController.linkSubjectSheet);

const PORT = process.env.PORT || 4000;

server.listen(PORT, async () => {
  await connectDB();
  console.log(`🚀 Smart Attendance Server listening on http://localhost:${PORT}`);
  console.log(`📡 WebSocket Realtime Server ready at ws://localhost:${PORT}/ws`);
});
