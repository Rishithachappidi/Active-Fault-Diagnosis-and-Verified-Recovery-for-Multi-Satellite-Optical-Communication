// Browser port of the MATLAB/Simulink satellite optical network model.
// Sources: matlab/configuration/default_config.m, optical_channel/*.m,
// fault_injection/fault_input.m, simulink/supervisor_sfun.m (V1),
// revisions/v2/v2_decision_step.m (V2), network/*.m, metrics/compute_metrics.m.
// Differences from MATLAB: fixed-step RK4 instead of Simulink's variable-step
// solver and a different random-number generator, so numbers are close to but
// not identical with the verified MATLAB batch.

export const SCENARIOS = ['normal', 'pointing', 'effectiveness', 'lag', 'power', 'blockage', 'sensor', 'simultaneous'];
export const PROFILES = ['sudden', 'gradual', 'intermittent', 'persistent'];
export const CLASS_NAMES = ['Healthy', 'Boresight offset', 'Actuator gain loss', 'Actuator lag', 'Optical power loss',
  'Blockage', 'Sensor bias', 'Uncertain', 'Offset + power loss'];
export const ACTION_NAMES = ['Monitor', 'Reroute traffic', 'Probing optics', 'Apply correction', 'Flag actuator maintenance', 'Roll back correction'];

// ---------- configuration ----------
export function defaultConfig(n = 4) {
  const c = {
    n, topology: 'mesh', seed: 101, dt: 0.02, T: 10,
    J: 0.002, b: 0.004, tau: 0.08, umax: 2e-6, rateMax: 120e-6,
    lambda: 8, K: 80e-6, phi: 8e-6, initialAngle: [2e-6, -1e-6], noise: 0.08e-6, powerNoise: 0.008,
    Pt: 0.5, eta: 0.4, divergence: 20e-6, aperture: 0.10, distance: 800e3, sensitivity: 1.5e-6,
    capacity: 1e9, offered: 0.6e9, packetBits: 12000, c: 299792458, processing: 1e-4,
    scenario: 'normal', faultStart: 2, faultEnd: 8, profile: 'sudden', severity: 1,
    probeAmplitude: 6e-6, probeDwell: 0.5, maxCorrection: 35e-6, detectRatio: 0.72, decisionPeriod: 0.1, warmup: 1,
    // V2 nominal thresholds (revisions/v2/v2_nominal.m)
    biasThreshold: 3e-6, offsetThreshold: 4e-6, gainThreshold: 0.8, fitWindow: 0.8, history: 150, cooldown: 0.6,
  };
  c.edges = makeNetwork(n);
  c.m = c.edges.length;
  return c;
}

export function makeNetwork(n) {
  const e = [];
  for (let i = 1; i <= n; i++) e.push([Math.min(i, i % n + 1), Math.max(i, i % n + 1)]);
  const chords = [];
  for (let i = 1; i <= n / 2; i++) chords.push([i, i + n / 2]);
  (n === 4 ? chords.slice(0, 1) : chords).forEach(ch => e.push(ch));
  const key = a => a[0] * 100 + a[1];
  const uniq = [...new Map(e.map(x => [key(x), x])).values()];
  return uniq.sort((a, b) => key(a) - key(b));
}

// ---------- random numbers (seeded, Box-Muller) ----------
function mulberry32(a) {
  return () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; };
}
function gaussianStream(seed) {
  const r = mulberry32(seed);
  return () => { let u = 0; while (u === 0) u = r(); return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * r()); };
}

// ---------- optics ----------
export function nominalPower(c) {
  const w = c.distance * c.divergence, a = c.aperture / 2;
  return c.Pt * c.eta * (1 - Math.exp(-2 * a * a / (w * w)));
}
const sq = v => v[0] * v[0] + v[1] * v[1];
const norm = v => Math.hypot(v[0], v[1]);
const clamp = (x, lo, hi) => Math.max(lo, Math.min(hi, x));

// ---------- fault injection (truth layer only) ----------
export function faultInput(t, edge, c) {
  // u: ref(2) gain lagFactor powerScale blocked sensorBias(2) opticalOffset(2) noiseOn
  const u = { ref: [0, 0], gain: 1, lag: 1, scale: 1, blocked: 0, bias: [0, 0], offset: [0, 0], noiseOn: 1 };
  let label = 0;
  if (edge !== 0 || t < c.faultStart || (t >= c.faultEnd && c.profile !== 'persistent')) return { u, label };
  let g = c.severity;
  if (c.profile === 'gradual') g *= Math.min(1, (t - c.faultStart) / 2);
  if (c.profile === 'intermittent') g *= ((t - c.faultStart) % 2) < 1 ? 1 : 0;
  if (g === 0) return { u, label };
  const off = [g * 23e-6, g * 10e-6];
  switch (c.scenario) {
    case 'pointing': u.offset = off; label = 1; break;
    case 'effectiveness': u.gain = Math.max(0.05, 1 - 0.75 * g); label = 2; break;
    case 'lag': u.lag = 1 + 5 * g; label = 3; break;
    case 'power': u.scale = Math.max(0.01, 1 - 0.82 * g); label = 4; break;
    case 'blockage': u.blocked = 1; label = 5; break;
    case 'sensor': u.bias = off; label = 6; break;
    case 'simultaneous': u.offset = off; u.scale = Math.max(0.01, 1 - 0.65 * g); label = 8; break;
  }
  return { u, label };
}

// ---------- terminal plant (simulink/terminal_kernel.m, SMC controller) ----------
function controlLaw(x, u, z, c) {
  const theta = [x[0], x[1]], v = [x[2], x[3]];
  const ym = [theta[0] + u.bias[0] + c.noise * u.noiseOn * z[0], theta[1] + u.bias[1] + c.noise * u.noiseOn * z[1]];
  const vm = [v[0] + c.noise * 2 * z[2], v[1] + c.noise * 2 * z[3]];
  const e = [ym[0] - u.ref[0], ym[1] - u.ref[1]];
  const s = [vm[0] + c.lambda * e[0], vm[1] + c.lambda * e[1]];
  const raw = [0, 1].map(k => c.b * vm[k] - c.J * c.lambda * vm[k] - c.J * c.K * clamp(s[k] / c.phi, -1, 1));
  const cmd = raw.map(r => clamp(r, -c.umax, c.umax));
  return { ym, vm, e, s, raw, cmd };
}
function deriv(x, u, z, c) {
  const { raw, cmd, e } = controlLaw(x, u, z, c);
  const v = [x[2], x[3]], a = [x[4], x[5]];
  const dv = [0, 1].map(k => { let d = (a[k] - c.b * v[k]) / c.J; if (Math.abs(v[k]) >= c.rateMax && Math.sign(v[k]) * d > 0) d = 0; return d; });
  const di = [0, 1].map(k => Math.abs(raw[k]) > c.umax ? 0 : e[k]);
  return [clamp(v[0], -c.rateMax, c.rateMax), clamp(v[1], -c.rateMax, c.rateMax), dv[0], dv[1],
    (u.gain * cmd[0] - a[0]) / (c.tau * u.lag), (u.gain * cmd[1] - a[1]) / (c.tau * u.lag), di[0], di[1]];
}
function plantOutput(x, u, z, c, p0) {
  const { ym, vm, raw, cmd } = controlLaw(x, u, z, c);
  const err = [x[0] + u.offset[0], x[1] + u.offset[1]];
  const power = p0 * Math.exp(-2 * sq(err) / (c.divergence ** 2)) * Math.max(0, u.scale) * (u.blocked > 0 ? 0 : 1);
  const available = power / c.sensitivity >= 1;
  return {
    ref: u.ref, theta: [x[0], x[1]], pointingError: err, cmd, delivered: [x[4], x[5]], saturated: raw.some(r => Math.abs(r) > c.umax),
    power, available, angle: ym, rate: vm, measuredPower: Math.max(0, power * (1 + c.powerNoise * z[4])),
  };
}
function rk4(x, u, z, c, h) {
  const add = (a, b, s) => a.map((v, i) => v + s * b[i]);
  const k1 = deriv(x, u, z, c), k2 = deriv(add(x, k1, h / 2), u, z, c), k3 = deriv(add(x, k2, h / 2), u, z, c), k4 = deriv(add(x, k3, h), u, z, c);
  return x.map((v, i) => v + h / 6 * (k1[i] + 2 * k2[i] + 2 * k3[i] + k4[i]));
}

// ---------- small linear algebra ----------
function solve(A, b) { // Gaussian elimination with partial pivoting
  const n = A.length, M = A.map((r, i) => [...r, b[i]]);
  for (let i = 0; i < n; i++) {
    let p = i; for (let r = i + 1; r < n; r++) if (Math.abs(M[r][i]) > Math.abs(M[p][i])) p = r;
    [M[i], M[p]] = [M[p], M[i]];
    if (Math.abs(M[i][i]) < 1e-300) return null;
    for (let r = i + 1; r < n; r++) { const f = M[r][i] / M[i][i]; for (let k = i; k <= n; k++) M[r][k] -= f * M[i][k]; }
  }
  const x = Array(n).fill(0);
  for (let i = n - 1; i >= 0; i--) { let s = M[i][n]; for (let k = i + 1; k < n; k++) s -= M[i][k] * x[k]; x[i] = s / M[i][i]; }
  return x;
}
function inverse(A) {
  const n = A.length; const cols = [];
  for (let j = 0; j < n; j++) { const e = Array(n).fill(0); e[j] = 1; const x = solve(A, e); if (!x) return null; cols.push(x); }
  return A.map((_, i) => cols.map(col => col[i]));
}
const norm1 = A => Math.max(...A[0].map((_, j) => A.reduce((s, r) => s + Math.abs(r[j]), 0)));
function rcond(A) { const inv = inverse(A); return inv ? 1 / (norm1(A) * norm1(inv)) : 0; }
function lstsq(X, y) { // returns {beta, XtX}
  const p = X[0].length, XtX = Array.from({ length: p }, () => Array(p).fill(0)), Xty = Array(p).fill(0);
  X.forEach((row, r) => { for (let i = 0; i < p; i++) { Xty[i] += row[i] * y[r]; for (let j = 0; j < p; j++) XtX[i][j] += row[i] * row[j]; } });
  return { beta: solve(XtX, Xty), XtX };
}

// ---------- V1 supervisor (simulink/supervisor_sfun.m, method = proposed) ----------
function selectProbe(power, refNorm, c, p0) {
  const noise = Math.max(c.powerNoise, 0.005);
  let best = -Infinity, amp = 0;
  [0, 0.5, 1].map(k => k * c.probeAmplitude).forEach(A => {
    const sep = 2 * A / c.divergence, loss = 1 - Math.exp(-2 * (A / c.divergence) ** 2);
    const feasible = refNorm + A <= c.maxCorrection && A / c.probeDwell < c.rateMax / 2;
    const score = feasible ? sep * sep / (noise * noise) - 10 * loss : -Infinity;
    if (score > best) { best = score; amp = A; }
  });
  if (power > c.detectRatio * p0 || power < 0.01 * p0) amp = 0;
  return amp;
}

class SupervisorV1 {
  constructor(c, p0) { this.c = c; this.p0 = p0; this.corr = [0, 0]; this.start = 0; this.amp = 0; this.fits = []; this.state = 0; this.prevTorque = [0, 0]; this.fitLabel = 0; this.label = 0; this.action = 0; this.estimate = null; }
  step(t, o, decision) {
    const c = this.c, p0 = this.p0;
    if (decision && t >= c.warmup) {
      let label = 0;
      const nominal = p0 * Math.exp(-2 * sq(o.angle) / c.divergence ** 2);
      if (o.power / p0 < c.detectRatio || Math.abs(o.power - nominal) / p0 > 0.3) label = 7;
      const adot = [0, 1].map(k => (o.delivered[k] - this.prevTorque[k]) / c.decisionPeriod);
      const res = Math.hypot(...[0, 1].map(k => c.tau * adot[k] + o.delivered[k] - o.command[k]));
      if (res > 0.12 * c.umax && norm(o.command) > 0.15 * c.umax) label = 7;
      this.prevTorque = [...o.delivered];
      this.label = label;
      if (this.state === 0 && label !== 0) {
        const A = selectProbe(o.power, norm(o.reference), c, p0);
        if (A > 0) { this.start = t; this.amp = A; this.state = 1; }
      }
    }
    let probe = [0, 0];
    const elapsed = t - this.start;
    if (this.state === 1 && this.amp > 0) {
      const phase = Math.floor(elapsed / c.probeDwell) + 1;
      if (phase <= 4) {
        const dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]][Math.max(1, phase) - 1];
        probe = [this.amp * dirs[0], this.amp * dirs[1]]; this.action = 2;
        if (decision && (elapsed % c.probeDwell) > 0.15 && o.power > 0.005 * p0 && this.fits.length < 200)
          this.fits.push([1, o.angle[0] / c.divergence, o.angle[1] / c.divergence, Math.log(o.power / p0) + 2 * sq(o.angle) / c.divergence ** 2]);
      } else {
        // active_fit.m then recovery_decision.m
        let fl = 7, offset = [0, 0], gain = NaN;
        const X = this.fits.map(r => r.slice(0, 3)), z = this.fits.map(r => r[3]);
        if (X.length >= 12) {
          const { beta, XtX } = lstsq(X, z);
          if (beta && rcond(XtX) >= 1e-4) {
            offset = [-beta[1] * c.divergence / 4, -beta[2] * c.divergence / 4];
            gain = Math.exp(beta[0] + 2 * sq(offset) / c.divergence ** 2);
            fl = norm(offset) > 4e-6 ? 7 : gain < 0.7 ? 4 : 0;
          }
        }
        let corr = [0, 0], action = 1;
        if (fl === 7 && norm(offset) > 4e-6) {
          corr = [-offset[0], -offset[1]];
          if (norm(corr) > c.maxCorrection) corr = corr.map(v => v * c.maxCorrection / norm(corr));
          action = 3;
        } else if (fl === 2 || fl === 3) action = 4;
        this.corr = corr; this.action = action; this.state = 2; this.fitLabel = fl;
        this.estimate = { offset, gain };
      }
    }
    if (this.state === 2) this.label = this.fitLabel;
    return { label: this.label, action: this.action, correction: this.corr, probe };
  }
}

// ---------- V2 supervisor (revisions/v2/v2_decision_step.m) ----------
function actuatorFit(H, c) {
  const out = { label: 7, eta: NaN, tau: NaN, condition: 0, err: Infinity };
  if (H.length < 15) return out;
  const X = [], y = [];
  for (let i = 0; i < H.length - 1; i++) {
    const dt = H[i + 1].t - H[i].t;
    if (!(dt > 0 && dt < 1.1 * c.dt)) continue;
    for (let k = 0; k < 2; k++) {
      X.push([H[i].cmd[k], -(H[i].del[k] + H[i + 1].del[k]) / 2]);
      y.push((H[i + 1].del[k] - H[i].del[k]) / dt);
    }
  }
  if (!X.length) return out;
  const scale = Math.max(...X.flat().map(Math.abs));
  if (scale < 1e-11) return out;
  const Xs = X.map(r => r.map(v => v / scale)), ys = y.map(v => v / scale);
  const { beta, XtX } = lstsq(Xs, ys);
  out.condition = rcond(XtX);
  if (out.condition < 2e-4 || !beta || beta[1] <= 0) return out;
  const tau = 1 / beta[1], eta = beta[0] * tau;
  const resid = Math.hypot(...Xs.map((r, i) => r[0] * beta[0] + r[1] * beta[1] - ys[i])), yn = Math.hypot(...ys);
  const err = resid / Math.max(yn, Number.EPSILON);
  Object.assign(out, { eta, tau, err });
  if (err > 0.5 || eta < 0.01 || eta > 2 || tau < 0.01 || tau > 2) return out;
  const gainF = eta < 0.65, lagF = tau > 1.8 * c.tau;
  out.label = gainF && !lagF ? 2 : lagF && !gainF ? 3 : gainF && lagF ? 7 : 0;
  return out;
}
function opticalFit(H, c, p0) {
  const out = { ok: false, offset: [0, 0], gain: 1, condition: 0, err: Infinity };
  const G = H.filter(h => h.power > 0.005 * p0);
  if (G.length < 20) return out;
  const X = G.map(h => [1, h.q[0] / c.divergence, h.q[1] / c.divergence]);
  const z = G.map(h => Math.log(h.power / p0) + 2 * sq(h.q) / c.divergence ** 2);
  const { beta, XtX } = lstsq(X, z);
  out.condition = rcond(XtX);
  if (out.condition < 1e-4 || !beta) return out;
  const offset = [-beta[1] * c.divergence / 4, -beta[2] * c.divergence / 4];
  const gain = Math.exp(beta[0] + 2 * sq(offset) / c.divergence ** 2);
  const res = z.map((v, i) => v - (X[i][0] * beta[0] + X[i][1] * beta[1] + X[i][2] * beta[2]));
  const ss = res.reduce((s, r) => s + r * r, 0), err = Math.sqrt(ss / res.length);
  const inv = inverse(XtX);
  const s2 = ss / Math.max(X.length - 3, 1);
  const offsetSE = inv ? c.divergence * Math.sqrt(Math.max(0, s2 * (inv[1][1] + inv[2][2]))) / 4 : Infinity;
  Object.assign(out, { offset, gain, err, ok: err < 0.08 && offsetSE < 2e-6 && gain > 0.02 && gain < 1.5 && norm(offset) < 60e-6 });
  return out;
}

class SupervisorV2 {
  constructor(c, p0) {
    this.c = c; this.p0 = p0; this.H = [];
    Object.assign(this, { kin: [0, 0], bias: [0, 0], prevRate: [0, 0], init: false, probeStart: 0, mode: 0, valid: false, offset: [0, 0], gain: 1,
      mismatch: 0, lastReset: 0, label: 0, eta: 1, tau: c.tau, act: 0, actErr: 1e6, actCond: 0, probeAmp: 0, healthy: 0, verified: false });
  }
  step(t, o) {
    const c = this.c, p0 = this.p0;
    // history uses the predicted kinetic angle for this sample (supervisor_v2.m)
    const q = this.init ? [0, 1].map(k => this.kin[k] + c.dt * (this.prevRate[k] + o.rate[k]) / 2) : [...o.angle];
    this.H.push({ t, q, power: o.power, cmd: [...o.command], del: [...o.delivered] });
    if (this.H.length > c.history) this.H.shift();
    if (!this.init) { this.kin = [...o.angle]; this.prevRate = [...o.rate]; this.init = true; this.gain = 1; this.tau = c.tau; }
    else { this.kin = q; this.prevRate = [...o.rate]; }
    this.bias = [0, 1].map(k => 0.5 * this.bias[k] + 0.5 * (o.angle[k] - this.kin[k]));
    let label = this.label, action = 0, probe = [0, 0];
    const wobble = [1e-6 * Math.sin(2 * t), 0.5e-6 * Math.sin(2 * t)];
    if (t < 1) return { label, action, correction: [0, 0], probe, ref: wobble };
    const decision = Math.round(t / c.dt) % Math.round(c.decisionPeriod / c.dt) === 0;
    const biasFlag = norm(this.bias) > c.biasThreshold;
    if (decision) {
      const a = actuatorFit(this.H.filter(h => h.t >= t - c.fitWindow), c);
      this.eta = isFinite(a.eta) ? a.eta : 1; this.tau = isFinite(a.tau) ? a.tau : c.tau; this.act = a.label;
      this.actErr = isFinite(a.err) ? a.err : 1e6; this.actCond = a.condition;
      const expected = p0 * this.gain * Math.exp(-2 * sq([this.kin[0] + this.offset[0], this.kin[1] + this.offset[1]]) / c.divergence ** 2);
      const mism = Math.abs(Math.log(Math.max(o.power, 0.001 * p0) / Math.max(expected, 0.001 * p0))) > 0.35;
      this.mismatch = this.valid && mism ? this.mismatch + 1 : 0;
      if (this.mismatch >= 2) {
        this.valid = false; this.offset = [0, 0]; this.gain = 1; this.mode = -1; this.lastReset = t; this.mismatch = 0; this.verified = false; action = 5;
      }
    }
    const nominal = p0 * Math.exp(-2 * sq(this.kin) / c.divergence ** 2);
    const optResidual = Math.abs(Math.log(Math.max(o.power, 0.001 * p0) / Math.max(nominal, 0.001 * p0)));
    const dark = o.power < 0.005 * p0;
    if (this.mode === -1 && t - this.lastReset >= c.cooldown) this.mode = 0;
    if (decision && this.mode === 0 && !this.valid && optResidual > 0.35 && !dark) {
      const amp = selectProbe(Math.min(o.power, 0.7 * p0), 0, c, p0);
      const torqueBound = c.J * 4 * amp / c.probeDwell ** 2 + c.b * 2 * amp / c.probeDwell;
      if (amp > 0 && torqueBound < c.umax) { this.mode = 1; this.probeStart = t; this.probeAmp = amp; this.valid = false; this.verified = false; }
    }
    if (this.mode === 1) {
      const elapsed = t - this.probeStart, phase = Math.min(4, Math.floor(elapsed / c.probeDwell) + 1);
      const d = [[1, 0], [-1, 0], [0, 1], [0, -1]][phase - 1];
      probe = [this.probeAmp * d[0], this.probeAmp * d[1]]; action = 2;
      if (decision && elapsed >= 1.4) {
        const sel = this.H.filter(h => { const age = h.t - this.probeStart; return age >= 0 && (age % c.probeDwell) > 0.12; });
        const f = opticalFit(sel, c, p0);
        if (f.ok) { this.offset = f.offset; this.gain = f.gain; this.valid = true; this.mode = 2; probe = [0, 0]; action = 3; }
        else if (elapsed >= 4 * c.probeDwell) { this.mode = -1; this.lastReset = t; probe = [0, 0]; action = 1; }
      }
    }
    const offsetFlag = this.valid && norm(this.offset) > c.offsetThreshold;
    const gainFlag = this.valid && this.gain < c.gainThreshold;
    const act = this.act;
    if (dark) label = 7;
    else if (this.mode === 1 || (!this.valid && optResidual > 0.35)) label = 7;
    else if (offsetFlag && gainFlag && !biasFlag && act === 0) label = 8;
    else if (Number(offsetFlag) + Number(gainFlag) + Number(biasFlag) + Number(act !== 0) > 1) label = 7;
    else if (biasFlag) label = 6;
    else if (offsetFlag) label = 1;
    else if (gainFlag) label = 4;
    else if (act === 2 || act === 3) label = act;
    else if (act === 7 && this.actCond >= 2e-4 && this.actErr < 0.5) label = 7;
    else label = 0;
    let bias = biasFlag ? [...this.bias] : [0, 0], offset = [0, 0];
    if (offsetFlag && p0 * this.gain >= 1.05 * c.sensitivity) offset = this.offset;
    let corr = [bias[0] - offset[0], bias[1] - offset[1]];
    if (norm(corr) > c.maxCorrection) corr = corr.map(v => v * c.maxCorrection / norm(corr));
    let ref = [corr[0] + probe[0] + wobble[0], corr[1] + probe[1] + wobble[1]];
    if (norm(ref) > c.maxCorrection) ref = ref.map(v => v * c.maxCorrection / norm(ref));
    if (norm(corr) > 0 && action === 0) action = 3;
    if (dark && action === 0) action = 1;
    if (o.power >= c.sensitivity) { this.healthy += c.dt; if (this.healthy >= 0.5) this.verified = true; } else { this.healthy = 0; this.verified = false; }
    this.label = label;
    return { label, action, correction: corr, probe, ref, estimate: { bias: this.bias, offset: this.offset, gain: this.gain, eta: this.eta, tau: this.tau, verified: this.verified } };
  }
}

// ---------- routing (network/route_network.m) ----------
export function route(c, available) {
  const cost = c.distance / c.c + c.processing + c.packetBits / c.capacity;
  const adj = Array.from({ length: c.n + 1 }, () => []);
  c.edges.forEach(([a, b], j) => { if (available[j]) { adj[a].push([b, j]); adj[b].push([a, j]); } });
  const d = Array(c.n + 1).fill(Infinity), prev = Array(c.n + 1).fill(0), prevE = Array(c.n + 1).fill(-1), seen = Array(c.n + 1).fill(false);
  d[1] = 0;
  for (let k = 0; k < c.n; k++) {
    let a = -1; for (let i = 1; i <= c.n; i++) if (!seen[i] && (a < 0 || d[i] < d[a])) a = i;
    if (a < 0 || !isFinite(d[a])) break; seen[a] = true;
    adj[a].forEach(([b, j]) => { if (d[a] + cost < d[b]) { d[b] = d[a] + cost; prev[b] = a; prevE[b] = j; } });
  }
  if (!isFinite(d[2])) return { path: [], edgeIDs: [], throughput: 0, latency: NaN, pdr: 0 };
  const path = [2], edgeIDs = [];
  while (path[0] !== 1) { edgeIDs.unshift(prevE[path[0]]); path.unshift(prev[path[0]]); }
  return { path, edgeIDs, throughput: Math.min(c.offered, c.capacity), latency: d[2], pdr: 1 };
}

// ---------- simulation ----------
export function simulate(opts = {}) {
  const c = Object.assign(defaultConfig(opts.n || 4), opts);
  c.edges = makeNetwork(c.n); c.m = c.edges.length;
  const p0 = nominalPower(c);
  const N = Math.round(c.T / c.dt);
  const sub = 4, h = c.dt / sub;
  const noise = c.edges.map((_, j) => { const g = gaussianStream(c.seed * 7919 + 1000 * j + 17); return Array.from({ length: N + 2 }, () => [g(), g(), g(), g(), g()]); });
  const x = c.edges.map(() => [c.initialAngle[0], c.initialAngle[1], 0, 0, 0, 0, 0, 0]);
  const Sup = opts.implementation === 'v1' ? SupervisorV1 : SupervisorV2;
  const sups = c.edges.map(() => new Sup(c, p0));
  let U = c.edges.map((_, j) => faultInput(0, j, c).u);
  const frames = [];
  for (let k = 0; k <= N; k++) {
    const t = +(k * c.dt).toFixed(10);
    const Y = c.edges.map((_, j) => plantOutput(x[j], U[j], noise[j][k], c, p0));
    const decision = Math.round(t / c.dt) % Math.round(c.decisionPeriod / c.dt) === 0;
    const Unext = [], dec = [];
    c.edges.forEach((_, j) => {
      const o = { angle: Y[j].angle, rate: Y[j].rate, power: Y[j].measuredPower, command: Y[j].cmd, delivered: Y[j].delivered, reference: Y[j].ref };
      const r = sups[j].step(t, o, decision);
      const { u, label: truth } = faultInput(t + c.dt, j, c);
      let ref = r.ref || [r.correction[0] + r.probe[0] + 1e-6 * Math.sin(2 * t), r.correction[1] + r.probe[1] + 0.5e-6 * Math.sin(2 * t)];
      if (norm(ref) > c.maxCorrection) ref = ref.map(v => v * c.maxCorrection / norm(ref));
      u.ref = ref; Unext.push(u);
      dec.push({ label: r.label, action: r.action, truth, correction: r.correction, probing: r.probe[0] !== 0 || r.probe[1] !== 0, estimate: r.estimate || null });
    });
    const rt = route(c, Y.map(y => y.available));
    frames.push({ t, Y, dec, route: rt });
    if (k < N) for (let j = 0; j < c.m; j++) for (let s = 0; s < sub; s++) x[j] = rk4(x[j], U[j], noise[j][k], c, h);
    U = Unext;
  }
  return { config: c, p0, frames, metrics: metrics(c, frames) };
}

// ---------- metrics (metrics/compute_metrics.m + v2_extra_metrics.m, edge 1) ----------
export function metrics(c, F) {
  const idx = F.filter(f => f.t >= c.warmup && f.t < c.T);
  let tp = 0, tn = 0, fp = 0, fn = 0, iso = 0, isoN = 0, unc = 0;
  idx.forEach(f => {
    const a = f.dec[0].truth !== 0, d = f.dec[0].label !== 0;
    if (a && d) tp++; else if (!a && !d) tn++; else if (!a && d) fp++; else fn++;
    if (a) { isoN++; if (f.dec[0].label === f.dec[0].truth) iso++; }
    if (f.dec[0].label === 7) unc++;
  });
  const div = (a, b) => b === 0 ? NaN : a / b;
  const first = F.find(f => f.t >= c.faultStart && f.dec[0].truth !== 0 && f.dec[0].label !== 0);
  const post = F.filter(f => f.t >= c.faultEnd && f.t < c.T);
  let recovery = NaN;
  const win = F.map((f, i) => [f, i]).filter(([f]) => f.t >= c.faultStart && f.t < c.faultEnd);
  const firstOut = win.find(([f]) => !f.Y[0].available);
  if (firstOut) {
    recovery = 0; const holdN = Math.round(0.5 / c.dt);
    for (let k = firstOut[1] + 1; k < F.length - holdN; k++) {
      if (F[k + holdN].t >= c.faultEnd) break;
      if (F.slice(k, k + holdN + 1).every(f => f.Y[0].available)) { recovery = 1; break; }
    }
  }
  return {
    detection_accuracy: (tp + tn) / idx.length, false_positive_rate: div(fp, fp + tn), isolation_accuracy: div(iso, isoN),
    uncertain_frequency: unc / idx.length, diagnosis_time_s: first ? first.t - c.faultStart : NaN,
    link_outage_s: idx.filter(f => !f.Y[0].available).length * c.dt,
    link_availability: idx.reduce((s, f) => s + f.Y.filter(y => y.available).length / c.m, 0) / idx.length,
    network_outage_s: idx.filter(f => f.route.throughput === 0).length * c.dt,
    postclear_outage_s: post.filter(f => !f.Y[0].available).length * c.dt,
    postclear_false_alarm_rate: div(post.filter(f => f.dec[0].label !== 0).length, post.length),
    recovery_success: recovery, active_probe_s: idx.filter(f => f.dec[0].probing).length * c.dt,
  };
}
