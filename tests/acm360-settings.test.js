// Testes do módulo M12 (Configurações) do painel web — rodar com: node --test tests/*.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  ACM360_SETTINGS_SCHEMA,
  ACM360_DEFAULT_SETTINGS,
  normalizeAcmSettings,
  exportAcmSettingsPayload,
  importAcmSettingsPayload,
  activeAcmPreset,
  findAcmTape
} = require('../acm360-settings.js');

test('configuração vazia volta ao padrão de fábrica', () => {
  const s = normalizeAcmSettings({});
  assert.deepEqual(s, ACM360_DEFAULT_SETTINGS);
});

test('barra de 6500 mm é mantida e valores fora da faixa são limitados', () => {
  const s = normalizeAcmSettings({ bar_mm: 6500, kerf_mm: 99, acm_sheet_w_mm: 'abc' });
  assert.equal(s.bar_mm, 6500);
  assert.equal(s.kerf_mm, 15);
  assert.equal(s.acm_sheet_w_mm, ACM360_DEFAULT_SETTINGS.acm_sheet_w_mm);
});

test('opções desconhecidas voltam ao padrão', () => {
  const s = normalizeAcmSettings({ seam_strategy: 'x', fresa_type: 'Z', acm_core: 'ABC', color_mode: 1 });
  assert.equal(s.seam_strategy, 'economia');
  assert.equal(s.fresa_type, 'V90');
  assert.equal(s.acm_core, 'PE');
  assert.equal(s.color_mode, 'tipo');
});

test('fator de dobra por fornecedor e chapa ativa', () => {
  const s = normalizeAcmSettings({
    acm_preset: 'alu_4',
    acm_presets: [
      { id: 'alu_3', name: 'Fornecedor A 3 mm', thickness_mm: 3, bend_factor_mm: 1.4 },
      { id: 'alu_4', name: 'Fornecedor A 4 mm', thickness_mm: 4, bend_factor_mm: 2.1 }
    ]
  });
  assert.equal(activeAcmPreset(s).bend_factor_mm, 2.1);
  assert.equal(activeAcmPreset(s).thickness_mm, 4);
});

test('chapa ativa inexistente cai na primeira da lista', () => {
  const s = normalizeAcmSettings({
    acm_preset: 'apagada',
    acm_presets: [{ id: 'b', name: 'B', thickness_mm: 3, bend_factor_mm: 1.6 }]
  });
  assert.equal(s.acm_preset, 'b');
});

test('lista de fitas vazia ou inválida volta ao padrão', () => {
  const s = normalizeAcmSettings({ tapes: [{ name: 'sem id' }], tape: 'x' });
  assert.deepEqual(s.tapes, ACM360_DEFAULT_SETTINGS.tapes);
  assert.equal(s.tape, 'vhb_4910');
  assert.equal(findAcmTape(s, 'vhb_4955').name, '3M VHB 4955 (2,0 mm)');
  assert.equal(findAcmTape(s, 'nao-existe').id, 'vhb_4910');
});

test('bitola própria precisa de id >= 100 e medidas positivas', () => {
  const s = normalizeAcmSettings({
    custom_profiles: [
      { id: 100, code: 'X100', name: 'Metalon 60x40', w_mm: 60, h_mm: 40, wall_mm: 1.5 },
      { id: 5, code: 'conflito', name: 'id do catálogo', w_mm: 20, h_mm: 40 },
      { id: 101, code: 'X101', name: 'sem medida', w_mm: 0, h_mm: 40 }
    ],
    profile_prices: { 5: '12.5', 100: -3 }
  });
  assert.equal(s.custom_profiles.length, 1);
  assert.equal(s.custom_profiles[0].id, 100);
  assert.deepEqual(s.profile_prices, { 5: 12.5, 100: 0 });
});

test('logo maior que 300 KB é descartado', () => {
  const big = 'data:image/png;base64,' + 'A'.repeat(500 * 1024);
  assert.equal(normalizeAcmSettings({ company_logo: big }).company_logo, '');
  const small = 'data:image/png;base64,AAAA';
  assert.equal(normalizeAcmSettings({ company_logo: small }).company_logo, small);
});

test('exportar e importar preserva a configuração (mesmo formato do plugin)', () => {
  const s = normalizeAcmSettings({ bar_mm: 6500, company_name: 'CS Fachadas' });
  const payload = exportAcmSettingsPayload(s);
  assert.equal(payload.schema, ACM360_SETTINGS_SCHEMA);
  const back = importAcmSettingsPayload(JSON.parse(JSON.stringify(payload)));
  assert.deepEqual(back, s);
});

test('importar arquivo sem schema é recusado', () => {
  assert.throws(() => importAcmSettingsPayload({ bar_mm: 6000 }), /não é uma configuração/);
  assert.throws(() => importAcmSettingsPayload(null), /não é uma configuração/);
});
