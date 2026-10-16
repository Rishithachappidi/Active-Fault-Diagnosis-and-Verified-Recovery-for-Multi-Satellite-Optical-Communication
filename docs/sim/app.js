import { simulate, SCENARIOS, PROFILES, CLASS_NAMES, ACTION_NAMES, makeNetwork } from './engine.js';

const $ = id => document.getElementById(id);
const css = name => getComputedStyle(document.documentElement).getPropertyValue(name).trim();
const CLASS_COLORS = ['#3fa36b', '#2f7fd1', '#8a5cd6', '#d0507a', '#d39b2a', '#5b6670', '#1aa3a3', '#9aa5ae', '#e0482f'];
const SCEN_LABEL = { normal: 'None (healthy)', pointing: 'Boresight offset', effectiveness: 'Actuator gain loss', lag: 'Actuator lag',
  power: 'Optical power loss', blockage: 'Blockage', sensor: 'Sensor bias', simultaneous: 'Offset + power loss' };
const PRESETS = [
  ['a biased angle sensor', { scenario: 'sensor' }], ['a misaligned beam', { scenario: 'pointing' }], ['a weak transmitter', { scenario: 'power' }],
  ['misalignment plus power loss', { scenario: 'simultaneous' }], ['an actuator that keeps cutting out', { scenario: 'effectiveness', profile: 'intermittent' }],
];

const S = { n: 4, res: null, k: 0, playing: true, speed: 1, impl: 'v2', last: 0, acc: 0 };

// ---------- controls ----------
$('nSeg').innerHTML = [4, 6, 8, 10].map(n => `<button type="button" data-n="${n}" aria-pressed="${n === 4}">${n}</button>`).join('');
$('scenario').innerHTML = SCENARIOS.map(s => `<option value="${s}" ${s === 'sensor' ? 'selected' : ''}>${SCEN_LABEL[s]}</option>`).join('');
$('profile').innerHTML = PROFILES.map(p => `<option value="${p}">${p[0].toUpperCase() + p.slice(1)}</option>`).join('');
$('presets').innerHTML = PRESETS.map(([name], i) => `<button type="button" data-i="${i}">${name}</button>`).join(', ') + '.';
$('classKey').innerHTML = CLASS_NAMES.map((n, i) => `<span><i style="background:${CLASS_COLORS[i]}"></i>${n}</span>`).join(' ');

$('nSeg').addEventListener('click', e => {
  const b = e.target.closest('button'); if (!b) return;
  S.n = +b.dataset.n; $('nSeg').querySelectorAll('button').forEach(x => x.setAttribute('aria-pressed', x === b)); run();
});
$('severity').addEventListener('input', () => { $('sevOut').textContent = (+$('severity').value).toFixed(2); });
$('presets').addEventListener('click', e => {
  const b = e.target.closest('button'); if (!b) return;
  const p = PRESETS[+b.dataset.i][1];
  $('scenario').value = p.scenario; $('profile').value = p.profile || 'sudden'; $('severity').value = 1; $('sevOut').textContent = '1.00';
  $('fStart').value = 2; $('fEnd').value = 8; run();
});
['scenario', 'profile'].forEach(id => $(id).addEventListener('change', run));
$('form').addEventListener('submit', e => { e.preventDefault(); run(); });
document.querySelector('.which').addEventListener('click', e => {
  const b = e.target.closest('button'); if (!b) return;
  S.impl = b.dataset.impl; document.querySelectorAll('.which button').forEach(x => x.setAttribute('aria-pressed', x === b)); render();
});
$('play').addEventListener('click', () => { if (S.k >= S.res.v2.frames.length - 1) S.k = 0; S.playing = !S.playing; syncPlay(); });
$('restart').addEventListener('click', () => { S.k = 0; S.playing = true; syncPlay(); render(); });
$('speed').addEventListener('change', () => { S.speed = +$('speed').value; });
$('scrub').addEventListener('input', () => { S.k = +$('scrub').value; S.playing = false; syncPlay(); render(); });
function syncPlay() { $('play').textContent = S.playing ? 'Pause' : 'Play'; }

function params() {
  let fs = +$('fStart').value, fe = +$('fEnd').value;
  if (!(fe > fs)) { fe = Math.min(10, fs + 1); $('fEnd').value = fe; }
  return { n: S.n, scenario: $('scenario').value, profile: $('profile').value, severity: +$('severity').value,
    faultStart: fs, faultEnd: fe, seed: Math.max(1, Math.round(+$('seed').value) || 101) };
}

// ---------- run ----------
function run() {
  $('runBtn').disabled = true;
  requestAnimationFrame(() => setTimeout(() => {
    const p = params();
    S.res = { v1: simulate({ ...p, implementation: 'v1' }), v2: simulate({ ...p, implementation: 'v2' }), p };
    S.k = 0; S.playing = true; syncPlay();
    $('scrub').max = S.res.v2.frames.length - 1;
    const m = makeNetwork(S.n).length;
    $('netLabel').textContent = `${S.n} satellites, ${m} links`;
    buildMetrics(); buildLog(); render();
    $('runBtn').disabled = false;
  }, 0));
}

// ---------- canvas helpers ----------
function fit(cv) {
  const r = cv.getBoundingClientRect(), d = window.devicePixelRatio || 1;
  const w = Math.max(10, Math.round(r.width)), h = Math.max(10, Math.round(r.height));
  if (cv.width !== w * d || cv.height !== h * d) { cv.width = w * d; cv.height = h * d; }
  const ctx = cv.getContext('2d'); ctx.setTransform(d, 0, 0, d, 0, 0); ctx.clearRect(0, 0, w, h);
  return { ctx, w, h };
}
const fmt = (v, d = 2) => Number.isFinite(v) ? v.toFixed(d) : '—';
const pct = v => Number.isFinite(v) ? (v * 100).toFixed(1) + '%' : '—';

// ---------- network ----------
function drawNet(frame, c, tNow) {
  const { ctx, w, h } = fit($('net'));
  const cx = w / 2, cy = h / 2, R = Math.min(w, h) * 0.37;
  const pos = i => { const a = -Math.PI / 2 + 2 * Math.PI * (i - 1) / c.n; return [cx + R * Math.cos(a), cy + R * Math.sin(a)]; };
  ctx.strokeStyle = css('--line'); ctx.setLineDash([2, 5]); ctx.beginPath(); ctx.arc(cx, cy, R, 0, 7); ctx.stroke(); ctx.setLineDash([]);
  const er = R * 0.22; ctx.strokeStyle = css('--muted'); ctx.lineWidth = 1; ctx.beginPath(); ctx.arc(cx, cy, er, 0, 7); ctx.stroke();
  ctx.fillStyle = css('--muted'); ctx.font = '12px "IBM Plex Sans", sans-serif'; ctx.textAlign = 'center'; ctx.fillText('Earth', cx, cy + 4); ctx.textAlign = 'left';
  const routeSet = new Set(frame.route.edgeIDs);
  c.edges.forEach(([a, b], j) => {
    const [x1, y1] = pos(a), [x2, y2] = pos(b), y = frame.Y[j];
    const up = y.available, onRoute = routeSet.has(j);
    ctx.lineWidth = onRoute ? 3.2 : 1.6;
    ctx.strokeStyle = up ? (onRoute ? css('--good') : css('--muted')) : css('--bad');
    ctx.globalAlpha = up ? (onRoute ? 1 : .55) : .95;
    ctx.setLineDash(up ? [] : [6, 6]); ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke(); ctx.setLineDash([]);
    ctx.globalAlpha = 1;
    if (j === 0) {
      const mx = (x1 + x2) / 2, my = (y1 + y2) / 2;
      ctx.font = '500 12px "IBM Plex Sans", sans-serif'; ctx.fillStyle = up ? css('--fg') : css('--bad');
      ctx.fillText(`link 1: ${(y.power * 1e6).toFixed(2)} µW`, mx + 10, my - 8);
      if (frame.dec[0].truth !== 0) { ctx.fillStyle = css('--bad'); ctx.fillText('fault active', mx + 10, my + 8); }
    }
  });
  // packets along the route 1 -> 2
  const path = frame.route.path;
  if (path.length > 1) {
    const pts = path.map(pos), segs = pts.slice(1).map((p, i) => Math.hypot(p[0] - pts[i][0], p[1] - pts[i][1]));
    const total = segs.reduce((s, v) => s + v, 0);
    ctx.fillStyle = css('--good');
    for (let q = 0; q < 6; q++) {
      let d = ((tNow * 140 + q * total / 6) % total), i = 0;
      while (d > segs[i] && i < segs.length - 1) { d -= segs[i]; i++; }
      const f = d / segs[i], x = pts[i][0] + (pts[i + 1][0] - pts[i][0]) * f, y = pts[i][1] + (pts[i + 1][1] - pts[i][1]) * f;
      ctx.beginPath(); ctx.arc(x, y, 3, 0, 7); ctx.fill();
    }
  }
  for (let i = 1; i <= c.n; i++) {
    const [x, y] = pos(i);
    ctx.fillStyle = css('--bg'); ctx.strokeStyle = css('--fg'); ctx.lineWidth = 1.4;
    ctx.beginPath(); ctx.rect(x - 7, y - 7, 14, 14); ctx.fill(); ctx.stroke();
    ctx.fillStyle = css('--fg'); ctx.font = '12px "IBM Plex Sans", sans-serif'; ctx.textAlign = 'center';
    ctx.fillText(`S${i}${i === 1 ? ' (sends)' : i === 2 ? ' (receives)' : ''}`, x, y + (y < cy ? -14 : 24)); ctx.textAlign = 'left';
  }
}

// ---------- beam scope ----------
function drawScope(res, k) {
  const { ctx, w, h } = fit($('scope'));
  const c = res.config, cx = w / 2, cy = h / 2, span = 45e-6, sc = Math.min(w, h) / 2 / span;
  ctx.strokeStyle = css('--line'); ctx.lineWidth = 1;
  for (let u = -40e-6; u <= 40e-6 + 1e-12; u += 10e-6) {
    ctx.beginPath(); ctx.moveTo(cx + u * sc, 0); ctx.lineTo(cx + u * sc, h); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(0, cy + u * sc); ctx.lineTo(w, cy + u * sc); ctx.stroke();
  }
  ctx.fillStyle = css('--muted'); ctx.font = '10px "IBM Plex Sans", sans-serif';
  ctx.fillText('grid: 10 µrad', 6, h - 6);
  // trail
  const F = res.frames;
  ctx.strokeStyle = res === S.res.v1 ? css('--v1') : css('--v2'); ctx.globalAlpha = .35; ctx.lineWidth = 1.2; ctx.beginPath();
  for (let i = Math.max(0, k - 60); i <= k; i++) { const e = F[i].Y[0].pointingError; const x = cx + e[0] * sc, y = cy - e[1] * sc; i === Math.max(0, k - 60) ? ctx.moveTo(x, y) : ctx.lineTo(x, y); }
  ctx.stroke(); ctx.globalAlpha = 1;
  // beam footprint: e^-2 radius equals the divergence
  const f = F[k], e = f.Y[0].pointingError, bx = cx + e[0] * sc, by = cy - e[1] * sc, r = c.divergence * sc;
  const dim = f.Y[0].power <= 0 ? 0 : Math.min(1, f.Y[0].power / res.p0);
  const g = ctx.createRadialGradient(bx, by, 0, bx, by, r);
  const beam = css('--bad');
  g.addColorStop(0, hexA(beam, .85 * dim + .05)); g.addColorStop(.5, hexA(beam, .35 * dim + .02)); g.addColorStop(1, hexA(beam, 0));
  ctx.fillStyle = g; ctx.beginPath(); ctx.arc(bx, by, r, 0, 7); ctx.fill();
  // receiver: sensitivity contour for this link's current power scale
  const avail = f.Y[0].available;
  ctx.strokeStyle = avail ? css('--fg') : css('--bad'); ctx.lineWidth = 2;
  ctx.beginPath(); ctx.arc(cx, cy, 5, 0, 7); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(cx - 12, cy); ctx.lineTo(cx + 12, cy); ctx.moveTo(cx, cy - 12); ctx.lineTo(cx, cy + 12); ctx.stroke();
  const rs = Math.sqrt(Math.max(0, -Math.log(c.sensitivity / res.p0) / 2)) * c.divergence * sc;
  ctx.setLineDash([4, 4]); ctx.strokeStyle = css('--muted'); ctx.lineWidth = 1; ctx.beginPath(); ctx.arc(cx, cy, rs, 0, 7); ctx.stroke(); ctx.setLineDash([]);
  // correction arrow
  const corr = f.dec[0].correction;
  if (Math.hypot(...corr) > 1e-7) {
    ctx.strokeStyle = css('--good'); ctx.lineWidth = 1.6;
    ctx.beginPath(); ctx.moveTo(bx, by); ctx.lineTo(bx + corr[0] * sc, by - corr[1] * sc); ctx.stroke();
  }
  ctx.fillStyle = css('--fg'); ctx.beginPath(); ctx.arc(bx, by, 2.5, 0, 7); ctx.fill();
}
function hexA(color, a) {
  const m = color.match(/^#([0-9a-f]{6})$/i); if (!m) return color;
  const v = parseInt(m[1], 16); return `rgba(${v >> 16 & 255},${v >> 8 & 255},${v & 255},${Math.max(0, Math.min(1, a)).toFixed(3)})`;
}

// ---------- charts ----------
function axes(ctx, w, h, ymax, unit, c) {
  const L = 40, R = 8, T = 6, B = 18, pw = w - L - R, ph = h - T - B;
  const X = t => L + pw * t / c.T, Y = v => T + ph * (1 - v / ymax);
  ctx.fillStyle = css('--soft');
  ctx.fillRect(X(c.faultStart), T, X(Math.min(c.T, c.faultEnd)) - X(c.faultStart), ph);
  ctx.strokeStyle = css('--line'); ctx.fillStyle = css('--muted'); ctx.font = '11px "IBM Plex Sans", sans-serif'; ctx.lineWidth = 1;
  for (let i = 0; i <= 4; i++) { const v = ymax * i / 4; ctx.beginPath(); ctx.moveTo(L, Y(v)); ctx.lineTo(w - R, Y(v)); ctx.stroke(); ctx.textAlign = 'right'; ctx.fillText(+v.toFixed(1) + '', L - 5, Y(v) + 3); }
  ctx.textAlign = 'center';
  for (let t = 0; t <= c.T; t += 2) ctx.fillText(t + 's', X(t), h - 4);
  ctx.textAlign = 'left';
  return { X, Y, L, R, T, B, pw, ph };
}
function series(ctx, F, get, X, Y, color) {
  ctx.strokeStyle = color; ctx.lineWidth = 1.6; ctx.beginPath();
  F.forEach((f, i) => { const x = X(f.t), y = Y(get(f)); i ? ctx.lineTo(x, y) : ctx.moveTo(x, y); }); ctx.stroke();
}
function cursor(ctx, x, T, ph) { ctx.strokeStyle = css('--fg'); ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(x, T); ctx.lineTo(x, T + ph); ctx.stroke(); }

function drawCharts(k) {
  const { v1, v2 } = S.res, c = v2.config, t = v2.frames[k].t;
  { const { ctx, w, h } = fit($('cPow'));
    const ymax = Math.max(4.2, ...v1.frames.concat(v2.frames).map(f => f.Y[0].measuredPower * 1e6)) * 1.02;
    const a = axes(ctx, w, h, ymax, 'µW', c);
    ctx.setLineDash([4, 4]); ctx.strokeStyle = css('--muted'); ctx.beginPath(); ctx.moveTo(a.L, a.Y(1.5)); ctx.lineTo(w - a.R, a.Y(1.5)); ctx.stroke(); ctx.setLineDash([]);
    series(ctx, v1.frames, f => f.Y[0].measuredPower * 1e6, a.X, a.Y, css('--v1'));
    series(ctx, v2.frames, f => f.Y[0].measuredPower * 1e6, a.X, a.Y, css('--v2'));
    cursor(ctx, a.X(t), a.T, a.ph); }
  { const { ctx, w, h } = fit($('cPt'));
    const pe = f => Math.hypot(...f.Y[0].pointingError) * 1e6;
    const ymax = Math.max(10, ...v1.frames.concat(v2.frames).map(pe)) * 1.08;
    const a = axes(ctx, w, h, ymax, 'µrad', c);
    series(ctx, v1.frames, pe, a.X, a.Y, css('--v1')); series(ctx, v2.frames, pe, a.X, a.Y, css('--v2'));
    cursor(ctx, a.X(t), a.T, a.ph); }
  { const { ctx, w, h } = fit($('cCls'));
    const L = 40, R = 8, pw = w - L - R, rows = [['Real', f => f.dec[0].truth, v2], ['V1', f => f.dec[0].label, v1], ['V2', f => f.dec[0].label, v2]];
    const rh = (h - 8) / 3;
    rows.forEach(([name, get, res], r) => {
      ctx.fillStyle = r === 1 ? css('--v1') : r === 2 ? css('--v2') : css('--muted');
      ctx.font = '500 11px "IBM Plex Sans", sans-serif'; ctx.textAlign = 'right'; ctx.fillText(name, L - 6, 4 + rh * r + rh / 2 + 3); ctx.textAlign = 'left';
      const F = res.frames, dx = pw / F.length;
      F.forEach((f, i) => { ctx.fillStyle = CLASS_COLORS[get(f)]; ctx.fillRect(L + i * dx, 4 + rh * r + 1, dx + .6, rh - 3); });
    });
    cursor(ctx, L + pw * t / c.T, 2, h - 4); }
}
['cPow', 'cPt', 'cCls'].forEach(id => $(id).addEventListener('click', e => {
  const r = $(id).getBoundingClientRect(), c = S.res.v2.config, frac = (e.clientX - r.left - 40) / (r.width - 48);
  S.k = Math.max(0, Math.min(S.res.v2.frames.length - 1, Math.round(frac * c.T / c.dt))); S.playing = false; syncPlay(); render();
}));

// ---------- metrics + log ----------
function buildMetrics() {
  const a = S.res.v1.metrics, b = S.res.v2.metrics;
  const rows = [
    ['Right about fault / no fault', 'detection_accuracy', pct, 1], ['Named the exact fault', 'isolation_accuracy', pct, 1], ['False alarms while healthy', 'false_positive_rate', pct, -1],
    ['Said "uncertain"', 'uncertain_frequency', pct, -1], ['Link 1 down', 'link_outage_s', v => fmt(v) + ' s', -1],
    ['Down after fault cleared', 'postclear_outage_s', v => fmt(v) + ' s', -1], ['First alarm after', 'diagnosis_time_s', v => fmt(v) + ' s', -1],
    ['No route at all', 'network_outage_s', v => fmt(v) + ' s', -1],
  ];
  $('metrics').innerHTML = '<thead><tr><th></th><th class="v1">V1</th><th class="v2">V2</th></tr></thead><tbody>' + rows.map(([n, k, f, dir]) => {
    const x = a[k], y = b[k], ok = Number.isFinite(x) && Number.isFinite(y) && x !== y;
    const v2win = ok && (dir > 0 ? y > x : y < x), v1win = ok && !v2win;
    return `<tr><td>${n}</td><td${v1win ? ' style="font-weight:600"' : ''}>${f(x)}</td><td${v2win ? ' style="font-weight:600"' : ''}>${f(y)}</td></tr>`;
  }).join('') + '</tbody>';
}
function buildLog() {
  const ev = [];
  ['v1', 'v2'].forEach(impl => {
    let pl = -1, pa = -1, pu = null, pr = '', pc = false;
    S.res[impl].frames.forEach((f, k) => {
      const d = f.dec[0], up = f.Y[0].available, rt = f.route.path.join('→'), hasCorr = Math.hypot(...d.correction) > 0;
      if (pc && !hasCorr) ev.push({ k, impl, text: 'correction removed' });
      pc = hasCorr;
      if (d.label !== pl && f.t >= 1) ev.push({ k, impl, text: `thinks: ${CLASS_NAMES[d.label].toLowerCase()}` });
      if (d.action !== pa && f.t >= 1 && d.action !== 0) {
        let txt = ACTION_NAMES[d.action].toLowerCase();
        if (d.action === 3 && Math.hypot(...d.correction) > 0) txt += ` (${(d.correction[0] * 1e6).toFixed(1)}, ${(d.correction[1] * 1e6).toFixed(1)}) µrad`;
        ev.push({ k, impl, text: txt });
      }
      if (pu !== null && up !== pu) ev.push({ k, impl, text: up ? 'link 1 back above 1.5 µW' : 'link 1 dropped below 1.5 µW' });
      if (pr && rt !== pr) ev.push({ k, impl, text: rt ? `traffic now goes ${rt}` : 'no route from S1 to S2' });
      pl = d.label; pa = d.action; pu = up; pr = rt;
    });
  });
  const c = S.res.v2.config, kStart = Math.round(c.faultStart / c.dt), kEnd = Math.round(c.faultEnd / c.dt);
  if (S.res.p.scenario !== 'normal') {
    ev.push({ k: kStart, impl: 'truth', text: `${SCEN_LABEL[S.res.p.scenario].toLowerCase()} starts (${S.res.p.profile})` });
    if (c.profile !== 'persistent' && kEnd < S.res.v2.frames.length) ev.push({ k: kEnd, impl: 'truth', text: 'fault clears' });
  }
  ev.sort((a, b) => a.k - b.k || (a.impl === 'truth' ? -1 : 1));
  S.events = ev;
  $('logCount').textContent = `${ev.length} events, click one to jump there`;
  $('log').innerHTML = ev.map((e, i) => `<button type="button" data-k="${e.k}" data-i="${i}"><span class="tm">${(e.k * c.dt).toFixed(2)}s</span>`
    + `<span class="${e.impl === 'v1' ? 'v1' : e.impl === 'v2' ? 'v2' : ''}">${e.impl === 'truth' ? '' : e.impl.toUpperCase()}</span><span>${e.text}</span></button>`).join('');
}
$('log').addEventListener('click', e => { const b = e.target.closest('button'); if (!b) return; S.k = +b.dataset.k; S.playing = false; syncPlay(); render(); });

// ---------- frame render ----------
function render(tNow = performance.now() / 1000) {
  if (!S.res) return;
  const res = S.res[S.impl], f = res.frames[S.k], c = res.config;
  $('scrub').value = S.k;
  const y = f.Y[0], d = f.dec[0], other = S.impl === 'v1' ? 'V2' : 'V1', who = S.impl.toUpperCase();
  const route = f.route.path.length === 0 ? 'there is no route from satellite 1 to satellite 2'
    : f.route.path.length === 2 ? 'traffic goes straight from 1 to 2' : `traffic goes the long way, ${f.route.path.join(' → ')}`;
  const act = d.action ? `, and it is currently ${ACTION_NAMES[d.action].toLowerCase()}` : '';
  $('pills').innerHTML = `<span class="t">${f.t.toFixed(2)} s</span>, showing ${who}. Link 1 is `
    + (y.available ? `up at ${(y.measuredPower * 1e6).toFixed(2)} µW` : `<span style="color:var(--bad)">down at ${(y.measuredPower * 1e6).toFixed(2)} µW</span>`)
    + ` and ${route}. Real fault: ${d.truth ? CLASS_NAMES[d.truth].toLowerCase() : 'none'}. ${who} thinks: ${CLASS_NAMES[d.label].toLowerCase()}${act}.`
    + ` <span class="note">(Switch to ${other} with the buttons above the beam view.)</span>`;
  drawNet(f, c, tNow); drawScope(res, S.k); drawCharts(S.k);
  $('log').querySelectorAll('button').forEach(b => b.className = +b.dataset.k <= S.k ? 'past' : 'future');
}

function loop(ts) {
  const now = ts / 1000;
  if (S.res && S.playing) {
    S.acc += Math.min(0.1, now - (S.last || now)) * S.speed;
    const dt = S.res.v2.config.dt, n = Math.floor(S.acc / dt);
    if (n > 0) { S.acc -= n * dt; S.k = Math.min(S.res.v2.frames.length - 1, S.k + n); if (S.k === S.res.v2.frames.length - 1) { S.playing = false; syncPlay(); } }
  }
  S.last = now;
  if (S.res) render(now);
  requestAnimationFrame(loop);
}

// ---------- benchmark sweep ----------
$('sweepBtn').addEventListener('click', async () => {
  const btn = $('sweepBtn'), prog = $('sweepProg'); btn.disabled = true; prog.hidden = false; prog.value = 0;
  const seeds = [101, 202, 303, 404, 505], out = {}, total = SCENARIOS.length * seeds.length * 2; let done = 0;
  for (const sc of SCENARIOS) {
    out[sc] = { v1: [], v2: [] };
    for (const seed of seeds) for (const impl of ['v1', 'v2']) {
      out[sc][impl].push(simulate({ n: S.n, scenario: sc, seed, implementation: impl }).metrics);
      done++; prog.value = done / total;
      if (done % 4 === 0) await new Promise(r => setTimeout(r, 0));
    }
  }
  const mean = (arr, k) => { const v = arr.map(m => m[k]).filter(Number.isFinite); return v.length ? v.reduce((s, x) => s + x, 0) / v.length : NaN; };
  const ref = window.SITE_DATA && window.SITE_DATA.scenario_n4;
  const cell = (b, m, p = true) => `${p ? pct(b) : fmt(b)}<br><span style="color:var(--muted)">${ref ? (p ? pct(m) : fmt(m)) : ''}</span>`;
  const rows = SCENARIOS.filter(s => s !== 'normal').map(s => {
    const r = ref && ref[s];
    return `<tr><td>${SCEN_LABEL[s]}</td><td>${cell(mean(out[s].v1, 'isolation_accuracy'), r && r.v1.isolation_accuracy.mean)}</td>`
      + `<td>${cell(mean(out[s].v2, 'isolation_accuracy'), r && r.v2.isolation_accuracy.mean)}</td>`
      + `<td>${cell(mean(out[s].v2, 'false_positive_rate'), r && r.v2.false_positive_rate.mean)}</td>`
      + `<td>${cell(mean(out[s].v2, 'link_outage_s'), r && r.v2.link_outage_s.mean, false)}</td></tr>`;
  }).join('');
  $('sweepOut').innerHTML = `<table><thead><tr><th>Fault</th><th class="v1">V1 named it</th><th class="v2">V2 named it</th><th class="v2">V2 false alarms</th><th class="v2">V2 link down (s)</th></tr></thead><tbody>${rows}</tbody></table>`
    + `<p class="note" style="margin-top:.5rem">Each cell: this browser run (${S.n} satellites) on top, the MATLAB average for the same five seeds underneath in grey${S.n !== 4 ? '. Diagnosis scores are the same at every network size' : ''}.</p>`;
  btn.disabled = false; prog.hidden = true;
});

window.addEventListener('resize', () => render());
run();
requestAnimationFrame(loop);
