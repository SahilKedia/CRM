// backend/utils/whatsapp.js
const axios = require("axios");

const WHATSAPP_API_URL = `https://graph.facebook.com/v20.0/${process.env.WHATSAPP_PHONE_NUMBER_ID}/messages`;

// Header image for the template — use your own permanently-hosted logo URL.
// Falls back to an env variable so you can change it without touching code.
const HEADER_IMAGE_URL =
  process.env.WHATSAPP_HEADER_IMAGE_URL || "http://159.223.151.37:5000/uploads/logo.jpg";

// Send customer feedback message via WhatsApp
exports.sendFeedbackWhatsApp = async (customerPhone, customerName) => {
  try {
    // Ensure phone number has country code, no +, no spaces
    let formattedPhone = customerPhone.replace(/\D/g, ""); // strip non-digits
    // A plain 10-digit Indian mobile number has no country code yet.
    // Checking startsWith("91") is unreliable — plenty of real numbers
    // (e.g. 91xxxxxxxx) legitimately start with those two digits.
    if (formattedPhone.length === 10) {
      formattedPhone = `91${formattedPhone}`;
    }

    const response = await axios.post(
      WHATSAPP_API_URL,
      {
        messaging_product: "whatsapp",
        to: formattedPhone,
        type: "template",
        template: {
          name: "maliram_jewellers", // exact template name from WhatsApp Manager
          language: { code: "en" },
          components: [
            {
              type: "header",
              parameters: [
                {
                  type: "image",
                  image: { link: HEADER_IMAGE_URL },
                },
              ],
            },
            {
              type: "body",
              parameters: [
                { type: "text", text: customerName }, // only {{1}} — review link is now a static button, no longer a variable
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
