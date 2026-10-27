// ============================================================================
// ACM360 STUDIO · CONFIGURAÇÕES (MÓDULO M12)
// Mesmo formato do plugin SketchUp (CS_ACM360::Settings / CS_ACM360_SETTINGS_V1):
// o JSON exportado de um lado pode ser importado no outro.
// No navegador fica salvo em localStorage, por usuário/máquina.
// ============================================================================

const ACM360_SETTINGS_SCHEMA = 'CS_ACM360_SETTINGS_V1';
const ACM360_SETTINGS_STORAGE_KEY = 'cs_acm360_settings';
const ACM360_LOGO_MAX_BYTES = 300 * 1024;

const ACM360_DEFAULT_SETTINGS = {
  bar_mm: 6000,
  kerf_mm: 3,
  seam_strategy: 'economia',
  color_mode: 'tipo',
  acm_sheet_w_mm: 5000,
  acm_sheet_h_mm: 1220,
  acm_core: 'PE',
  fresa_type: 'V90',
  refile_tab_mm: 15,
  default_return_mm: 50,
  default_aba_mm: 20,
  default_joint_mm: 10,
  nest_gap_mm: 8,
  nest_margin_mm: 10,
  acm_preset: 'generico_3',
  acm_presets: [
    { id: 'generico_3', name: 'Genérico 3 mm', thickness_mm: 3, bend_factor_mm: 1.5 },
    { id: 'generico_4', name: 'Genérico 4 mm', thickness_mm: 4, bend_factor_mm: 2 }
  ],
  // Fixadores (M4): cantoneira bandeja → estrutura usa spacing/offset; ancoragem e espera
  // (estrutura → parede) usam anchor_*; standoff_mm é o afastamento da espera até a parede
  fastener_spacing_mm: 400,
  fastener_offset_mm: 70,
  anchor_spacing_mm: 800,
  anchor_margin_mm: 150,
  standoff_mm: 100,
  fastener_specs: [
    { id: 'cantoneira', name: 'Cantoneira bandeja → estrutura', leg_a_mm: 25, leg_b_mm: 25, length_mm: 40, thickness_mm: 2,
      items: [{ name: 'Rebite alumínio 4,8×12', qty: 2 }, { name: 'Parafuso autobrocante 4,2×19', qty: 2 }] },
    { id: 'ancoragem', name: 'Ancoragem estrutura → parede', leg_a_mm: 50, leg_b_mm: 50, length_mm: 50, thickness_mm: 3,
      items: [{ name: 'Parafuso autobrocante 4,2×19', qty: 2 }, { name: 'Bucha S8', qty: 2 }, { name: 'Parafuso 5,5×50', qty: 2 }] },
    { id: 'espera', name: 'Espera (afastador)', leg_a_mm: 40, leg_b_mm: 50, length_mm: 50, thickness_mm: 3,
      items: [{ name: 'Parafuso autobrocante 4,2×19', qty: 2 }, { name: 'Bucha S8', qty: 2 }, { name: 'Parafuso 5,5×50', qty: 2 }] }
  ],
  tape: 'vhb_4910',
  tapes: [
    { id: 'vhb_4910', name: '3M VHB 4910 (1,1 mm)', width_mm: 19, roll_m: 33, price: 0 },
    { id: 'vhb_4941', name: '3M VHB 4941 (1,6 mm)', width_mm: 19, roll_m: 33, price: 0 },
    { id: 'vhb_4955', name: '3M VHB 4955 (2,0 mm)', width_mm: 19, roll_m: 33, price: 0 }
  ],
  custom_profiles: [],
  profile_prices: {},
  company_name: 'CS Comunicação',
  company_phone: '',
  company_email: '',
  company_logo: ''
};

const ACM360_NUMERIC_RANGES = {
  bar_mm: [1000, 12000],
  kerf_mm: [0, 15],
  acm_sheet_w_mm: [500, 10000],
  acm_sheet_h_mm: [500, 3000],
  refile_tab_mm: [0, 100],
  default_return_mm: [0, 400],
  default_aba_mm: [0, 150],
  default_joint_mm: [0, 50],
  nest_gap_mm: [0, 100],
  nest_margin_mm: [0, 200],
  fastener_spacing_mm: [100, 2000],
  fastener_offset_mm: [0, 500],
  anchor_spacing_mm: [100, 3000],
  anchor_margin_mm: [0, 1000],
  standoff_mm: [10, 500]
};

const ACM360_FASTENER_RANGES = {
  leg_a_mm: [10, 200],
  leg_b_mm: [10, 200],
  length_mm: [10, 300],
  thickness_mm: [0.5, 10]
};

const clampNum = (v, lo, hi, fallback) => {
  const n = Number(v);
  return Number.isFinite(n) ? Math.min(hi, Math.max(lo, n)) : fallback;
};

const cloneJson = (obj) => JSON.parse(JSON.stringify(obj));

// Os três tipos de fixador são fixos (cantoneira, ancoragem, espera); só as medidas e o consumo mudam
function normalizeFastenerSpecs(list, fallback) {
  const given = (Array.isArray(list) ? list : []).filter((s) => s && typeof s === 'object');
  return fallback.map((base) => {
    const s = given.find((g) => String(g.id) === base.id) || {};
    const spec = { id: base.id, name: String(s.name || '').trim() ? String(s.name) : base.name };
    Object.entries(ACM360_FASTENER_RANGES).forEach(([k, [lo, hi]]) => {
      spec[k] = clampNum(s[k], lo, hi, base[k]);
    });
    const items = s.items !== undefined ? (Array.isArray(s.items) ? s.items : []) : base.items;
    spec.items = items
      .filter((i) => i && String(i.name || '').trim())
      .map((i) => ({ name: String(i.name).trim(), qty: Math.min(100, Math.max(0, Math.trunc(Number(i.qty) || 0))) }));
    return spec;
  });
}

function normalizeAcmSettings(raw) {
  const src = raw && typeof raw === 'object' ? raw : {};
  const def = ACM360_DEFAULT_SETTINGS;
  const out = {};
  Object.keys(def).forEach((k) => {
    out[k] = src[k] !== undefined ? src[k] : cloneJson(def[k]);
  });

  Object.entries(ACM360_NUMERIC_RANGES).forEach(([k, [lo, hi]]) => {
    out[k] = clampNum(out[k], lo, hi, def[k]);
  });
  if (!['economia', 'iguais'].includes(out.seam_strategy)) out.seam_strategy = 'economia';
  if (!['tipo', 'comprimento', 'unica'].includes(out.color_mode)) out.color_mode = 'tipo';
  if (!['PE', 'FR'].includes(out.acm_core)) out.acm_core = 'PE';
  if (!['V90', 'V135', 'U'].includes(out.fresa_type)) out.fresa_type = 'V90';

  const validList = (list, fallback) => {
    const items = (Array.isArray(list) ? list : []).filter((i) => i && i.id && i.name);
    return items.length ? items : cloneJson(fallback);
  };
  out.acm_presets = validList(out.acm_presets, def.acm_presets).map((p) => ({
    id: String(p.id),
    name: String(p.name),
    thickness_mm: clampNum(p.thickness_mm, 1, 10, 3),
    bend_factor_mm: clampNum(p.bend_factor_mm, 0, 10, 1.5)
  }));
  out.tapes = validList(out.tapes, def.tapes).map((t) => ({
    id: String(t.id),
    name: String(t.name),
    width_mm: clampNum(t.width_mm, 1, 100, 19),
    roll_m: clampNum(t.roll_m, 1, 500, 33),
    price: Math.max(0, Number(t.price) || 0)
  }));
  out.fastener_specs = normalizeFastenerSpecs(out.fastener_specs, def.fastener_specs);
  if (!out.acm_presets.some((p) => p.id === out.acm_preset)) out.acm_preset = out.acm_presets[0].id;
  if (!out.tapes.some((t) => t.id === out.tape)) out.tape = out.tapes[0].id;

  out.custom_profiles = (Array.isArray(out.custom_profiles) ? out.custom_profiles : [])
    .filter((p) => p && Number(p.id) >= 100 && Number(p.w_mm) > 0 && Number(p.h_mm) > 0);
  const prices = out.profile_prices && typeof out.profile_prices === 'object' ? out.profile_prices : {};
  out.profile_prices = {};
  Object.entries(prices).forEach(([id, v]) => {
    out.profile_prices[String(id)] = Math.max(0, Number(v) || 0);
  });

  ['company_name', 'company_phone', 'company_email', 'company_logo'].forEach((k) => {
    out[k] = out[k] == null ? '' : String(out[k]);
  });
  // data URI em base64 de no máximo 300 KB
  if (out.company_logo.length > Math.ceil(ACM360_LOGO_MAX_BYTES * 4 / 3) + 64) out.company_logo = '';
  return out;
}

function loadAcmSettings() {
  try {
    const raw = globalThis.localStorage?.getItem(ACM360_SETTINGS_STORAGE_KEY);
    return normalizeAcmSettings(raw ? JSON.parse(raw) : {});
  } catch (err) {
    return normalizeAcmSettings({});
  }
}

// Retorna false quando o navegador não deixa gravar (modo privado, cota cheia)
function saveAcmSettings(settings) {
  try {
    globalThis.localStorage?.setItem(ACM360_SETTINGS_STORAGE_KEY, JSON.stringify(settings));
    return true;
  } catch (err) {
    return false;
  }
}

function exportAcmSettingsPayload(settings) {
  return { schema: ACM360_SETTINGS_SCHEMA, ...settings };
}

function importAcmSettingsPayload(data) {
  if (!data || data.schema !== ACM360_SETTINGS_SCHEMA) {
    throw new Error('Arquivo não é uma configuração CS ACM360.');
  }
  const { schema, ...rest } = data;
  return normalizeAcmSettings(rest);
}

function activeAcmPreset(settings) {
  return settings.acm_presets.find((p) => p.id === settings.acm_preset) || settings.acm_presets[0];
}

function findAcmTape(settings, id) {
  return settings.tapes.find((t) => t.id === id) || settings.tapes.find((t) => t.id === settings.tape) || settings.tapes[0];
}

if (typeof module !== 'undefined') {
  module.exports = {
    ACM360_SETTINGS_SCHEMA,
    ACM360_DEFAULT_SETTINGS,
    normalizeAcmSettings,
    exportAcmSettingsPayload,
    importAcmSettingsPayload,
    activeAcmPreset,
    findAcmTape
  };
}
