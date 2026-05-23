#!/usr/bin/env node
// Force-update broken fields via Tooling API composite to trigger data-layer activation
const https = require('https');
const { execSync } = require('child_process');

process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

const ORG_INFO = JSON.parse(execSync('sf org display --target-org GuitarAcademy --json', { env: process.env }).toString());
const { accessToken, instanceUrl } = ORG_INFO.result;

// Fields to recreate: delete broken record then create fresh via Tooling API
const OBJECT_ID = '01IgL000005slrtUAA'; // Guitar_Video__c

const fieldsToCreate = [
    {
        fullName: 'Guitar_Video__c.Level__c',
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
    },
    {
        fullName: 'Guitar_Video__c.Category__c',
        Metadata: {
            type: 'Picklist',
            label: 'Category',
            required: false,
            trackTrending: false,
            valueSet: {
                restricted: true,
                valueSetDefinition: {
                    sorted: false,
                    value: [
                        { fullName: 'Technique', default: false, label: 'Technique' },
                        { fullName: 'Theory', default: false, label: 'Theory' },
                        { fullName: 'Song Lesson', default: false, label: 'Song Lesson' },
                        { fullName: 'Gear & Tone', default: false, label: 'Gear & Tone' },
                    ],
                },
            },
        },
    },
    {
        fullName: 'Guitar_Video__c.Price__c',
        Metadata: { type: 'Currency', label: 'Price', precision: 4, scale: 2, required: false, trackTrending: false },
    },
    {
        fullName: 'Guitar_Video__c.Duration_Minutes__c',
        Metadata: { type: 'Number', label: 'Duration (minutes)', precision: 4, scale: 0, required: false, trackTrending: false },
    },
    {
        fullName: 'Guitar_Video__c.Is_Free_Preview__c',
        Metadata: { type: 'Checkbox', label: 'Free Preview', defaultValue: false, trackTrending: false },
    },
    {
        fullName: 'Guitar_Video__c.Description__c',
        Metadata: { type: 'LongTextArea', label: 'Description', length: 2000, visibleLines: 5, required: false, trackTrending: false },
    },
];

function apiRequest(method, path, body) {
    return new Promise((resolve, reject) => {
        const u = new URL(instanceUrl + path);
        const bodyStr = body ? JSON.stringify(body) : undefined;
        const req = https.request({
            hostname: u.hostname,
            path: u.pathname + (u.search || ''),
            method,
            headers: {
                Authorization: `Bearer ${accessToken}`,
                'Content-Type': 'application/json',
                ...(bodyStr ? { 'Content-Length': Buffer.byteLength(bodyStr) } : {}),
            },
        }, (res) => {
            let d = '';
            res.on('data', c => d += c);
            res.on('end', () => {
                try { resolve({ status: res.statusCode, body: JSON.parse(d) }); }
                catch { resolve({ status: res.statusCode, body: d }); }
            });
        });
        req.on('error', reject);
        if (bodyStr) req.write(bodyStr);
        req.end();
    });
}

(async () => {
    console.log('Creating fields via Tooling API...\n');

    for (const field of fieldsToCreate) {
        process.stdout.write(`  ${field.fullName} ... `);
        const r = await apiRequest('POST', '/services/data/v65.0/tooling/sobjects/CustomField', {
            FullName: field.fullName,
            Metadata: field.Metadata,
        });
        if (r.status === 201 || r.status === 200) {
            console.log(`OK (id: ${r.body.id})`);
        } else {
            console.log(`FAILED HTTP ${r.status}: ${JSON.stringify(r.body).substring(0, 150)}`);
        }
    }

    console.log('\nDone. Test with: sf data query --query "SELECT Level__c FROM Guitar_Video__c LIMIT 1" --target-org GuitarAcademy');
})();
