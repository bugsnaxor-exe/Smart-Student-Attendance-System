import { Response } from 'express';
import { AuthRequest } from '../middleware/auth_middleware';
import { prisma } from '../config/database';

export class GeofenceController {
  /**
   * Returns current Department coordinates and geofence radius.
   */
  public static async getDepartmentGeofence(req: AuthRequest, res: Response) {
    try {
      const { departmentId } = req.params;

      const department = await prisma.department.findUnique({
        where: { id: departmentId },
      });

      if (!department) {
        return res.status(404).json({ error: 'Department not found.' });
      }

      return res.json({
        department: {
          id: department.id,
          name: department.name,
          code: department.code,
          latitude: department.latitude,
          longitude: department.longitude,
          radiusMeters: department.radiusMeters,
        },
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }

  /**
   * Admin-only: Updates Department coordinates and geofenced radius.
   */
  public static async updateDepartmentGeofence(req: AuthRequest, res: Response) {
    try {
      const { departmentId } = req.params;
      const { latitude, longitude, radiusMeters } = req.body;

      if (latitude === undefined || longitude === undefined) {
        return res.status(400).json({ error: 'Latitude and Longitude are required.' });
      }

      const updatedDept = await prisma.department.update({
        where: { id: departmentId },
        data: {
          latitude: parseFloat(latitude),
          longitude: parseFloat(longitude),
          radiusMeters: radiusMeters ? parseFloat(radiusMeters) : 50.0,
        },
      });

      return res.json({
        message: `Department geofence updated successfully (Radius: ${updatedDept.radiusMeters}m).`,
        department: updatedDept,
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }
}
