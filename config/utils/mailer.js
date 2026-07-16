// utils/mailer.js
const nodemailer = require("nodemailer");

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: process.env.SMTP_PORT,
  secure: process.env.SMTP_PORT == 465,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

// Send customer feedback email
exports.sendFeedbackEmail = async (customerEmail, customerName, feedbackLink) => {
  const mailOptions = {
    from: `"Maliram Jewellers" <${process.env.SMTP_USER}>`,
    to: customerEmail,
    subject: "Your feedback matters to us",
    html: `
      <div style="font-family: Georgia, 'Times New Roman', serif; max-width: 560px; margin: auto; background:#ffffff; border:1px solid #eee;">
        
        <div style="background:#1a1a1a; padding:24px 32px; text-align:center;">
          <h1 style="color:#c9a227; margin:0; font-size:22px; letter-spacing:1px; font-weight:normal;">
            MALIRAM JEWELLERS
          </h1>
        </div>

        <div style="padding:32px;">
          <p style="font-size:15px; color:#333; margin:0 0 16px;">Dear ${customerName},</p>

          <p style="font-size:15px; color:#333; line-height:1.6; margin:0 0 20px;">
            Thank you for choosing Maliram Jewellers. It was a pleasure having you with us,
            and we hope you found something truly special.
          </p>

          <p style="font-size:15px; color:#333; line-height:1.6; margin:0 0 24px;">
            Your experience matters to us, and we would be grateful if you could take
            a moment to share your feedback. Your insights help us continue to serve
            you better.
          </p>

          <div style="text-align:center; margin:28px 0;">
            <a href="${feedbackLink}"
               style="display:inline-block; padding:14px 36px; background:#c9a227;
               color:#ffffff; text-decoration:none; border-radius:4px; font-size:14px;
               letter-spacing:0.5px;">
              SHARE YOUR FEEDBACK
            </a>
          </div>

          <p style="font-size:15px; color:#333; line-height:1.6; margin:0 0 8px;">
            Warm regards,
          </p>
          <p style="font-size:15px; color:#333; margin:0;">
            Team Maliram Jewellers
          </p>
        </div>

        <div style="border-top:1px solid #eee; padding:20px 32px; text-align:center;">
          <p style="font-size:12px; color:#999; margin:0;">
            If the button above doesn't work, copy and paste this link into your browser:
          </p>
          <p style="font-size:12px; color:#999; word-break:break-all; margin:6px 0 0;">
            ${feedbackLink}
          </p>
        </div>

      </div>
    `,
  };

  await transporter.sendMail(mailOptions);
};
// OTP Email
exports.sendOtpEmail = async (toEmail, employeeName, otp) => {
  const mailOptions = {
    from: `"Maliram Jewellers CRM" <${process.env.SMTP_USER}>`,
    to: toEmail,
    subject: "Your CRM Login OTP",
    html: `
      <div style="font-family:Arial,sans-serif;max-width:400px;margin:auto;">
        <h2>Hi ${employeeName},</h2>

        <p>Your login OTP is:</p>

        <div style="
          font-size:32px;
          font-weight:bold;
          letter-spacing:6px;
          background:#f4f4f4;
          padding:15px;
          text-align:center;
          border-radius:8px;
          margin:20px 0;
        ">
          ${otp}
        </div>

        <p>This OTP is valid for 5 minutes.</p>
      </div>
    `,
  };

  await transporter.sendMail(mailOptions);
};