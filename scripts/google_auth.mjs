import { google } from 'googleapis';
import { createServer } from 'http';
import { readFileSync, writeFileSync } from 'fs';
import { URL } from 'url';

const creds = JSON.parse(readFileSync('./google_credentials.json'));
const { client_id, client_secret } = creds.web;
const REDIRECT = 'http://localhost:9876/callback';
const TOKEN_PATH = './google_token.json';

const oauth2Client = new google.auth.OAuth2(client_id, client_secret, REDIRECT);

const authUrl = oauth2Client.generateAuthUrl({
  access_type: 'offline',
  scope: ['https://www.googleapis.com/auth/calendar.readonly'],
  prompt: 'consent',
});

console.log('\nAbre este link en tu navegador:\n');
console.log(authUrl);
console.log('\nEsperando autorización en http://localhost:3000 ...\n');

const server = createServer(async (req, res) => {
  if (!req.url.startsWith('/callback')) return;

  const code = new URL(req.url, 'http://localhost:3000').searchParams.get('code');
  if (!code) {
    res.end('Error: no se recibió código');
    return;
  }

  const { tokens } = await oauth2Client.getToken(code);
  writeFileSync(TOKEN_PATH, JSON.stringify(tokens, null, 2));

  res.end('<h2>Autorización exitosa. Puedes cerrar esta ventana.</h2>');
  console.log('Token guardado en google_token.json');
  server.close();
});

server.listen(9876);
