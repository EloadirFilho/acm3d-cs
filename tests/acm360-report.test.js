// Testes do módulo M8 (relatório, lista de corte e plano de barras) — rodar com: node --test tests/*.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  buildAcmReport,
  planBars,
  kgPerMeter,
  reportToCsv,
  reportToXlsx,
  reportToHtml
} = require('../sketchup-plugin/CS_ACM360_BETA/ui/acm360-report.js');

const PROFILES = [
  { id: 5, name: 'Metalon 20x40mm', family: 'metalon', w_mm: 20, h_mm: 40, wall_mm: 1.2, price_m: 10 },
  { id: 13, name: 'Alumínio 1" (25,4x25,4mm)', family: 'aluminio', w_mm: 25.4, h_mm: 25.4, wall_mm: 1.5, price_m: 0 }
];
const SETTINGS = { bar_mm: 6000, kerf_mm: 3, tape: 'vhb_4910', tapes: [{ id: 'vhb_4910', name: '3M VHB 4910', roll_m: 33, price: 50 }] };

const tube = (id, len, extra = {}) => ({
  id, name: id, profile_id: 5, profile_name: 'Metalon 20x40mm', wall_mm: 1.2,
  material: 'Aço Carbono', length_mm: len, cut_a_deg: 0, cut_b_deg: 0, ...extra
});

test('número de barras bate com o cálculo manual (serra entre os cortes)', () => {
  // 3 × 1998 + 2 cortes de 3 mm = 6000 → cabem 3 por barra
  const six = buildAcmReport({ tubes: [1, 2, 3, 4, 5, 6].map(i => tube('P' + i, 1998)) }, SETTINGS, PROFILES);
  assert.equal(six.profiles[0].bars, 2);
  // 3 × 2000 + 6 = 6006 → só 2 por barra
  const four = buildAcmReport({ tubes: [1, 2, 3, 4].map(i => tube('P' + i, 2000)) }, SETTINGS, PROFILES);
  assert.equal(four.profiles[0].bars, 2);
  const five = buildAcmReport({ tubes: [1, 2, 3, 4, 5].map(i => tube('P' + i, 2000)) }, SETTINGS, PROFILES);
  assert.equal(five.profiles[0].bars, 3);
});

test('ponta reta não ganha perda extra; 45° ganha kerf × (1/cos − 1)', () => {
  const plan = (cuts) => planBars([{ length_mm: 1000, stock_mm: 1000 + cuts }], 6000, 3);
  assert.equal(plan(0).bars[0].used_mm, 1000);
  const r = buildAcmReport({ tubes: [tube('A', 1000), tube('B', 1000, { cut_a_deg: 45, cut_b_deg: 45 })] }, SETTINGS, PROFILES);
  const used = r.profiles[0].plan[0].used_mm;
  const expected = 2000 + 2 * 3 * (1 / Math.cos(Math.PI / 4) - 1);
  assert.ok(Math.abs(used - expected) < 0.1, `${used} ≠ ${expected}`);
});

test('melhor preenchimento usa menos barras que o FFD quando o FFD erra', () => {
  // FFD: [5,4] [4,3,2] [2] = 3 barras; ótimo: [5,3,2] [4,4,2] = 2
  const pieces = [5, 4, 4, 3, 2, 2].map((m, i) => ({ id: 'X' + i, length_mm: m * 1000, stock_mm: m * 1000 }));
  const plan = planBars(pieces, 10000, 0);
  assert.equal(plan.bars_count, 2);
  assert.equal(plan.algorithm, 'Melhor preenchimento');
});

test('peças iguais viram uma linha com quantidade e corte A/B', () => {
  const r = buildAcmReport({
    tubes: [tube('M1', 1460), tube('M2', 1460), tube('C1', 1500, { cut_a_deg: 45, cut_b_deg: 45 })]
  }, SETTINGS, PROFILES);
  assert.equal(r.cut_list.length, 2);
  const m = r.cut_list.find(l => l.length_mm === 1460);
  assert.equal(m.qty, 2);
  assert.equal(m.cut, '0°/0°');
  assert.equal(r.cut_list.find(l => l.length_mm === 1500).cut, '45°/45°');
});

test('peça maior que a barra gera aviso e conta as barras necessárias', () => {
  const r = buildAcmReport({ tubes: [tube('L', 7000)] }, SETTINGS, PROFILES);
  assert.equal(r.warnings.length, 1);
  assert.match(r.warnings[0], /7000 mm é maior que a barra de 6000 mm/);
  assert.equal(r.profiles[0].bars, 2);
});

test('peso e custo por bitola', () => {
  assert.ok(Math.abs(kgPerMeter(PROFILES[0], 'Aço Carbono') - 1.0852) < 0.001);
  // Mesma bitola: alumínio (2,70) pesa ~1/3 do aço (7,85)
  assert.ok(kgPerMeter(PROFILES[0], 'Alumínio') < kgPerMeter(PROFILES[0], 'Aço Carbono') / 2.5);
  // 2 × 2990 + 3 cabem numa barra; 2 × 3000 + 3 não
  const r = buildAcmReport({ tubes: [tube('A', 2990), tube('B', 2990), tube('C', 2990)] }, SETTINGS, PROFILES);
  assert.equal(r.profiles[0].bars, 2);
  assert.equal(r.profiles[0].cost, 2 * 6 * 10);
});

test('fita VHB pelas medidas reais e quantidade das bandejas', () => {
  const r = buildAcmReport({
    trays: [{ code: 'P01', quantity: 2, front_w_mm: 1000, front_h_mm: 600, flat_w_mm: 1100, flat_h_mm: 700 }]
  }, SETTINGS, PROFILES);
  assert.equal(r.vhb.perimeter_m, 6.4);
  assert.equal(r.vhb.stiffener_m, 1);
  assert.equal(r.vhb.rolls, 1);
  assert.equal(r.vhb.cost, 50);
  assert.equal(r.totals.acm_m2, 1.54);
});

test('CSV usa ponto e vírgula, vírgula decimal e mantém acentos', () => {
  const r = buildAcmReport({ projectName: 'Fachada Ação', tubes: [tube('A', 1234.5)] }, SETTINGS, PROFILES);
  const csv = reportToCsv(r);
  assert.match(csv, /Fachada Ação/);
  assert.match(csv, /Metalon 20x40mm;Aço Carbono;1,2;1234,5;0°\/0°;1;1,23;A/);
});

test('XLSX é um zip válido com as 4 planilhas', () => {
  const r = buildAcmReport({ projectName: 'Teste <&>', tubes: [tube('A', 1000)] }, SETTINGS, PROFILES);
  const bytes = reportToXlsx(r);
  assert.equal(bytes[0], 0x50);
  assert.equal(bytes[1], 0x4B);
  const text = Buffer.from(bytes).toString('utf8');
  for (const name of ['Resumo', 'Lista de Corte', 'Plano de Barras', 'Bandejas ACM']) assert.ok(text.includes(name));
  assert.ok(text.includes('Teste &lt;&amp;&gt;'));
});

test('HTML de impressão traz o cabeçalho da empresa', () => {
  const r = buildAcmReport({ tubes: [tube('A', 1000)] }, SETTINGS, PROFILES);
  const html = reportToHtml(r, { company_name: 'CS Comunicação', company_phone: '(11) 0000-0000' });
  assert.match(html, /CS Comunicação/);
  assert.match(html, /window\.print/);
});
