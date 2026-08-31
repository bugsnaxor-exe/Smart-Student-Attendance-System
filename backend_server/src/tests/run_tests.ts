import { GeofenceService } from '../services/geofence_service';
import { GoogleSheetsService } from '../services/sheets_service';

let passedTests = 0;
let totalTests = 0;

function assert(condition: boolean, testName: string) {
  totalTests++;
  if (condition) {
    console.log(`  ✅ PASS: ${testName}`);
    passedTests++;
  } else {
    console.error(`  ❌ FAIL: ${testName}`);
  }
}

async function runTestSuite() {
  console.log('\n🧪 ========================================================');
  console.log('🧪 SMART ATTENDANCE SYSTEM - AUTOMATED VERIFICATION SUITE');
  console.log('🧪 ========================================================\n');

  // ----------------------------------------------------
  // TEST GROUP 1: Geofencing & Haversine 50m Calculation
  // ----------------------------------------------------
  console.log('📍 [Test 1] Geofencing & Haversine Distance (50m Radius)');
  const deptLat = 22.5726;
  const deptLon = 88.3639;

  // Exact point (0m)
  const zeroDistance = GeofenceService.calculateHaversineDistance(deptLat, deptLon, deptLat, deptLon);
  assert(zeroDistance === 0, 'Distance to exact department location is 0m');

  // Point ~20m away (lat + 0.00018 deg)
  const nearLat = 22.57278;
  const nearLon = 88.3639;
  const nearDistance = GeofenceService.calculateHaversineDistance(deptLat, deptLon, nearLat, nearLon);
  const nearValidation = GeofenceService.validateStudentLocation(nearLat, nearLon, deptLat, deptLon, 50.0, false);
  assert(nearDistance < 50 && nearValidation.isValid, `Point within 50m (${nearDistance}m) is accepted`);

  // Point ~120m away
  const farLat = 22.5737;
  const farLon = 88.3639;
  const farDistance = GeofenceService.calculateHaversineDistance(deptLat, deptLon, farLat, farLon);
  const farValidation = GeofenceService.validateStudentLocation(farLat, farLon, deptLat, deptLon, 50.0, false);
  assert(farDistance > 50 && !farValidation.isValid, `Point outside 50m (${farDistance}m) is rejected`);

  // ----------------------------------------------------
  // TEST GROUP 2: Anti-GPS Spoofing & Mock Location Rejection
  // ----------------------------------------------------
  console.log('\n🛡️ [Test 2] Anti-GPS Spoofing & Fake GPS Rejection');
  const mockValidation = GeofenceService.validateStudentLocation(
    deptLat,
    deptLon,
    deptLat,
    deptLon,
    50.0,
    true // isMockLocation flag from fake GPS app
  );
  assert(
    !mockValidation.isValid && (mockValidation.reason?.includes('Fake/Mock GPS detected') ?? false),
    'Mock GPS / Spoofed location is immediately blocked even if coordinates match department'
  );

  // ----------------------------------------------------
  // TEST GROUP 3: Standard College Hours (10:15 AM - 5:00 PM)
  // ----------------------------------------------------
  console.log('\n⏰ [Test 3] Standard College Hours Validation (10:15 AM - 5:00 PM)');

  // 10:14 AM (Rejected)
  const timeBefore = new Date(2026, 7, 31, 10, 14, 0);
  const valBefore = GeofenceService.validateCollegeHours(timeBefore);
  assert(!valBefore.isValid, '10:14 AM is rejected (before 10:15 AM opening)');

  // 10:15 AM (Accepted)
  const timeOpen = new Date(2026, 7, 31, 10, 15, 0);
  const valOpen = GeofenceService.validateCollegeHours(timeOpen);
  assert(valOpen.isValid, '10:15 AM is accepted (exact opening)');

  // 2:30 PM (Accepted)
  const timeMidday = new Date(2026, 7, 31, 14, 30, 0);
  const valMidday = GeofenceService.validateCollegeHours(timeMidday);
  assert(valMidday.isValid, '2:30 PM is accepted (during standard hours)');

  // 5:00 PM (Accepted)
  const timeClose = new Date(2026, 7, 31, 17, 0, 0);
  const valClose = GeofenceService.validateCollegeHours(timeClose);
  assert(valClose.isValid, '5:00 PM is accepted (exact closing)');

  // 5:01 PM (Rejected)
  const timeAfter = new Date(2026, 7, 31, 17, 1, 0);
  const valAfter = GeofenceService.validateCollegeHours(timeAfter);
  assert(!valAfter.isValid, '5:01 PM is rejected (after 5:00 PM close)');

  // ----------------------------------------------------
  // TEST GROUP 4: Google Sheets Row Schema Validation
  // ----------------------------------------------------
  console.log('\n📊 [Test 4] Google Sheets Row Schema & Service Account Sync');
  const sampleRow = {
    date: '2026-08-31',
    classRoll: 'CSE-2023-042',
    universityRoll: '12000123042',
    registrationNumber: 'REG-2023-8891',
    studentName: 'Sayan Banerjee',
    status: 'Full' as const,
  };

  const sheetsResult = await GoogleSheetsService.appendAttendanceRow('sample_test_sheet_id', sampleRow);
  assert(sheetsResult.success, 'Google Sheets row appended with Date, Class Roll, Uni Roll, Reg No, Name, Status');

  const halfAttendanceRow = {
    date: '2026-08-31',
    classRoll: 'CSE-2023-015',
    universityRoll: '12000123015',
    registrationNumber: 'REG-2023-8864',
    studentName: 'Jane Smith',
    status: 'Half' as const,
  };

  const halfResult = await GoogleSheetsService.appendAttendanceRow('sample_test_sheet_id', halfAttendanceRow);
  assert(halfResult.success, 'Teacher Manual Override ("Half") row format accepted');

  // Summary
  console.log('\n========================================================');
  console.log(`📊 TEST RESULTS: ${passedTests}/${totalTests} TESTS PASSED (${Math.round((passedTests / totalTests) * 100)}%)`);
  console.log('========================================================\n');
}

runTestSuite().catch(console.error);
