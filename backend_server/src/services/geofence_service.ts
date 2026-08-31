/**
 * Geofence & Location Validation Service
 * - Haversine Distance Calculation (50-meter perimeter)
 * - Anti-GPS Spoofing / Mock Location Rejection
 * - College Hours Verification (10:15 AM - 5:00 PM)
 */

export interface LocationValidationResult {
  isValid: boolean;
  distanceMeters: number;
  reason?: string;
}

export interface TimeValidationResult {
  isValid: boolean;
  formattedTime: string;
  reason?: string;
}

export class GeofenceService {
  /**
   * Calculates the Great-Circle distance between two points in meters using the Haversine Formula.
   */
  public static calculateHaversineDistance(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number
  ): number {
    const R = 6371e3; // Earth's radius in meters
    const phi1 = (lat1 * Math.PI) / 180;
    const phi2 = (lat2 * Math.PI) / 180;
    const deltaPhi = ((lat2 - lat1) * Math.PI) / 180;
    const deltaLambda = ((lon2 - lon1) * Math.PI) / 180;

    const a =
      Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
      Math.cos(phi1) * Math.cos(phi2) * Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);

    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    const distance = R * c;

    return Math.round(distance * 10) / 10; // Round to 1 decimal place
  }

  /**
   * Validates if student's coordinates are within the department's geofenced radius (default: 50m).
   * Also checks for mock location flags and GPS accuracy sanity.
   */
  public static validateStudentLocation(
    studentLat: number,
    studentLon: number,
    deptLat: number,
    deptLon: number,
    radiusMeters: number = 50.0,
    isMockLocation: boolean = false,
    accuracyMeters?: number
  ): LocationValidationResult {
    // 1. Anti-Spoofing / Mock Location Check
    if (isMockLocation) {
      return {
        isValid: false,
        distanceMeters: 0,
        reason: 'Fake/Mock GPS detected. Attendance rejected for security.',
      };
    }

    // 2. Indoor GPS Accuracy Sanity Check
    if (accuracyMeters !== undefined && accuracyMeters > 40) {
      return {
        isValid: false,
        distanceMeters: 0,
        reason: `GPS accuracy too low (${accuracyMeters}m). Please move closer to a window or corridor for better satellite lock.`,
      };
    }

    // 3. Haversine Distance Calculation
    const distance = this.calculateHaversineDistance(studentLat, studentLon, deptLat, deptLon);

    if (distance > radiusMeters) {
      return {
        isValid: false,
        distanceMeters: distance,
        reason: `You are ${distance}m away from the department. Must be within ${radiusMeters}m.`,
      };
    }

    return {
      isValid: true,
      distanceMeters: distance,
    };
  }

  /**
   * Validates if current timestamp is within standard college hours (10:15 AM to 5:00 PM).
   * Standard College Hours:
   *  Start: 10:15 AM (615 minutes from midnight)
   *  End:   5:00 PM (1020 minutes from midnight / 17:00)
   */
  public static validateCollegeHours(date: Date = new Date()): TimeValidationResult {
    // Format time in 12-hour format
    const hours = date.getHours();
    const minutes = date.getMinutes();
    const totalMinutes = hours * 60 + minutes;

    const startMinutes = 10 * 60 + 15; // 10:15 AM -> 615
    const endMinutes = 17 * 60;        // 05:00 PM -> 1020

    const ampm = hours >= 12 ? 'PM' : 'AM';
    const displayHours = hours % 12 || 12;
    const displayMinutes = minutes < 10 ? `0${minutes}` : minutes;
    const formattedTime = `${displayHours}:${displayMinutes} ${ampm}`;

    if (totalMinutes < startMinutes || totalMinutes > endMinutes) {
      return {
        isValid: false,
        formattedTime,
        reason: `Attendance is only permitted during college hours (10:15 AM to 5:00 PM). Current time: ${formattedTime}`,
      };
    }

    return {
      isValid: true,
      formattedTime,
    };
  }
}
