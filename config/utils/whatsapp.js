// utils/whatsapp.js
const axios = require("axios");

const WHATSAPP_API_URL = `https://graph.facebook.com/v20.0/${process.env.WHATSAPP_PHONE_NUMBER_ID}/messages`;

// Send customer feedback message via WhatsApp
exports.sendFeedbackWhatsApp = async (customerPhone, customerName, googleReviewLink) => {
  try {
    // Ensure phone number has country code, no +, no spaces
    let formattedPhone = customerPhone.replace(/\D/g, ""); // strip non-digits
    if (!formattedPhone.startsWith("91")) {
      formattedPhone = `91${formattedPhone}`;
    }

    const response = await axios.post(
      WHATSAPP_API_URL,
      {
        messaging_product: "whatsapp",
        to: formattedPhone,
        type: "template",
        template: {
          name: "maliram_jeweller", // exact template name from WhatsApp Manager
          language: { code: "en" },
          components: [
            {
              type: "body",
              parameters: [
                { type: "text", text: customerName },
                { type: "text", text: googleReviewLink },
              ],
            },
          ],
        },
      },
      {
        headers: {
          Authorization: `Bearer ${process.env.WHATSAPP_ACCESS_TOKEN}`,
          "Content-Type": "application/json",
        },
      }
    );

    return response.data;
  } catch (error) {
    console.error("WhatsApp send error:", error.response?.data || error.message);
    throw error;
  }
};