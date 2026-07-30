const axios = require("axios");

const sendFeedbackWhatsApp = async (customerPhone, customerName) => {
  try {
    let phone = String(customerPhone).replace(/\D/g, "");

    if (phone.length === 10) {
      phone = "91" + phone;
    }

    const payload = {
      messaging_product: "whatsapp",
      recipient_type: "individual",
      to: phone,
      type: "template",
      template: {
        name: "visit_thankyou_optin",
        language: {
          code: "en",
        },
        components: [
          {
            type: "header",
            parameters: [
              {
                type: "image",
                image: {
                  link: process.env.WHATSAPP_HEADER_IMAGE_URL,
                },
              },
            ],
          },
          {
            type: "body",
            parameters: [
              {
                type: "text",
                text: customerName,
              },
            ],
          },
        ],
      },
    };

    console.log(
      "Sending WhatsApp Template:",
      JSON.stringify(payload, null, 2)
    );

    const response = await axios.post(
      `https://graph.facebook.com/v23.0/${process.env.WHATSAPP_PHONE_NUMBER_ID}/messages`,
      payload,
      {
        headers: {
          Authorization: `Bearer ${process.env.WHATSAPP_ACCESS_TOKEN}`,
          "Content-Type": "application/json",
        },
      }
    );

    console.log("✅ WhatsApp Success");
    console.log(response.data);

    return response.data;
  } catch (err) {
    console.error("❌ WhatsApp Error");

    if (err.response) {
      console.error(JSON.stringify(err.response.data, null, 2));
    } else {
      console.error(err.message);
    }

    throw err;
  }
};
 const sendPlainWhatsAppMessage = async (toPhone, text) => {
  try {
    const payload = {
      messaging_product: "whatsapp",
      recipient_type: "individual",
      to: toPhone,
      type: "text",
      text: { body: text },
    };

    const response = await axios.post(
      `https://graph.facebook.com/v23.0/${process.env.WHATSAPP_PHONE_NUMBER_ID}/messages`,
      payload,
      {
        headers: {
          Authorization: `Bearer ${process.env.WHATSAPP_ACCESS_TOKEN}`,
          "Content-Type": "application/json",
        },
      }
    );

    console.log("✅ Plain message sent:", response.data);
    return response.data;
  } catch (err) {
    console.error("❌ Plain message error:", err.response?.data || err.message);
    throw err;
  }
};

module.exports = {
  sendFeedbackWhatsApp,
  sendPlainWhatsAppMessage, // isko bhi export list mein add karo
};
