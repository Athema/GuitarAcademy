#!/usr/bin/env node
// Hard-delete broken soft-deleted fields via Tooling API
const https = require('https');
const { execSync } = require('child_process');

process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

const ORG_INFO = JSON.parse(execSync('sf org display --target-org GuitarAcademy --json', { env: process.env }).toString());
const { accessToken, instanceUrl } = ORG_INFO.result;

// All broken field IDs to hard-delete (both _del versions and broken new versions)
const fieldIds = [
    // Soft-deleted (_del) versions
    '00NgL00003vt5frUAA', // Category_del
    '00NgL00003vt5fsUAA', // Description_del
    '00NgL00003vt5ftUAA', // Duration_Minutes_del
    '00NgL00003vt5fuUAA', // Is_Free_Preview_del
    '00NgL00003vt5fvUAA', // Level_del
    '00NgL00003vt5fwUAA', // Price_del
    '00NgL00003vt5g5UAA', // Thumbnail_URL_del
    // Broken new versions (created while _del existed)
    '00NgL00003wQBNZUA4', // Category (new, broken)
    '00NgL00003wQBNaUAO', // Description (new, broken)
    '00NgL00003wQBNbUAO', // Duration_Minutes (new, broken)
    '00NgL00003wQBNcUAO', // Is_Free_Preview (new, broken)
    '00NgL00003wQBNdUAO', // Level (new, broken)
    '00NgL00003wQBNeUAO', // Price (new, broken)
    '00NgL00003wQBNfUAO', // Thumbnail_URL (new, broken)
];

function deleteField(id) {
    return new Promise((resolve, reject) => {
        const url = new URL(`${instanceUrl}/services/data/v65.0/tooling/sobjects/CustomField/${id}`);
        const req = https.request({
            hostname: url.hostname,
            path: url.pathname,
            method: 'DELETE',
            headers: { Authorization: `Bearer ${accessToken}` },
        }, (res) => {
            let d = '';
            res.on('data', c => d += c);
            res.on('end', () => resolve({ id, status: res.statusCode, body: d }));
        });
        req.on('error', reject);
        req.end();
    });
}

(async () => {
    console.log(`Deleting ${fieldIds.length} fields...`);
    for (const id of fieldIds) {
        const r = await deleteField(id);
        console.log(`  ${id}: HTTP ${r.status}${r.body ? ' ' + r.body.substring(0, 80) : ''}`);
    }
    console.log('\nDone. Now run the deploy again.');
})();
