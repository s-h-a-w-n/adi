const express = require('express');
const cors = require('cors');
const { google } = require('googleapis');
const fs = require('fs');
const yaml = require('js-yaml');
const path = require('path');

// Load the config.yaml file
const configPath = '/etc/secrets/config.yaml';
let config;

try {
  config = yaml.load(fs.readFileSync(configPath, 'utf8'));
} catch (error) {
  console.error(`Error reading config file at ${configPath}:`, error);
  process.exit(1);
}

const { SHEET_ID, TAB_NAME } = config.appConfig;

const app = express();
const port = 3001;

app.use(cors()); // Enable CORS for all routes

const auth = new google.auth.GoogleAuth({
  credentials: config.googleCredentials,
  scopes: ['https://www.googleapis.com/auth/spreadsheets.readonly'],
});

// Health check endpoint
app.get('/healthz', (req, res) => {
  res.status(200).send('OK');
});

// Readiness check endpoint
app.get('/ready', (req, res) => {
  res.status(200).send('Ready');
});

app.get('/patterns', async (req, res) => {
  try {
    const authClient = await auth.getClient();
    const sheets = google.sheets({ version: 'v4', auth: authClient });
    const response = await sheets.spreadsheets.values.get({
      spreadsheetId: SHEET_ID,
      range: TAB_NAME,
    });
    res.json(response.data.values);
  } catch (error) {
    console.error('Error fetching data from Google Sheets:', error);
    res.status(500).send({
      message: 'Error fetching data from Google Sheets',
      error: error.message,
      stack: error.stack,
    });
  }
});

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});