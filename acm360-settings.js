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
  fastener_spacing_mm: 400,
  fastener_offset_mm: 70,
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
  fastener_offset_mm: [0, 500]
};

const clampNum = (v, lo, hi, fallback) => {
  const n = Number(v);
  return Number.isFinite(n) ? Math.min(hi, Math.max(lo, n)) : fallback;
};

const cloneJson = (obj) => JSON.parse(JSON.stringify(obj));

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
