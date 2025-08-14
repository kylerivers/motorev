const jwt = require('jsonwebtoken');
const axios = require('axios');

function buildClientToken() {
  const keyId = process.env.APPSTORE_KEY_ID;
  const issuerId = process.env.APPSTORE_ISSUER_ID;
  const privateKey = process.env.APPSTORE_PRIVATE_KEY?.replace(/\\n/g, '\n');
  if (!keyId || !issuerId || !privateKey) {
    return null;
  }
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: issuerId,
    iat: now,
    exp: now + 1800,
    aud: 'appstoreconnect-v1'
  };
  const header = { kid: keyId, typ: 'JWT', alg: 'ES256' };
  return jwt.sign(payload, privateKey, { algorithm: 'ES256', header });
}

async function verifyTransaction(transactionId) {
  try {
    const token = buildClientToken();
    if (!token) return { ok: false, reason: 'Missing App Store API credentials' };
    const base = process.env.APPSTORE_ENV === 'sandbox'
      ? 'https://api.storekit-sandbox.itunes.apple.com'
      : 'https://api.storekit.itunes.apple.com';
    const url = `${base}/inApps/v1/transactions/${encodeURIComponent(transactionId)}`;
    const resp = await axios.get(url, { headers: { Authorization: `Bearer ${token}` } });
    // If request succeeds (200), we consider it verified for now.
    return { ok: true, data: resp.data };
  } catch (e) {
    return { ok: false, reason: e.response?.data || e.message };
  }
}

module.exports = { verifyTransaction }; 