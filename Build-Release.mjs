#!/usr/bin/env node
// Cross-platform release builder for CI/Linux. Windows technicians can use Build-Release.ps1.
import { readFileSync, writeFileSync, existsSync, statSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { gzipSync } from 'node:zlib';
import { createHash } from 'node:crypto';

const root = dirname(fileURLToPath(import.meta.url));
const read = (name) => readFileSync(join(root, name));
const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex').toUpperCase();

const bat = read('Tool_Windows.bat');
const core = read('Syscare.WindowsTool.ps1');
const batText = bat.toString('latin1');
const versionMatch = batText.match(/^set "TOOL_VERSION=(\d+\.\d+\.\d+)"\r?$/m);
if (!versionMatch) throw new Error('TOOL_VERSION was not found in Tool_Windows.bat.');
const version = versionMatch[1];

const buildScript = readFileSync(join(root, 'Build-Release.ps1'), 'utf8');
const templateMatch = buildScript.match(/\$launcherTemplate = @'\r?\n([\s\S]*?)\r?\n'@/);
if (!templateMatch) throw new Error('Launcher template was not found in Build-Release.ps1.');

const generatedUtc = new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
const batHash = sha256(bat);
const coreHash = sha256(core);
const launcher = templateMatch[1]
  .replaceAll('__GENERATED_UTC__', generatedUtc)
  .replaceAll('__TOOL_VERSION__', version)
  .replaceAll('__BAT_SHA256__', batHash)
  .replaceAll('__CORE_SHA256__', coreHash)
  .replaceAll('__BAT_PAYLOAD__', gzipSync(bat, { level: 9, mtime: 0 }).toString('base64'))
  .replaceAll('__CORE_PAYLOAD__', gzipSync(core, { level: 9, mtime: 0 }).toString('base64'));

writeFileSync(join(root, 'Invoke-JoITWindowsTool.ps1'), launcher, 'utf8');
writeFileSync(join(root, 'index.html'), launcher, 'utf8');

const releaseFiles = [
  '.nojekyll', 'AUDIT_REPORT.md', 'Build-Release.mjs', 'Build-Release.ps1',
  'CHANGELOG.md', 'CNAME', 'Invoke-JoITWindowsTool.ps1', 'README.md',
  'Syscare.WindowsTool.ps1', 'TEST_REPORT.md', 'Tool_Windows.bat', 'index.html'
];
const files = releaseFiles.filter((name) => existsSync(join(root, name))).map((name) => {
  const bytes = read(name);
  return { File: name, SHA256: sha256(bytes), Bytes: statSync(join(root, name)).size };
});
writeFileSync(join(root, 'checksums.sha256'), files.map((f) => `${f.SHA256}  ${f.File}`).join('\n') + '\n', 'utf8');
writeFileSync(join(root, 'release-manifest.json'), JSON.stringify({
  name: 'Syscare Windows Tool',
  version,
  generatedUtc,
  officialUrl: 'https://win.syscare.site',
  minimumPowerShell: '5.1',
  launcherPayloads: [
    { file: 'Tool_Windows.bat', sha256: batHash, bytes: bat.length },
    { file: 'Syscare.WindowsTool.ps1', sha256: coreHash, bytes: core.length }
  ],
  files
}, null, 2) + '\n', 'utf8');

console.log(`Release v${version} built successfully.`);
console.log(`BAT SHA-256 : ${batHash}`);
console.log(`Core SHA-256: ${coreHash}`);
console.log(`Launcher and index are identical: ${sha256(read('Invoke-JoITWindowsTool.ps1')) === sha256(read('index.html'))}`);
