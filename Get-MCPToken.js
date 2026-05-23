#!/usr/bin/env node
// Run: node Get-MCPToken.js
// Opens browser for Salesforce OAuth PKCE flow, captures token, updates .mcp.json

const https = require('https');
const http = require('http');
const crypto = require('crypto');
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

const CONSUMER_KEY = '3MVG9dAEux2v1sLsUY66q2pgMhgIdDo.YynLb_4XBU1H.DZ1h6cf7g4NklvBRNgJ7zrrc4d9qL0OnH2uhisDg';
const INSTANCE_URL = 'https://orgfarm-96c3beb92c-dev-ed.develop.my.salesforce.com';
const REDIRECT_PORT = 1717;
const REDIRECT_URI = `http://localhost:${REDIRECT_PORT}/callback`;
const MCP_JSON = path.join(__dirname, '.mcp.json');

// PKCE helpers
function base64url(buf) {
  return buf.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

const codeVerifier = base64url(crypto.randomBytes(64));
const codeChallenge = base64url(crypto.createHash('sha256').update(codeVerifier).digest());
const state = crypto.randomBytes(16).toString('hex');

const authUrl = `${INSTANCE_URL}/services/oauth2/authorize?` +
  `response_type=code` +
  `&client_id=${encodeURIComponent(CONSUMER_KEY)}` +
  `&redirect_uri=${encodeURIComponent(REDIRECT_URI)}` +
  `&code_challenge=${codeChallenge}` +
  `&code_challenge_method=S256` +
  `&state=${state}`;

console.log('\n=== Guitar Academy MCP - OAuth Token Setup ===\n');
console.log('Opening browser for Salesforce login...');
console.log('If browser does not open, visit:\n' + authUrl + '\n');

// Open browser (Windows)
try { execSync(`start "" "${authUrl}"`, { stdio: 'ignore' }); } catch (_) {}

function exchangeCode(code) {
  return new Promise((resolve, reject) => {
    const body = new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      redirect_uri: REDIRECT_URI,
      client_id: CONSUMER_KEY,
      code_verifier: codeVerifier,
    }).toString();

    const opts = {
      hostname: new URL(INSTANCE_URL).hostname,
      path: '/services/oauth2/token',
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Content-Length': Buffer.byteLength(body) },
    };

    const req = https.request(opts, (res) => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => {
        try { resolve(JSON.parse(d)); } catch (e) { reject(new Error('Bad JSON: ' + d)); }
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

function testMcpEndpoint(token, url) {
  return new Promise((resolve) => {
    const body = JSON.stringify({ jsonrpc: '2.0', method: 'initialize', params: { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'test', version: '1.0' } }, id: 1 });
    const u = new URL(url);
    const req = https.request({ hostname: u.hostname, path: u.pathname, method: 'POST', headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) } }, (res) => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => resolve({ status: res.statusCode, body: d.substring(0, 200) }));
    });
    req.on('error', e => resolve({ status: 0, body: e.message }));
    req.write(body);
    req.end();
  });
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${REDIRECT_PORT}`);
  const code = url.searchParams.get('code');
  const returnedState = url.searchParams.get('state');
  const error = url.searchParams.get('error');

  if (error) {
    res.end('<html><body><h2>Error: ' + error + '</h2><p>' + url.searchParams.get('error_description') + '</p></body></html>');
    console.error('OAuth error:', error);
    server.close();
    return;
  }

  if (!code || returnedState !== state) {
    res.end('<html><body><h2>Invalid response</h2></body></html>');
    return;
  }

  res.end('<html><body><h2>Authorized! Return to VS Code.</h2></body></html>');
  server.close();

  console.log('\nGot authorization code, exchanging for token...');
  let tokenData;
  try {
    tokenData = await exchangeCode(code);
  } catch (e) {
    console.error('Token exchange failed:', e.message);
    return;
  }

  if (!tokenData.access_token) {
    console.error('No access_token in response:', JSON.stringify(tokenData));
    return;
  }

  const token = tokenData.access_token;
  const instanceUrl = tokenData.instance_url || INSTANCE_URL;
  console.log('Got token (last 10): ...' + token.slice(-10));

  // Test which MCP URL works
  const candidates = [
    'https://api.salesforce.com/platform/mcp/v1/platform/sobject-all',
    'https://api.salesforce.com/platform/mcp/v1/sandbox/sobject-all',
    'https://api.salesforce.com/platform/mcp/v1/sobject-all',
  ];

  let workingUrl = null;
  for (const candidate of candidates) {
    process.stdout.write(`Testing ${candidate} ... `);
    const r = await testMcpEndpoint(token, candidate);
    console.log('HTTP ' + r.status + (r.status < 400 ? ' OK' : ''));
    if (r.status < 400) { workingUrl = candidate; break; }
    if (r.status === 401) {
      // 401 is better than 404 — the endpoint exists
      if (!workingUrl) workingUrl = candidate;
    }
  }

  const chosenUrl = workingUrl || candidates[0];
  console.log('\nUsing URL:', chosenUrl);

  const mcp = {
    mcpServers: {
      salesforce: {
        type: 'http',
        url: chosenUrl,
        headers: { Authorization: 'Bearer ' + token },
      },
    },
  };

  fs.writeFileSync(MCP_JSON, JSON.stringify(mcp, null, 4));
  console.log('\n.mcp.json updated!');
  console.log('\nNext: Ctrl+Shift+P > "MCP: Restart MCP Server" in VS Code');
  console.log('Token expires in ~2 hrs. Run this script again when it does.\n');
});

server.listen(REDIRECT_PORT, () => {
  console.log(`Waiting for OAuth redirect on port ${REDIRECT_PORT}...`);
});

server.on('error', (e) => {
  if (e.code === 'EADDRINUSE') {
    console.error(`Port ${REDIRECT_PORT} is already in use. Kill the process using it and retry.`);
  } else {
    console.error('Server error:', e.message);
  }
});
