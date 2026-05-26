#!/usr/bin/env node

// ── A/B Performance benchmark for Lucy Game simulation ────────────────────
// Compares active-block iteration vs naive O(W×H) iteration at 8 densities.
// Both approaches run on the SAME grid for a fair comparison.
//
// Usage: node bench.mjs

import { new$ as createSim, steps, steps_naive, grid as simGrid } from './priv/javascript/lucy_game/simulation.mjs';
import {
  filled_with_air,
  set,
  sand,
  active_cell_count,
} from './priv/javascript/lucy_game/grid.mjs';

const W = 160;
const H = 100;
const PHASES_PER_ITERATION = 4;

// ── Benchmark helpers ────────────────────────────────────────────────────

function createGrid(density) {
  let g = filled_with_air(W, H);
  const total = Math.floor(W * H * density);
  for (let i = 0; i < total; i++) {
    const x = Math.floor(Math.random() * W);
    const y = Math.floor(Math.random() * H);
    g = set(g, x, y, sand());
  }
  return g;
}

function benchmarkBoth(label, density, phaseCount) {
  // Create ONE grid — both approaches start from identical state
  const g = createGrid(density);
  const sim = createSim(g);
  const active = active_cell_count(g);

  // Warmup: 4 phases using active-block (settle initial random placement)
  const warm = steps(sim, 4);

  // ── Active-block run ──────────────────────────────────────────────
  const warmActive = warm;  // Same warmup state
  const startA = performance.now();
  steps(warmActive, phaseCount);
  const elapsedA = performance.now() - startA;
  const stepsPerSecA = Math.round((phaseCount / elapsedA) * 1000);
  const marginsPerSecA = (stepsPerSecA / PHASES_PER_ITERATION).toFixed(1);

  // ── Naive O(W×H) run (same warmup, separate clone) ────────────────
  // Create a fresh copy from the same warmup state
  const warmNaive = createSim(simGrid(warm));
  const startN = performance.now();
  steps_naive(warmNaive, phaseCount);
  const elapsedN = performance.now() - startN;
  const stepsPerSecN = Math.round((phaseCount / elapsedN) * 1000);
  const marginsPerSecN = (stepsPerSecN / PHASES_PER_ITERATION).toFixed(1);

  const speedup = (elapsedN / elapsedA).toFixed(1);

  console.log(
    `${label.padEnd(20)} | ${String(active).padStart(5)} ` +
    `| ${String(marginsPerSecA).padStart(6)} m/s` +
    `  ${String(stepsPerSecA).padStart(6)} p/s` +
    ` | ${String(marginsPerSecN).padStart(6)} m/s` +
    `  ${String(stepsPerSecN).padStart(6)} p/s` +
    ` | ${speedup}x`,
  );

  return { label, density, active, elapsedA, elapsedN, stepsPerSecA, stepsPerSecN, speedup: parseFloat(speedup) };
}



// ── Run benchmarks ───────────────────────────────────────────────────────

console.log('\n╔══════════════════════════════════════════════════════════════════════╗');
console.log('║     Lucy Game — Active-Block vs O(W×H) A/B Performance Test        ║');
console.log('╠══════════════════════════════════════════════════════════════════════╣');
console.log(`║  Grid: ${W}×${H} (${W * H} cells) | 1 margin = 4 phases | ${W * H / 4} blocks/phase ║`);
console.log('╚══════════════════════════════════════════════════════════════════════╝');
console.log('');
console.log('(Both approaches run from the same initial grid for a fair comparison)');
console.log('');

const PHASES = 400;
const DENSITIES = [
  ['Sparse (0.5%)', 0.005],
  ['Low (2%)', 0.02],
  ['Medium (5%)', 0.05],
  ['Moderate (10%)', 0.10],
  ['Moderate (15%)', 0.15],
  ['Dense (25%)', 0.25],
  ['Very Dense (40%)', 0.40],
  ['Full (60%)', 0.60],
];

console.log('Density              | Cells |  Active-Block   |   O(W×H) Naive   |  Speedup');
console.log('─────────────────────┼───────┼─────────────────┼──────────────────┼──────────');

const results = [];
for (const [label, density] of DENSITIES) {
  results.push(benchmarkBoth(label, density, PHASES));
}

console.log('');

// ── Summary ──────────────────────────────────────────────────────────────

const sparse = results[0];
const dense = results[results.length - 1];

console.log('╔══════════════════════════════════════════════════════════════════╗');
console.log('║                        SPEEDUP SUMMARY                          ║');
console.log('╠══════════════════════════════════════════════════════════════════╣');
console.log(`║  Sparse (0.5%):  ${String(sparse.speedup).padStart(5)}x faster with active-block            ║`);
console.log(`║  Full (60%):     ${String(dense.speedup).padStart(5)}x (near parity — all blocks active)    ║`);
console.log('╚══════════════════════════════════════════════════════════════════╝');
console.log('');
console.log('Active-block  → O(active_cells) : only processes blocks with particles');
console.log('O(W×H) naive  → O(W×H)          : processes all 4,000 blocks every phase');
console.log('');
