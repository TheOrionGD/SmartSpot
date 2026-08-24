const fs = require('fs');
const path = require('path');
const https = require('https');

// Read .env file manually
const envPath = path.join(__dirname, '.env');
const envContent = fs.readFileSync(envPath, 'utf8');
const env = {};
envContent.split('\n').forEach(line => {
    const parts = line.split('=');
    if (parts.length >= 2) {
        env[parts[0].trim()] = parts.slice(1).join('=').trim();
    }
});

const apiKey = env.BREVO_API_KEY;
const senderEmail = env.MAIL_FROM || 'godfrey.cs23@krct.ac.in';
const senderName = env.MAIL_FROM_NAME || 'SmartSpot Support';

const data = JSON.stringify({
    sender: {
        name: senderName,
        email: senderEmail
    },
    to: [
        {
            email: 'godfrey.prof@gmail.com',
            name: 'Godfrey'
        }
    ],
    subject: 'Sample Email from SmartSpot',
    htmlContent: `
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
                .container { max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px; }
                .header { background-color: #4F46E5; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
                .content { padding: 20px; }
                .footer { font-size: 12px; color: #666; text-align: center; margin-top: 20px; padding-top: 10px; border-top: 1px solid #eee; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h2>SmartSpot System Notification</h2>
                </div>
                <div class="content">
                    <p>Hello Godfrey,</p>
                    <p>This is a sample test email sent successfully from your <strong>SmartSpot</strong> backend system using Brevo API integration.</p>
                    <p><strong>Details:</strong></p>
                    <ul>
                        <li><strong>Recipient:</strong> godfrey.prof@gmail.com</li>
                        <li><strong>Sender:</strong> ${senderName} (${senderEmail})</li>
                        <li><strong>Timestamp:</strong> ${new Date().toLocaleString()}</li>
                    </ul>
                    <p>If you received this message, your mail configuration is active and operational!</p>
                </div>
                <div class="footer">
                    <p>&copy; ${new Date().getFullYear()} SmartSpot. All rights reserved.</p>
                </div>
            </div>
        </body>
        </html>
    `
});

const options = {
    hostname: 'api.brevo.com',
    port: 443,
    path: '/v3/smtp/email',
    method: 'POST',
    headers: {
        'accept': 'application/json',
        'api-key': apiKey,
        'content-type': 'application/json',
        'content-length': Buffer.byteLength(data)
    }
};

console.log('Sending sample email via Brevo API...');

const req = https.request(options, (res) => {
    let responseData = '';
    res.on('data', (chunk) => {
        responseData += chunk;
    });
    res.on('end', () => {
        console.log(`Status Code: ${res.statusCode}`);
        console.log(`Response: ${responseData}`);
        if (res.statusCode >= 200 && res.statusCode < 300) {
            console.log('SUCCESS: Email sent successfully!');
        } else {
            console.error('ERROR: Failed to send email.');
        }
    });
});

req.on('error', (e) => {
    console.error(`Problem with request: ${e.message}`);
});

req.write(data);
req.end();
