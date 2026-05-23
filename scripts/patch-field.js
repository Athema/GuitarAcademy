#!/usr/bin/env node
const https = require('https');
const { execSync } = require('child_process');

process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

const ORG_INFO = JSON.parse(execSync('sf org display --target-org GuitarAcademy --json', { env: process.env }).toString());
const { accessToken, instanceUrl } = ORG_INFO.result;

// PATCH the broken Level field to force re-activation
const FIELD_ID = '00NgL00003wQBNdUAO'; // Level (broken)

const body = JSON.stringify({
    Metadata: {
        type: 'Picklist',
        label: 'Level',
        required: false,
        trackTrending: false,
        valueSet: {
            restricted: true,
            valueSetDefinition: {
                sorted: false,
                value: [
                    { fullName: 'Beginner', default: false, label: 'Beginner' },
                    { fullName: 'Intermediate', default: false, label: 'Intermediate' },
                    { fullName: 'Advanced', default: false, label: 'Advanced' },
                ],
            },
        },
    },
});

const u = new URL(`${instanceUrl}/services/data/v65.0/tooling/sobjects/CustomField/${FIELD_ID}`);
const req = https.request({
    hostname: u.hostname,
    path: u.pathname,
    method: 'PATCH',
    headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
    },
}, (res) => {
    let d = '';
    res.on('data', c => d += c);
    res.on('end', () => console.log(`HTTP ${res.statusCode}: ${d || '(no body - success)'}`));
});
req.on('error', console.error);
req.write(body);
req.end();
