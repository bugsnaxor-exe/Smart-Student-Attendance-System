export interface SendOtpOptions {
  toEmail: string;
  recipientName?: string;
  otpCode: string;
  expiresInMinutes?: number;
}

export class EmailService {
  /**
   * Sends a beautifully branded 6-digit security OTP to the faculty member's email.
   */
  public static async sendFacultyLoginOtp(options: SendOtpOptions): Promise<{ success: boolean; message: string }> {
    const { toEmail, recipientName = 'Faculty Member', otpCode, expiresInMinutes = 5 } = options;

    const brevoApiKey = process.env.BREVO_API_KEY?.trim();
    const resendApiKey = process.env.RESEND_API_KEY?.trim();

    console.log('\n======================================================');
    console.log(`🔐 [SECURITY 2FA] GENERATED OTP FOR: ${toEmail}`);
    console.log(`👉 6-DIGIT VERIFICATION CODE: [ ${otpCode} ]`);
    console.log(`⏳ VALID FOR: ${expiresInMinutes} MINUTES`);
    console.log('======================================================\n');

    const htmlContent = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #FAF7F0; margin: 0; padding: 24px; }
          .container { max-width: 520px; margin: 0 auto; background: #ffffff; border-radius: 20px; border: 1px solid #E8E2D4; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.06); }
          .header { background-color: #1C1E21; color: #ffffff; padding: 28px 24px; text-align: center; }
          .badge { display: inline-block; background-color: #0D7A68; color: #ffffff; font-size: 11px; font-weight: bold; text-transform: uppercase; letter-spacing: 1px; padding: 4px 12px; border-radius: 999px; margin-bottom: 8px; }
          .title { font-size: 20px; font-weight: 800; margin: 0; }
          .body-content { padding: 32px 24px; color: #1C1E21; line-height: 1.6; }
          .otp-card { background: #FAF7F0; border: 2px dashed #0D7A68; border-radius: 16px; text-align: center; padding: 20px; margin: 24px 0; }
          .otp-code { font-size: 34px; font-weight: 900; letter-spacing: 8px; color: #0D7A68; font-family: monospace; }
          .expiry { font-size: 12px; color: #71717A; margin-top: 6px; font-weight: 600; }
          .warning-box { background: #FFF1F2; border-left: 4px solid #E11D48; padding: 14px; border-radius: 8px; font-size: 12px; color: #9F1239; margin-top: 20px; }
          .footer { padding: 20px 24px; background: #FAF7F0; border-top: 1px solid #E8E2D4; text-align: center; font-size: 11px; color: #71717A; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <span class="badge">Faculty 2FA Security</span>
            <h1 class="title">Smart Attendance System</h1>
          </div>
          <div class="body-content">
            <p style="font-size: 14px; margin-top: 0;">Hello <strong>${recipientName}</strong>,</p>
            <p style="font-size: 13px; color: #4B5563;">A sign-in request to the <strong>MCA Faculty Console</strong> was initiated. Use the single-use 6-digit verification code below to authorize your session:</p>
            
            <div class="otp-card">
              <div class="otp-code">${otpCode}</div>
              <div class="expiry">⏱️ Valid for the next ${expiresInMinutes} minutes</div>
            </div>

            <div class="warning-box">
              <strong>⚠️ Did not attempt to log in?</strong><br/>
              A student or unauthorized user may have tried using your password. Since they do not have access to your email, access was blocked. We recommend changing your password.
            </div>
          </div>
          <div class="footer">
            Department of Master of Computer Applications (MCA)<br/>
            Secured with Zero-Trust Student Impersonation Protection
          </div>
        </div>
      </body>
      </html>
    `;

    // 1. Try Brevo API if key is present
    if (brevoApiKey) {
      try {
        const payload = JSON.stringify({
          sender: { name: 'EduAttendance Security', email: 'security@smart-attendance.edu' },
          to: [{ email: toEmail, name: recipientName }],
          subject: `🔐 Your Faculty Login OTP: ${otpCode}`,
          htmlContent: htmlContent,
        });

        const res = await fetch('https://api.brevo.com/v3/smtp/email', {
          method: 'POST',
          headers: {
            'accept': 'application/json',
            'api-key': brevoApiKey,
            'content-type': 'application/json',
          },
          body: payload,
        });

        if (res.ok) {
          console.log(`✅ [Brevo] OTP Email successfully dispatched to ${toEmail}`);
          return { success: true, message: `6-digit verification code sent to ${toEmail}` };
        } else {
          const errBody = await res.text();
          console.warn(`⚠️ [Brevo API Error] ${res.status}: ${errBody}`);
        }
      } catch (err: any) {
        console.warn(`⚠️ [Brevo Network Error]: ${err.message}`);
      }
    }

    // 2. Try Resend API if key is present
    if (resendApiKey) {
      try {
        const payload = JSON.stringify({
          from: 'EduAttendance <onboarding@resend.dev>',
          to: [toEmail],
          subject: `🔐 Your Faculty Login OTP: ${otpCode}`,
          html: htmlContent,
        });

        const res = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${resendApiKey}`,
            'Content-Type': 'application/json',
          },
          body: payload,
        });

        if (res.ok) {
          console.log(`✅ [Resend] OTP Email successfully dispatched to ${toEmail}`);
          return { success: true, message: `6-digit verification code sent to ${toEmail}` };
        }
      } catch (err: any) {
        console.warn(`⚠️ [Resend Network Error]: ${err.message}`);
      }
    }

    // Fallback message (always logs code in console for development/fallback)
    return {
      success: true,
      message: `Verification code generated for ${toEmail}. (Check email / server console)`,
    };
  }
}
