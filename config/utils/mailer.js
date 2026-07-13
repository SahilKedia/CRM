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
    subject: "We'd love your feedback!",
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 500px; margin: auto;">
        <h2>Hi ${customerName},</h2>

        <p>Thank you for visiting us! We'd really appreciate it if you could take
        a minute to share your feedback about your visit.</p>

        <a href="${feedbackLink}"
           style="display:inline-block;padding:12px 24px;background:#c9a227;
           color:#fff;text-decoration:none;border-radius:6px;margin-top:10px;">
          Give Feedback
        </a>

        <p style="margin-top:20px;font-size:12px;color:#888;">
          If the button doesn't work, copy this link:
          <br>
          ${feedbackLink}
        </p>
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