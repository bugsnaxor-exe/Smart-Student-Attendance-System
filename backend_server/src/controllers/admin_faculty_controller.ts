import { Request, Response } from 'express';
import { prisma } from '../config/database';
import { EmailService } from '../services/email_service';

export class AdminFacultyController {
  /**
   * Returns all pending (unapproved) faculty registrations.
   */
  public static async getPendingFaculty(req: Request, res: Response) {
    try {
      const pendingTeachers = await prisma.teacherProfile.findMany({
        where: { isApproved: false },
        include: {
          user: {
            select: {
              id: true,
              name: true,
              email: true,
              role: true,
              createdAt: true,
            },
          },
          department: true,
          subjects: {
            select: {
              id: true,
              code: true,
              name: true,
              semester: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
      });

      return res.status(200).json({
        pendingCount: pendingTeachers.length,
        faculty: pendingTeachers.map((t) => ({
          teacherId: t.id,
          userId: t.user.id,
          name: t.user.name,
          email: t.user.email,
          departmentCode: t.department?.code,
          departmentName: t.department?.name,
          assignedSubject: t.subjects?.[0] ? `${t.subjects[0].code}: ${t.subjects[0].name}` : 'Not assigned',
          registeredAt: t.createdAt,
        })),
      });
    } catch (err: any) {
      console.error('❌ [Admin Faculty Error]:', err);
      return res.status(500).json({ error: 'Failed to retrieve pending faculty requests.' });
    }
  }

  /**
   * Approves a pending faculty member.
   */
  public static async approveFaculty(req: Request, res: Response) {
    try {
      const { teacherId } = req.params;
      if (!teacherId) {
        return res.status(400).json({ error: 'Teacher ID is required.' });
      }

      const teacher = await prisma.teacherProfile.findUnique({
        where: { id: teacherId },
        include: {
          user: true,
          department: true,
        },
      });

      if (!teacher) {
        return res.status(404).json({ error: 'Faculty account not found.' });
      }

      const updated = await prisma.teacherProfile.update({
        where: { id: teacherId },
        data: {
          isApproved: true,
          approvedAt: new Date(),
        },
      });

      // Send confirmation email in background
      EmailService.sendFacultyApprovalEmail({
        toEmail: teacher.user.email,
        recipientName: teacher.user.name,
        departmentName: teacher.department?.name,
      }).catch((e) => console.warn('Could not send approval email:', e.message));

      return res.status(200).json({
        success: true,
        message: `Faculty member ${teacher.user.name} (${teacher.user.email}) has been approved.`,
        teacher: updated,
      });
    } catch (err: any) {
      console.error('❌ [Admin Approve Error]:', err);
      return res.status(500).json({ error: 'Failed to approve faculty account.' });
    }
  }

  /**
   * Rejects and permanently removes a pending faculty registration.
   */
  public static async rejectFaculty(req: Request, res: Response) {
    try {
      const { teacherId } = req.params;
      if (!teacherId) {
        return res.status(400).json({ error: 'Teacher ID is required.' });
      }

      const teacher = await prisma.teacherProfile.findUnique({
        where: { id: teacherId },
        include: { user: true },
      });

      if (!teacher) {
        return res.status(404).json({ error: 'Faculty account not found.' });
      }

      const userName = teacher.user.name;
      const userEmail = teacher.user.email;
      const userId = teacher.userId;

      // Deleting the user will cascade delete the teacher profile
      await prisma.user.delete({
        where: { id: userId },
      });

      console.log(`🗑️ [Admin Faculty Reject] Deleted unapproved faculty registration for ${userName} (${userEmail})`);

      return res.status(200).json({
        success: true,
        message: `Rejected and removed registration request for ${userName} (${userEmail}).`,
      });
    } catch (err: any) {
      console.error('❌ [Admin Reject Error]:', err);
      return res.status(500).json({ error: 'Failed to reject faculty account.' });
    }
  }
}
