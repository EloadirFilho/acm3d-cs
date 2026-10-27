// Testes do módulo M4 (fixadores: posições e consumo) — rodar com: node --test tests/*.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const { fastenerPositions, estimateFasteners } = require('../sketchup-plugin/CS_ACM360_BETA/ui/acm360-report.js');
const { ACM360_DEFAULT_SETTINGS, normalizeAcmSettings } = require('../acm360-settings.js');

const S = normalizeAcmSettings({});
const DOBRA = { type: 'dobra', return_mm: 50 };

test('posições: margem nas pontas e passo nunca maior que o espaçamento', () => {
  // 1200 com margem 70: útil 1060 -> floor(1060/400)+1 = 3 pontos, passo 530
  assert.deepEqual(fastenerPositions(1200, 400, 70), [70, 600, 1130]);
  // sempre pelo menos 2 quando cabe a margem
  assert.deepEqual(fastenerPositions(300, 400, 70), [70, 230]);
  // peça menor que as duas margens: um só, no meio
  assert.deepEqual(fastenerPositions(100, 400, 70), [50]);
  assert.deepEqual(fastenerPositions(0, 400, 70), []);
});

test('cantoneiras só nas bordas com dobra e retorno maior que a espessura', () => {
  const r = estimateFasteners({
    trays: [{ w_mm: 1200, h_mm: 800, quantity: 2, edges: { inf: DOBRA, sup: DOBRA, esq: { type: 'refile', return_mm: 50 }, dir: { type: 'dobra', return_mm: 1 } } }]
  }, S);
  // inf e sup: 3 cada; esq refile e dir com retorno de 1 mm ficam de fora
  assert.equal(r.cantoneiras, 12);
  assert.equal(r.pieces['Cantoneira L25x25x2 c40'], 12);
  assert.equal(r.items['Rebite alumínio 4,8×12'], 24);
  assert.equal(r.anchors, 0);
});

test('ancoragem nos tubos verticais; espera soma o afastamento e limita a aba ao tubo', () => {
  const tubes = [
    { axis: 'z', length_mm: 3000, d_mm: 40 },
    { axis: 'z', length_mm: 3000, d_mm: 40 },
    { axis: 'x', length_mm: 2000, d_mm: 40 }
  ];
  const a = estimateFasteners({ tubes, wall: 'ancoragem' }, S);
  // útil 2700 / 800 -> 4 por tubo vertical; o horizontal não recebe
  assert.equal(a.anchors, 8);
  assert.equal(a.pieces['Ancoragem L40x50x3 c50'], 8); // aba 50 limitada aos 40 do tubo
  assert.equal(a.items['Bucha S8'], 16);

  const e = estimateFasteners({ tubes, wall: 'espera' }, S);
  assert.equal(e.pieces['Espera L140x50x3 c50'], 8); // 40 + 100 de afastamento
});

test('estrutura sem verticais usa os horizontais', () => {
  const r = estimateFasteners({ tubes: [{ axis: 'x', length_mm: 2000, d_mm: 50 }], wall: 'ancoragem' }, S);
  assert.equal(r.anchors, 3);
});

test('configuração: três fixadores fixos, medidas limitadas e consumo editável', () => {
  const cfg = normalizeAcmSettings({
    fastener_specs: [
      { id: 'cantoneira', name: '', leg_a_mm: 999, items: [{ name: 'Rebite', qty: 4 }, { name: '', qty: 2 }] },
      { id: 'inventado', name: 'X' }
    ],
    standoff_mm: 5
  });
  assert.deepEqual(cfg.fastener_specs.map((s) => s.id), ['cantoneira', 'ancoragem', 'espera']);
  assert.equal(cfg.fastener_specs[0].name, ACM360_DEFAULT_SETTINGS.fastener_specs[0].name);
  assert.equal(cfg.fastener_specs[0].leg_a_mm, 200);
  assert.deepEqual(cfg.fastener_specs[0].items, [{ name: 'Rebite', qty: 4 }]);
  assert.deepEqual(cfg.fastener_specs[1], ACM360_DEFAULT_SETTINGS.fastener_specs[1]);
  assert.equal(cfg.standoff_mm, 10);
});
