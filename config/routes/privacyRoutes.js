const express = require("express");
const router = express.Router();

router.get("/privacy-policy", (req, res) => {
  res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Privacy Policy - Maliram CRM</title>

<style>
body{
    font-family: Arial, Helvetica, sans-serif;
    background:#f5f5f5;
    color:#333;
    margin:0;
    padding:40px;
}
.container{
    max-width:900px;
    margin:auto;
    background:#fff;
    padding:40px;
    border-radius:10px;
    box-shadow:0 0 10px rgba(0,0,0,.1);
}
h1,h2{
    color:#b8860b;
}
p,li{
    line-height:1.8;
}
footer{
    margin-top:40px;
    text-align:center;
    color:#777;
}
</style>

</head>

<body>

<div class="container">

<h1>Privacy Policy</h1>

<p><strong>Effective Date:</strong> August 2026</p>

<p>
Maliram CRM ("the App") is developed for the internal business operations of
<strong>Maliram Jewellers</strong>. The application is intended exclusively
for authorized employees and administrators.
</p>

<h2>Information We Collect</h2>

<ul>
<li>Employee information</li>
<li>Customer names</li>
<li>Customer phone numbers</li>
<li>Customer email addresses</li>
<li>Customer visit history</li>
<li>Jewellery and customer images uploaded by authorized employees</li>
<li>Reminder and follow-up information</li>
<li>Authentication information required for login</li>
</ul>

<h2>How We Use Information</h2>

<ul>
<li>Manage customer relationships</li>
<li>Maintain customer records</li>
<li>Schedule reminders and follow-ups</li>
<li>Manage employee activities</li>
<li>Improve customer service</li>
<li>Maintain business records</li>
</ul>

<h2>Data Security</h2>

<p>
We implement appropriate technical and organizational security measures
to protect customer and employee information. Access is restricted to
authorized users only.
</p>

<h2>Data Sharing</h2>

<p>
We do not sell, rent, or trade personal information.
Information is shared only when necessary for business operations
or to comply with legal obligations.
</p>

<h2>Data Retention</h2>

<p>
Information is retained only for as long as necessary for legitimate
business purposes or as required by applicable law.
</p>

<h2>Children's Privacy</h2>

<p>
This application is intended solely for authorized employees and
is not directed toward children under 13 years of age.
</p>

<h2>Contact Us</h2>

<p>
<b>Maliram Jewellers</b><br>
Email:
<a href="mailto:sahil@maliramjewellers.com">
sahil@maliramjewellers.com
</a>
</p>

<footer>

© 2026 Maliram Jewellers. All rights reserved.

</footer>

</div>

</body>
</html>
  `);
});

module.exports = router;