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

// Notify Sahil when a customer sends a "could be better" WhatsApp suggestion
exports.sendFeedbackNotificationEmail = async ({
  customerName,
  customerPhone,
  address,
  branch,
  visitDate,
  purposeOfVisit,
  whoAttend,
  comment,
}) => {
  const formattedDate = visitDate
    ? new Date(visitDate).toLocaleDateString("en-IN", {
        day: "numeric",
        month: "long",
        year: "numeric",
      })
    : "N/A";

  const mailOptions = {
    from: `"Maliram Jewellers CRM" <${process.env.SMTP_USER}>`,
    to: "sahil@maliramjewellers.com",
    subject: `New Customer Feedback — ${customerName || "Unknown Customer"}`,
    html: `
      <div style="font-family:'Segoe UI',Arial,sans-serif;max-width:520px;margin:auto;background:#ffffff;border:1px solid #eee;border-radius:10px;overflow:hidden;">
        
        <div style="background:#1a1a1a;padding:20px 28px;">
          <h1 style="color:#c9a227;margin:0;font-size:18px;letter-spacing:1px;font-weight:normal;">
            MALIRAM JEWELLERS
          </h1>
          <p style="color:#aaa;margin:4px 0 0;font-size:12px;">CRM — WhatsApp Feedback Alert</p>
        </div>

        <div style="padding:28px;">
          <h2 style="margin:0 0 4px;font-size:20px;color:#1a1a1a;">New Customer Feedback</h2>
          <p style="color:#777;margin:0 0 20px;font-size:14px;">A customer marked their visit as "Could be better" and shared a suggestion via WhatsApp.</p>

          <table style="width:100%;border-collapse:collapse;margin-bottom:20px;">
            <tr>
              <td style="padding:8px 0;color:#888;font-size:13px;width:130px;border-bottom:1px solid #f0f0f0;">Customer</td>
              <td style="padding:8px 0;font-size:14px;font-weight:600;color:#1a1a1a;border-bottom:1px solid #f0f0f0;">${customerName || "Unknown"}</td>
            </tr>
            <tr>
              <td style="padding:8px 0;color:#888;font-size:13px;border-bottom:1px solid #f0f0f0;">Phone</td>
              <td style="padding:8px 0;font-size:14px;color:#1a1a1a;border-bottom:1px solid #f0f0f0;">${customerPhone || "N/A"}</td>
            </tr>
            <tr>
              <td style="padding:8px 0;color:#888;font-size:13px;border-bottom:1px solid #f0f0f0;">Address</td>
              <td style="padding:8px 0;font-size:14px;color:#1a1a1a;border-bottom:1px solid #f0f0f0;">${address || "N/A"}</td>
            </tr>
            <tr>
              <td style="padding:8px 0;color:#888;font-size:13px;border-bottom:1px solid #f0f0f0;">Branch</td>
              <td style="padding:8px 0;font-size:14px;color:#1a1a1a;border-bottom:1px solid #f0f0f0;">${branch || "N/A"}</td>
            </tr>
            <tr>
              <td style="padding:8px 0;color:#888;font-size:13px;border-bottom:1px solid #f0f0f0;">Visit Date</td>
              <td style="padding:8px 0;font-size:14px;color:#1a1a1a;border-bottom:1px solid #f0f0f0;">${formattedDate}</td>
            </tr>
            <tr>
              <td style="padding:8px 0;color:#888;font-size:13px;border-bottom:1px solid #f0f0f0;">Purpose of Visit</td>
              <td style="padding:8px 0;font-size:14px;color:#1a1a1a;border-bottom:1px solid #f0f0f0;">${purposeOfVisit || "N/A"}</td>
            </tr>
            <tr>
              <td style="padding:8px 0;color:#888;font-size:13px;">Attended By</td>
              <td style="padding:8px 0;font-size:14px;color:#1a1a1a;">${whoAttend || "N/A"}</td>
            </tr>
          </table>

          <p style="margin:0 0 8px;color:#888;font-size:13px;">Suggestion</p>
          <div style="background:#faf8f2;border-left:3px solid #c9a227;padding:14px 16px;border-radius:4px;">
            <p style="margin:0;white-space:pre-wrap;font-size:14px;color:#333;line-height:1.5;">${comment}</p>
          </div>
        </div>

        <div style="border-top:1px solid #eee;padding:14px 28px;text-align:center;">
          <p style="font-size:11px;color:#aaa;margin:0;">Sent automatically by Maliram Jewellers CRM</p>
        </div>
      </div>
    `,
  };

  await transporter.sendMail(mailOptions);
};

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
             <a href="${feedbackLink}" target="_blank"
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