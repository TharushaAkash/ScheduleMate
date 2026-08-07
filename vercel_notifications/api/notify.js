const admin = require('firebase-admin');

if (!admin.apps.length) {
  try {
    // We expect FIREBASE_SERVICE_ACCOUNT to be the JSON string of the service account
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
  } catch (error) {
    console.error('Firebase initialization error', error);
  }
}

export default async function handler(req, res) {
  // Add CORS headers so Flutter web/app can call it if needed
  res.setHeader('Access-Control-Allow-Credentials', true);
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,PATCH,DELETE,POST,PUT');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version'
  );

  // Handle preflight request
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { topic, title, body, senderId } = req.body;

    if (!topic || !title || !body) {
      return res.status(400).json({ error: 'Missing required parameters (topic, title, body)' });
    }

    const message = {
      notification: {
        title: title,
        body: body
      },
      data: {
        senderId: senderId || '',
        topic: topic,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      topic: topic
    };

    const response = await admin.messaging().send(message);
    return res.status(200).json({ success: true, messageId: response });
  } catch (error) {
    console.error('Error sending message:', error);
    return res.status(500).json({ error: error.message });
  }
}
