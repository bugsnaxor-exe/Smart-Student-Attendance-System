# 🎓 Smart Geofenced Student Attendance System

> A cross-platform mobile attendance management application with server-side GPS geofencing, anti-spoofing verification, 15-minute dynamic session cutoffs, and real-time Google Sheets dispatch.

---

## 🌟 Key Highlights

- 📍 **50-Meter Server-Side Geofencing**: Precise Haversine distance validation around department GPS coordinates.
- 🛡️ **Anti-GPS Spoofing**: Detects and rejects mock locations and fake GPS tools.
- ⏰ **Strict College Window**: Enforces check-ins strictly between **10:15 AM – 5:00 PM**.
- ⏱️ **15-Minute Dynamic TTL Cutoff**: Sessions expire automatically 15 minutes after the teacher starts them.
- 📊 **Real-time Google Sheets Dispatch**: Appends attendance records (`Date | Class Roll | University Roll | Registration No | Student Name | Status`) directly to the teacher's Google Sheet via Service Account OAuth2 JWT.
- ⚡ **Latecomer Manual Override**: Allows faculty to grant "Half" attendance for late students.
- 📚 **MCA 4-Semester Curriculum**: Complete pre-loaded syllabus (31 courses, 125 credits, 3350 marks).
- 🎨 **Classic Minimalist Theme**: Custom palette featuring **Cream** (`#FAF7F0`), **Sea Green** (`#0D7A68`), and **Charcoal** (`#1C1E21`).

---

## 🏗️ Project Architecture

```
smart_attendance_system/
├── backend_server/               # Node.js + Express + TypeScript + Prisma Backend
│   ├── prisma/
│   │   └── schema.prisma         # Models: User, Department, Student, Teacher, Subject, Session, Attendance
│   ├── src/
│   │   ├── controllers/          # Auth, Attendance, Sessions, Overrides, Geofence, Sheets
│   │   ├── services/             # Geofence (Haversine), Google Sheets API v4, Session Manager
│   │   ├── config/               # Database connection & MCA Syllabus Seeder
│   │   ├── tests/                # 11/11 Automated Verification Test Suite
│   │   └── server.ts             # Express REST API + WebSocket Realtime Stream
│   └── public/
│       └── index.html            # Dual-Screen Web Simulator (Student App + Faculty Portal)
│
└── mobile_app/                   # Cross-Platform Flutter Mobile App (Android & iOS)
    └── lib/
        ├── core/theme/           # Classic Minimalist Theme (Cream, Sea Green, Charcoal)
        ├── models/               # Attendance & Subject Syllabus Data Models
        ├── providers/            # Auth, Attendance & Location State Management
        ├── screens/
        │   ├── auth/             # Login & Student Roll-based Registration
        │   ├── student/          # Dashboard (Aggregate Dial, MCA Courses, Radar Scanner)
        │   └── teacher/          # Session Trigger, Check-in Feed, Manual Override, Sheets
        └── main.dart
```

---

## 📋 Google Sheets Row Schema

Rows are automatically appended to the teacher's linked Google Sheet in the following exact format:

| Date | Class Roll | University Roll | Registration Number | Student Name | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `2026-08-31` | `MCA-26-042` | `12000126042` | `REG-2026-9042` | `Sayan Banerjee` | `Full` |
| `2026-08-31` | `MCA-26-015` | `12000126015` | `REG-2026-9015` | `Jane Smith` | `Half` |

---

## 🚀 Quick Start & Testing

### 1. Start Backend & Web Simulator
```bash
cd backend_server
npm install
npm run seed:mca
npm start
```
Open **[http://localhost:4000](http://localhost:4000)** in your browser for the interactive dual simulator.

### 2. Run Verification Tests
```bash
npm run test
```

### 3. Launch Flutter Mobile App
```bash
cd mobile_app
flutter pub get
flutter run
```

---

## 🧪 Pre-Configured Test Credentials

- **Faculty**: `prof.sharma@college.edu` | `Teacher@123`
- **Sem 1 Student**: `12000126042` | `Student@123` (MCA-101 to MCA-141)
- **Sem 2 Student**: `12000125018` | `Student@123` (MCA-201 to MCA-214)
- **Sem 3 Student**: `12000124007` | `Student@123` (MCA-301 to MCA-321)

---

## 📄 License
MIT License.
