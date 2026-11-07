#!/usr/bin/env node
// Run reports for the custom commands in devenv.nix: see "Run reports" in CLAUDE.md.
//
// One JSON file per invocation in .run-reports/, filled while the command runs.
// stack.json lists the open reports, innermost last: a report started while
// another is open becomes its child, so the outermost report renders the
// whole tree. Two invocations of the same command always get two files.

import fs from 'node:fs';
import path from 'node:path';

const dir = path.resolve(process.env.RUN_REPORT_DIR ?? '.run-reports');
const stackFile = path.join(dir, 'stack.json');
// A run leaves its report open only while it is alive; a long build may keep
// a report quiet for an hour or two, never this long.
const STALE_MS = 3 * 60 * 60 * 1000;
const SECTIONS = ['step', 'result', 'note', 'open'];

const now = () => new Date().toISOString();
const die = (msg) => {
  console.error(`run-report: ${msg}`);
  process.exit(1);
};
const file = (name) => path.join(dir, name);
const load = (name) => JSON.parse(fs.readFileSync(file(name), 'utf8'));
const save = (name, report) => fs.writeFileSync(file(name), JSON.stringify(report, null, 2) + '\n');
const tryLoad = (name) => (fs.existsSync(file(name)) ? load(name) : null);
const byAt = (a, b) => (a.at < b.at ? -1 : a.at > b.at ? 1 : 0);

function loadStack() {
  if (!fs.existsSync(stackFile)) return [];
  return JSON.parse(fs.readFileSync(stackFile, 'utf8')).filter((name) => fs.existsSync(file(name)));
}

function saveStack(stack) {
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(stackFile, JSON.stringify(stack, null, 2) + '\n');
}

function markInterrupted(name) {
  const report = tryLoad(name);
  if (report && report.state === 'open') {
    report.state = 'interrupted';
    save(name, report);
  }
}

function newReport(args) {
  const root = args[0] === '--root';
  if (root) args.shift();
  const command = args[0] || die('usage: new [--root] <command>');
  fs.mkdirSync(dir, { recursive: true });

  let stack = loadStack();
  const top = stack.length ? tryLoad(stack.at(-1)) : null;
  const stale = top && Date.now() - Date.parse(top.updated) > STALE_MS;
  if (root || stale) {
    stack.forEach(markInterrupted);
    stack = [];
  }

  const at = now();
  // Milliseconds keep reports of the same command in start order.
  const stamp = at.replace(/[-:.]/g, '');
  let name = `${stamp}-${command}.json`;
  for (let i = 2; fs.existsSync(file(name)); i++) name = `${stamp}-${command}-${i}.json`;

  const parent = stack.at(-1) ?? null;
  save(name, {
    command,
    state: 'open',
    started: at,
    updated: at,
    ended: null,
    parent,
    headline: null,
    logs: {},
    steps: [],
    result: [],
    note: [],
    open: [],
  });
  if (parent) {
    const p = load(parent);
    p.steps.push({ at, child: name });
    p.updated = at;
    save(parent, p);
  }
  stack.push(name);
  saveStack(stack);
  console.log(parent ? `report ${name}, inside ${parent}` : `report ${name}`);
}

function add(args) {
  const section = args.shift() || die('usage: add <section> [text]  (text on stdin if omitted)');
  let text = args.join(' ');
  if (!text.trim() && !process.stdin.isTTY) text = fs.readFileSync(0, 'utf8');
  text = text.trim().replace(/\s*\n\s*/g, ' ');
  if (!text) die(`no text for ${section}`);

  const top = loadStack().at(-1) ?? die('no open report: run `just report new <command>` first');
  const report = load(top);
  const at = now();
  const log = section.match(/^(log|status):(.+)$/);
  if (section === 'headline') {
    report.headline = text;
  } else if (SECTIONS.includes(section)) {
    report[section === 'step' ? 'steps' : section].push({ at, text });
  } else if (log) {
    const entry = (report.logs[log[2]] ??= { status: null, statusAt: null, items: [] });
    if (log[1] === 'status') {
      entry.status = text;
      entry.statusAt = at;
    } else {
      entry.items.push({ at, text });
    }
  } else {
    die(`unknown section ${section}: use headline, ${SECTIONS.join(', ')}, log:<Name> or status:<Name>`);
  }
  report.updated = at;
  save(top, report);
}

function close() {
  const stack = loadStack();
  const top = stack.pop() ?? die('no open report');
  const report = load(top);
  report.state = 'closed';
  report.ended = now();
  report.updated = report.ended;
  save(top, report);
  saveStack(stack);
  if (stack.length) {
    console.log(`nested in ${stack.at(-1)}, whose report includes this one. On its own: just report render ${top}`);
    return;
  }
  process.stdout.write(renderToFile(top));
}

// Every report in the tree under `name`, parents before children.
function tree(name) {
  const report = tryLoad(name);
  if (!report) return [];
  return [report, ...report.steps.filter((s) => s.child).flatMap((s) => tree(s.child))];
}

function childLabel(report) {
  if (report.headline) return report.headline;
  return { open: 'still running', interrupted: 'interrupted' }[report.state] ?? 'no headline recorded';
}

function steps(report, indent) {
  return report.steps.flatMap((s) => {
    if (!s.child) return [`${indent}- ${s.text}`];
    const child = tryLoad(s.child);
    if (!child) return [`${indent}- (report ${s.child} is missing)`];
    return [`${indent}- **/${child.command}:** ${childLabel(child)}`, ...steps(child, `${indent}  `)];
  });
}

function render(name) {
  const report = load(name);
  const all = tree(name);
  const out = [report.headline ?? `/${report.command}: ${childLabel(report)}.`];

  // Tracked-state logs merge by name across the tree; the newest status wins.
  const logs = new Map();
  for (const r of all) {
    for (const [logName, l] of Object.entries(r.logs)) {
      const merged = logs.get(logName) ?? { status: null, statusAt: '', items: [] };
      if (l.status && l.statusAt > merged.statusAt) Object.assign(merged, { status: l.status, statusAt: l.statusAt });
      merged.items.push(...l.items);
      logs.set(logName, merged);
    }
  }
  for (const [logName, l] of logs) {
    out.push('', `**${logName} log${l.status ? `: ${l.status}` : ''}**`, ...l.items.sort(byAt).map((i) => `- ${i.text}`));
  }

  const stepLines = steps(report, '');
  if (stepLines.length) out.push('', '**By step**', ...stepLines);

  // The result is the state the run ended in: the lines of the report that
  // recorded one last.
  const latest = (r) => r.result.reduce((m, i) => (i.at > m ? i.at : m), '');
  const last = all.filter((r) => r.result.length).sort((a, b) => (latest(a) < latest(b) ? -1 : 1)).at(-1);
  if (last) out.push('', '**Result**', ...last.result.map((i) => `- ${i.text}`));

  for (const [section, title] of [['note', 'Worth noting'], ['open', 'Still open']]) {
    const items = all.flatMap((r) => r[section]).sort(byAt);
    if (items.length) out.push('', `**${title}**`, ...items.map((i) => `- ${i.text}`));
  }
  return out;
}

function renderToFile(name) {
  const md = path.join(dir, name.replace(/\.json$/, '.md'));
  const rel = path.relative(process.cwd(), md);
  const shown = rel.startsWith('..') ? md : rel;
  const text = [...render(name), '', `_Log: \`${shown}\`_`].join('\n') + '\n';
  fs.writeFileSync(md, text);
  return text;
}

function latestRoot() {
  if (!fs.existsSync(dir)) return null;
  const names = fs.readdirSync(dir).filter((n) => n.endsWith('.json') && n !== 'stack.json').sort();
  return names.reverse().find((n) => load(n).parent === null) ?? null;
}

function list(args) {
  const count = Number(args[0] ?? 10);
  if (!fs.existsSync(dir)) return;
  const names = fs.readdirSync(dir).filter((n) => n.endsWith('.json') && n !== 'stack.json').sort().slice(-count);
  for (const n of names) {
    const r = load(n);
    console.log(`${n}  ${r.state}${r.parent ? `  (in ${r.parent})` : ''}  ${r.headline ?? ''}`);
  }
}

const [cmd, ...args] = process.argv.slice(2);
switch (cmd) {
  case 'new':
    newReport(args);
    break;
  case 'add':
    add(args);
    break;
  case 'close':
    close();
    break;
  case 'render': {
    const name = args[0] ? path.basename(args[0]).replace(/\.md$/, '.json') : latestRoot();
    if (!name) die('no reports yet');
    process.stdout.write(renderToFile(name));
    break;
  }
  case 'list':
    list(args);
    break;
  default:
    die('usage: new [--root] <command> | add <section> [text] | close | render [file] | list [count]');
}
