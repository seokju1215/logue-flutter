import jwt from 'jsonwebtoken';
import fs from 'fs';

const privateKey = fs.readFileSync('/Users/hongseogju/Desktop/logue/AuthKey_6X24N4S3GN.p8');

const now = Math.floor(Date.now() / 1000); // 현재 시간 (초 단위)

const payload = {
  iat: now,
  exp: now + 60 * 60 * 24 * 180, // 180일 후
  aud: 'https://appleid.apple.com',
  iss: 'SCJMRA4Z88',                // 👉 팀 ID
  sub: 'logue.apple.service',      // 👉 서비스 ID (Client ID)
};

const token = jwt.sign(payload, privateKey, {
  algorithm: 'ES256',
  keyid: '6X24N4S3GN',             // 👉 키 ID
  header: { kid: '6X24N4S3GN' },
});

console.log(token);