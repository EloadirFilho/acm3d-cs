'use strict';

// ============================================================================
// DADOS REALISTAS — CS FACHADAS (ERP CHÃO DE FÁBRICA)
// ============================================================================

const OPERATORS = [
  { id: 'op-pedro', name: 'Pedro Almeida', short: 'Eu mesmo (Pedro)', initials: 'PE', role: 'Líder de Produção', canAssignOthers: true, sectors: 'todos os setores', pin: '1234' },
  { id: 'op-adenilson', name: 'Adenilson Barbosa', short: 'Adenilson Barbosa', initials: 'AB', role: 'Instalação / Montagem', canAssignOthers: false, sectors: 'Instalação, Montagem, Expedição', pin: '2211' },
  { id: 'op-daphne', name: 'Daphne Avelino', short: 'Daphne Avelino', initials: 'DA', role: 'Impressão / Acabamento', canAssignOthers: false, sectors: 'Impressão, Acabamento de impressos', pin: '3311' },
  { id: 'op-jeremias', name: 'Jeremias de Souza', short: 'Jeremias de Souza', initials: 'JS', role: 'Serralheria / Estruturas', canAssignOthers: false, sectors: 'Serralheria, Montagem', pin: '4411' },
  { id: 'op-joenes', name: 'Joenes de Oliveira', short: 'Joenes de Oliveira', initials: 'JO', role: 'CNC Router / Letras Caixa', canAssignOthers: false, sectors: 'CNC, Letras caixa', pin: '5511' },
  { id: 'op-rafael', name: 'Rafael de Castro', short: 'Rafael de Castro', initials: 'RC', role: 'Pintura Automotiva', canAssignOthers: false, sectors: 'Pintura, Acabamento', pin: '6611' }
];

const SECTORS = [
  { id: 'Todos', label: 'Todos', icon: '⚡' },
  { id: 'Criação/Projetos', label: 'Criação/Projetos', icon: '✏️' },
  { id: 'Arquivos', label: 'Arquivos', icon: '📁' },
  { id: 'Impressão', label: 'Impressão', icon: '🖨️' },
  { id: 'Acabamento de impressos', label: 'Acabamento de impressos', icon: '🥞' },
  { id: 'CNC', label: 'CNC', icon: '🧩' },
  { id: 'Serralheria', label: 'Serralheria', icon: '⚙️' },
  { id: 'Letras caixa', label: 'Letras caixa', icon: '🔤' },
  { id: 'Pintura', label: 'Pintura', icon: '🔫' },
  { id: 'Montagem', label: 'Montagem', icon: '🔩' },
  { id: 'Expedição', label: 'Expedição', icon: '📦' },
  { id: 'Instalação', label: 'Instalação', icon: '🚚' }
];

const OS_LIST = [
  {
    id: 'OS-39',
    client: 'Cliente Balcão',
    title: 'Banner — Até 1 metro de largura, Lona Front 440g',
    dimensions: '1,00 × 2,00 m',
    qty: '1 un',
    deadline: '19/10/26',
    tag: 'banner',
    isLate: true,
    sector: 'Instalação',
    state: 'queue', // 'running' | 'queue' | 'incoming'
    assignedTo: [],
    elapsedSeconds: 0,
    isPaused: false,
    pauseReason: '',
    obs: 'Conferir ilhós reforçado a cada 30cm nas pontas superiores. Cliente retira ou instalação rápida na fachada.',
    croquiType: 'banner',
    stages: [
      { name: 'Arquivos', status: 'done', by: 'Pedro Almeida', duration: '12 min' },
      { name: 'Impressão', status: 'done', by: 'Daphne Avelino', duration: '28 min' },
      { name: 'Acabamento de impressos', status: 'done', by: 'Daphne Avelino', duration: '19 min' },
      { name: 'Expedição', status: 'done', by: 'Adenilson Barbosa', duration: '08 min' },
      { name: 'Instalação', status: 'current', by: '—', duration: '—' }
    ],
    materials: [
      { matId: 'mat-lona-440', name: 'Lona Frontlight 440g Brilho', predicted: 2.0, used: 2.0, unit: 'm²' },
      { matId: 'mat-adesivo-avery', name: 'Adesivo Avery® Branco Brilho', predicted: 0.4, used: 0.0, unit: 'm²' }
    ]
  },
  {
    id: 'OS-36',
    client: 'CS Comunicação Visual',
    title: 'Fachada ACM Preto + Letra Caixa Acrílico c/ LED',
    dimensions: '4,50 × 1,20 m',
    qty: '1 conj',
    deadline: '20/10/26',
    tag: 'fachada acm',
    isLate: false,
    sector: 'CNC',
    state: 'running',
    assignedTo: ['Joenes de Oliveira', 'Pedro Almeida'],
    elapsedSeconds: 1425,
    isPaused: false,
    pauseReason: '',
    obs: 'Usinar vinco para dobra de bandeja ACM com fresa V 90°. Letras caixa com face em acrílico branco leitoso 3mm.',
    croquiType: 'fachada',
    stages: [
      { name: 'Criação/Projetos', status: 'done', by: 'Pedro Almeida', duration: '1h 15m' },
      { name: 'Arquivos', status: 'done', by: 'Pedro Almeida', duration: '25 min' },
      { name: 'CNC', status: 'current', by: 'Joenes + Pedro', duration: 'Em andamento' },
      { name: 'Serralheria', status: 'todo', by: '—', duration: '—' },
      { name: 'Letras caixa', status: 'todo', by: '—', duration: '—' },
      { name: 'Montagem', status: 'todo', by: '—', duration: '—' },
      { name: 'Instalação', status: 'todo', by: '—', duration: '—' }
    ],
    materials: [
      { matId: 'mat-adesivo-avery', name: 'Adesivo Avery® Branco Brilho', predicted: 0.53, used: 0.0, unit: 'm²' },
      { matId: 'mat-metalon-20', name: 'Metalon 20x20 #18', predicted: 18.0, used: 6.0, unit: 'ml' },
      { matId: 'mat-led-12v', name: 'Módulo LED 12V Branco Frio IP67', predicted: 45, used: 0, unit: 'un' }
    ]
  },
  {
    id: 'OS-41',
    client: 'Padaria Pão Dourado',
    title: 'Totem Dupla Face Estruturado + Quadro Metalon',
    dimensions: '1,20 × 3,00 m',
    qty: '1 un',
    deadline: '19/10/26',
    tag: 'totem externo',
    isLate: true,
    sector: 'Serralheria',
    state: 'running',
    assignedTo: ['Jeremias de Souza'],
    elapsedSeconds: 2690,
    isPaused: false,
    pauseReason: '',
    obs: 'Base com sapata chumbadora 30x30cm. Aplicar fundo anticorrosivo nas soldas antes de liberar para Pintura.',
    croquiType: 'totem',
    stages: [
      { name: 'Arquivos', status: 'done', by: 'Pedro Almeida', duration: '30 min' },
      { name: 'Serralheria', status: 'current', by: 'Jeremias de Souza', duration: 'Em andamento' },
      { name: 'Pintura', status: 'todo', by: '—', duration: '—' },
      { name: 'Montagem', status: 'todo', by: '—', duration: '—' },
      { name: 'Instalação', status: 'todo', by: '—', duration: '—' }
    ],
    materials: [
      { matId: 'mat-metalon-20', name: 'Metalon 20x20 #18', predicted: 24.0, used: 12.0, unit: 'ml' },
      { matId: 'mat-primer-pu', name: 'Primer PU Cinza Automotivo', predicted: 1.5, used: 0.0, unit: 'L' }
    ]
  },
  {
    id: 'OS-44',
    client: 'Ótica Visão Clara',
    title: 'Painel Vitrine Interna em Adesivo Avery® + Laminação',
    dimensions: '2,40 × 1,20 m',
    qty: '2 un',
    deadline: '20/10/26',
    tag: 'adesivo vitrine',
    isLate: false,
    sector: 'Impressão',
    state: 'queue',
    assignedTo: [],
    elapsedSeconds: 0,
    isPaused: false,
    pauseReason: '',
    obs: 'Imprimir em alta resolução (1440dpi). Deixar sangria de 2cm em todos os lados para aplicação.',
    croquiType: 'banner',
    stages: [
      { name: 'Criação/Projetos', status: 'done', by: 'Pedro Almeida', duration: '45 min' },
      { name: 'Arquivos', status: 'done', by: 'Pedro Almeida', duration: '15 min' },
      { name: 'Impressão', status: 'current', by: '—', duration: '—' },
      { name: 'Acabamento de impressos', status: 'todo', by: '—', duration: '—' },
      { name: 'Instalação', status: 'todo', by: '—', duration: '—' }
    ],
    materials: [
      { matId: 'mat-adesivo-avery', name: 'Adesivo Avery® Branco Brilho', predicted: 5.76, used: 0.0, unit: 'm²' }
    ]
  },
  {
    id: 'OS-39-ACAB',
    osDisplayCode: 'OS-39',
    client: 'Cliente Balcão',
    title: 'Banner — Até 1 metro de largura, Lona Front 440g',
    dimensions: '1,00 × 2,00 m',
    qty: '1 un',
    deadline: '19/10/26',
    tag: 'banner',
    isLate: true,
    sector: 'Acabamento de impressos',
    currentLocationLabel: 'agora em Instalação',
    state: 'incoming',
    assignedTo: [],
    elapsedSeconds: 0,
    isPaused: false,
    pauseReason: '',
    obs: 'Reforço de bainha extra solicitado pelo balcão.',
    croquiType: 'banner',
    stages: [
      { name: 'Impressão', status: 'done', by: 'Daphne Avelino', duration: '28 min' },
      { name: 'Acabamento de impressos', status: 'current', by: '—', duration: '—' },
      { name: 'Instalação', status: 'todo', by: '—', duration: '—' }
    ],
    materials: [
      { matId: 'mat-lona-440', name: 'Lona Frontlight 440g Brilho', predicted: 2.0, used: 2.0, unit: 'm²' }
    ]
  },
  {
    id: 'OS-47',
    client: 'Auto Posto Estrela',
    title: 'Testeira de Pista em ACM Vermelho + Quadro Metalon',
    dimensions: '8,00 × 0,90 m',
    qty: '1 conj',
    deadline: '21/10/26',
    tag: 'testeira posto',
    isLate: false,
    sector: 'Serralheria',
    currentLocationLabel: 'agora em CNC',
    state: 'incoming',
    assignedTo: [],
    elapsedSeconds: 0,
    isPaused: false,
    pauseReason: '',
    obs: 'Dá para adiantar os quadros modulares de 2,00 × 0,90 m em Metalon 20x20 enquanto o CNC corta o ACM.',
    croquiType: 'fachada',
    stages: [
      { name: 'Arquivos', status: 'done', by: 'Pedro Almeida', duration: '40 min' },
      { name: 'CNC', status: 'current', by: 'Joenes de Oliveira', duration: 'Em andamento' },
      { name: 'Serralheria', status: 'todo', by: '—', duration: '—' },
      { name: 'Montagem', status: 'todo', by: '—', duration: '—' },
      { name: 'Instalação', status: 'todo', by: '—', duration: '—' }
    ],
    materials: [
      { matId: 'mat-metalon-20', name: 'Metalon 20x20 #18', predicted: 36.0, used: 0.0, unit: 'ml' }
    ]
  }
];

const MATERIALS_CATALOG = [
  {
    id: 'mat-adesivo-avery',
    name: 'Adesivo Avery® Branco Brilho',
    category: 'Lonas & Adesivos',
    stock: 38,
    unit: 'm²',
    supportsDimCalc: true,
    presets: [
      { label: '+1,00 m²', value: 1.0 },
      { label: '+2,50 m²', value: 2.5 }
    ]
  },
  {
    id: 'mat-metalon-20',
    name: 'Metalon 20x20 #18',
    category: 'Serralheria',
    stock: -59,
    unit: 'ml',
    supportsDimCalc: false,
    presets: [
      { label: '1 Barra (6m)', value: 6 },
      { label: '1/2 Barra (3m)', value: 3 },
      { label: '2 Barras (12m)', value: 12 }
    ]
  },
  {
    id: 'mat-lona-440',
    name: 'Lona Frontlight 440g Brilho',
    category: 'Lonas & Adesivos',
    stock: 112,
    unit: 'm²',
    supportsDimCalc: true,
    presets: [
      { label: '+2,00 m²', value: 2.0 },
      { label: '+5,00 m²', value: 5.0 }
    ]
  },
  {
    id: 'mat-led-12v',
    name: 'Módulo LED 12V Branco Frio IP67',
    category: 'Elétrica & LED',
    stock: 340,
    unit: 'un',
    supportsDimCalc: false,
    presets: [
      { label: '+10 un', value: 10 },
      { label: '+20 un', value: 20 },
      { label: '+50 un', value: 50 }
    ]
  },
  {
    id: 'mat-fonte-12v',
    name: 'Fonte Chaveada Slim 12V 15A',
    category: 'Elétrica & LED',
    stock: 14,
    unit: 'un',
    supportsDimCalc: false,
    presets: [
      { label: '1 un', value: 1 },
      { label: '2 un', value: 2 }
    ]
  },
  {
    id: 'mat-primer-pu',
    name: 'Primer PU Cinza Automotivo',
    category: 'Pintura & Química',
    stock: 8.5,
    unit: 'L',
    supportsDimCalc: false,
    presets: [
      { label: '0,5 L', value: 0.5 },
      { label: '1,0 L', value: 1.0 }
    ]
  }
];

const SHEETS_INVENTORY = [
  {
    id: 'CH-4',
    type: 'ACM',
    kind: 'sobra',
    widthCm: 100,
    heightCm: 50,
    freeAreaM2: 0.50,
    cuts: []
  },
  {
    id: 'CH-3',
    type: 'ACM',
    kind: 'sobra',
    widthCm: 500,
    heightCm: 150,
    freeAreaM2: 5.79,
    cuts: [
      { xPct: 0, yPct: 0, wPct: 18, hPct: 82 },
      { xPct: 18, yPct: 0, wPct: 7, hPct: 28 },
      { xPct: 18, yPct: 28, wPct: 7, hPct: 28 },
      { xPct: 18, yPct: 56, wPct: 7, hPct: 28 },
      { xPct: 18, yPct: 84, wPct: 7, hPct: 16 }
    ]
  },
  {
    id: 'CH-2',
    type: 'ACM',
    kind: 'inteira',
    widthCm: 122,
    heightCm: 244,
    freeAreaM2: 2.98,
    cuts: []
  },
  {
    id: 'CH-7',
    type: 'Acrílico',
    kind: 'sobra',
    widthCm: 90,
    heightCm: 60,
    freeAreaM2: 0.54,
    cuts: []
  },
  {
    id: 'CH-6',
    type: 'Acrílico',
    kind: 'inteira',
    widthCm: 122,
    heightCm: 244,
    freeAreaM2: 2.98,
    cuts: []
  },
  {
    id: 'CH-5',
    type: 'PVC Expandido',
    kind: 'sobra',
    widthCm: 120,
    heightCm: 80,
    freeAreaM2: 0.96,
    cuts: []
  },
  {
    id: 'CH-9',
    type: 'MDF',
    kind: 'inteira',
    widthCm: 185,
    heightCm: 275,
    freeAreaM2: 5.09,
    cuts: []
  },
  {
    id: 'CH-10',
    type: 'Galvanizada',
    kind: 'inteira',
    widthCm: 120,
    heightCm: 300,
    freeAreaM2: 3.60,
    cuts: []
  }
];

const SHEET_TYPES = ['ACM', 'Acrílico', 'PVC Expandido', 'MDF', 'Galvanizada'];

// ============================================================================
// ESTADO DA APLICAÇÃO
// ============================================================================

const state = {
  currentOperatorId: 'op-pedro',
  activeView: 'os', // 'os' | 'material' | 'chapas'
  selectedSector: 'Todos',
  showZeroSectors: false,
  inactivitySeconds: 60,

  // Modal state
  pendingAssignOsId: null,
  activeDetailsOsId: null,
  pendingFinishOsId: null,

  // Material state
  materialSearch: '',
  materialCategory: 'Sugeridos OS',
  selectedMaterialId: 'mat-adesivo-avery',
  materialCalcMode: 'direct', // 'direct' | 'dimensions'
  materialQtyStr: '0',
  materialDimFocus: 'w', // 'w' | 'h'
  materialDimW: '100',
  materialDimH: '53',
  selectedMaterialWorkTarget: 'OS-36',

  // Chapas state
  chapaSubmode: 'cut', // 'cut' | 'register'
  selectedSheetType: 'ACM',
  selectedSheetId: 'CH-4',
  chapaFocusField: 'w', // 'w' | 'h'
  chapaWStr: '',
  chapaHStr: '',
  selectedChapaWorkTarget: 'Sem OS',

  // PIN Lock state
  pinLocked: false,
  pinTargetOperatorId: 'op-pedro',
  pinInput: ''
};

// ============================================================================
// INICIALIZAÇÃO & FALLBACK DE DIALOG (MODERN WEB GUIDANCE)
// ============================================================================

function initDialogLightDismissFallback() {
  document.querySelectorAll('dialog[closedby="any"]').forEach((dialog) => {
    if (!('closedBy' in HTMLDialogElement.prototype)) {
      dialog.addEventListener('click', (event) => {
        if (event.target !== dialog) return;
        const rect = dialog.getBoundingClientRect();
        const isDialogContent = (
          rect.top <= event.clientY &&
          event.clientY <= rect.top + rect.height &&
          rect.left <= event.clientX &&
          event.clientX <= rect.left + rect.width
        );
        if (isDialogContent) return;
        dialog.close();
      });
    }
  });

  document.querySelectorAll('[data-close-dialog]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const dlg = document.getElementById(btn.getAttribute('data-close-dialog'));
      if (dlg) dlg.close();
    });
  });
}

// ============================================================================
// UTILITÁRIOS VISUAIS (CROQUIS SVG, FORMATADORES, TOAST)
// ============================================================================

function formatDuration(totalSec) {
  const hrs = Math.floor(totalSec / 3600);
  const mins = Math.floor((totalSec % 3600) / 60);
  const secs = totalSec % 60;
  const pad = (n) => String(n).padStart(2, '0');
  return `${pad(hrs)}:${pad(mins)}:${pad(secs)}`;
}

function formatNumberBR(num) {
  return Number(num).toLocaleString('pt-BR', { maximumFractionDigits: 2 });
}

let toastTimeout = null;
function showToast(message) {
  const toast = document.getElementById('totemToast');
  toast.textContent = message;
  toast.hidden = false;
  clearTimeout(toastTimeout);
  toastTimeout = setTimeout(() => {
    toast.hidden = true;
  }, 3800);
}

function renderCroquiSvg(type, dimensions, isLarge = false) {
  const w = isLarge ? 320 : 58;
  const h = isLarge ? 175 : 38;
  if (type === 'fachada') {
    return `
      <svg role="img" viewBox="0 0 320 175" width="${w}" height="${h}" class="${isLarge ? '' : 'croqui-mini-svg'}">
        <title>Croqui Técnico da Fachada (${dimensions})</title>
        <rect x="16" y="26" width="288" height="105" fill="#18181b" stroke="#f87171" stroke-width="3" rx="4"/>
        <line x1="112" y1="26" x2="112" y2="131" stroke="#3f3f46" stroke-dasharray="4 4" stroke-width="1.5"/>
        <line x1="208" y1="26" x2="208" y2="131" stroke="#3f3f46" stroke-dasharray="4 4" stroke-width="1.5"/>
        <text x="160" y="78" text-anchor="middle" fill="#ffffff" font-family="sans-serif" font-weight="800" font-size="22">CS FACHADAS</text>
        <text x="160" y="102" text-anchor="middle" fill="#38bdf8" font-family="monospace" font-size="12">LETRA CAIXA ACRÍLICO + LED</text>
        <text x="160" y="156" text-anchor="middle" fill="#fde047" font-family="monospace" font-weight="700" font-size="14">↔ ${dimensions}</text>
      </svg>
    `;
  }
  if (type === 'totem') {
    return `
      <svg role="img" viewBox="0 0 320 175" width="${w}" height="${h}" class="${isLarge ? '' : 'croqui-mini-svg'}">
        <title>Croqui Técnico do Totem (${dimensions})</title>
        <rect x="115" y="14" width="90" height="135" fill="#1e293b" stroke="#38bdf8" stroke-width="3" rx="3"/>
        <line x1="115" y1="58" x2="205" y2="58" stroke="#64748b" stroke-width="1.5"/>
        <line x1="115" y1="104" x2="205" y2="104" stroke="#64748b" stroke-width="1.5"/>
        <rect x="95" y="149" width="130" height="10" fill="#94a3b8"/>
        <text x="160" y="42" text-anchor="middle" fill="#fde047" font-family="sans-serif" font-weight="800" font-size="13">TOTEM ACM</text>
        <text x="255" y="88" text-anchor="middle" fill="#fde047" font-family="monospace" font-weight="700" font-size="13">${dimensions}</text>
      </svg>
    `;
  }
  return `
    <svg role="img" viewBox="0 0 320 175" width="${w}" height="${h}" class="${isLarge ? '' : 'croqui-mini-svg'}">
      <title>Croqui Técnico de Impressão (${dimensions})</title>
      <rect x="35" y="24" width="250" height="110" fill="#ffffff" stroke="#ef4444" stroke-width="3" rx="3"/>
      <circle cx="48" cy="36" r="4" fill="#dc2626"/>
      <circle cx="272" cy="36" r="4" fill="#dc2626"/>
      <circle cx="48" cy="122" r="4" fill="#dc2626"/>
      <circle cx="272" cy="122" r="4" fill="#dc2626"/>
      <text x="160" y="75" text-anchor="middle" fill="#111827" font-family="sans-serif" font-weight="800" font-size="18">IMPRESSÃO DIGITAL</text>
      <text x="160" y="98" text-anchor="middle" fill="#dc2626" font-family="monospace" font-weight="700" font-size="12">ILHÓS REFORÇADO NAS PONTAS</text>
      <text x="160" y="158" text-anchor="middle" fill="#fde047" font-family="monospace" font-weight="700" font-size="14">↔ ${dimensions}</text>
    </svg>
  `;
}

// ============================================================================
// CABEÇALHO, NAVEGAÇÃO E BARRA DE SETORES
// ============================================================================

function renderHeader() {
  const op = OPERATORS.find((o) => o.id === state.currentOperatorId) || OPERATORS[0];
  document.getElementById('headerOpAvatar').textContent = op.initials;
  document.getElementById('headerOpName').textContent = `OLÁ, ${op.name.split(' ')[0].toUpperCase()}`;
  const badge = document.getElementById('headerOpBadge');
  badge.hidden = !op.canAssignOthers;
  document.getElementById('headerOpSectors').textContent = `Seus setores: ${op.sectors}`;

  // Badges de contagem nas abas principais
  document.getElementById('badgeTotalOS').textContent = String(OS_LIST.length);

  // Quantos materiais têm previsão pendente nas OS em fila/execução
  let pendingMats = 0;
  OS_LIST.forEach((os) => {
    os.materials.forEach((m) => {
      if (m.used < m.predicted) pendingMats += 1;
    });
  });
  document.getElementById('badgeSuggestedMat').textContent = String(pendingMats);

  // Atualizar estado dos botões de navegação
  document.querySelectorAll('[data-nav-view]').forEach((btn) => {
    const v = btn.getAttribute('data-nav-view');
    if (v === state.activeView) {
      btn.setAttribute('aria-current', 'page');
    } else {
      btn.removeAttribute('aria-current');
    }
  });

  document.getElementById('viewOS').hidden = state.activeView !== 'os';
  document.getElementById('viewMaterial').hidden = state.activeView !== 'material';
  document.getElementById('viewChapas').hidden = state.activeView !== 'chapas';
  const elAcm = document.getElementById('viewAcm360');
  if (elAcm) elAcm.hidden = state.activeView !== 'acm360';
}

function getSectorCounts() {
  const counts = {};
  const urgent = {};
  SECTORS.forEach((s) => {
    counts[s.id] = 0;
    urgent[s.id] = false;
  });

  OS_LIST.forEach((os) => {
    counts['Todos'] += 1;
    if (os.isLate) urgent['Todos'] = true;
    if (counts[os.sector] !== undefined) {
      counts[os.sector] += 1;
      if (os.isLate) urgent[os.sector] = true;
    }
  });
  return { counts, urgent };
}

function renderSectorBar() {
  const container = document.getElementById('sectorPillsContainer');
  const { counts, urgent } = getSectorCounts();

  const visibleSectors = SECTORS.filter((s) => {
    if (s.id === 'Todos' || s.id === state.selectedSector) return true;
    if (state.showZeroSectors) return true;
    return counts[s.id] > 0;
  });

  container.innerHTML = visibleSectors
    .map((sec) => {
      const c = counts[sec.id] || 0;
      const isPressed = state.selectedSector === sec.id;
      const isZero = c === 0;
      const hasUrgent = urgent[sec.id];
      return `
        <button
          type="button"
          class="sector-pill"
          data-sector-id="${sec.id}"
          aria-pressed="${isPressed}"
          data-zero="${isZero}"
          data-has-urgent="${hasUrgent}"
        >
          <span aria-hidden="true">${sec.icon}</span>
          <span>${sec.label}</span>
          <span class="sector-count">${c}</span>
        </button>
      `;
    })
    .join('');

  container.querySelectorAll('[data-sector-id]').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.selectedSector = btn.getAttribute('data-sector-id');
      renderSectorBar();
      renderOSBoard();
    });
  });

  const toggleBtn = document.getElementById('btnToggleZeroSectors');
  toggleBtn.setAttribute('aria-pressed', String(state.showZeroSectors));
  toggleBtn.textContent = state.showZeroSectors
    ? 'Ocultar setores vazios (0)'
    : 'Mostrar setores vazios (0)';
}

// ============================================================================
// QUADRO DE ORDENS DE SERVIÇO (3 COLUNAS: EM EXECUÇÃO | FILA | A CAMINHO)
// ============================================================================

function renderOSBoard() {
  const filtered = OS_LIST.filter((os) => {
    if (state.selectedSector === 'Todos') return true;
    return os.sector === state.selectedSector;
  });

  const activeList = filtered.filter((o) => o.state === 'running');
  const queueList = filtered.filter((o) => o.state === 'queue');
  const incomingList = filtered.filter((o) => o.state === 'incoming');

  document.getElementById('countActiveOS').textContent = String(activeList.length);
  document.getElementById('countQueueOS').textContent = String(queueList.length);
  document.getElementById('countIncomingOS').textContent = String(incomingList.length);

  // 1. Renderizar Coluna EM EXECUÇÃO AGORA
  const elActive = document.getElementById('listActiveOS');
  if (activeList.length === 0) {
    elActive.innerHTML = `
      <div style="padding: 24px 14px; text-align: center; color: var(--text-muted); font-size: 0.88rem;">
        Nenhum trabalho iniciado neste setor.<br>Toque em <strong>PEGUEI</strong> na coluna ao lado para começar.
      </div>
    `;
  } else {
    elActive.innerHTML = activeList
      .map((os) => {
        const displayCode = os.osDisplayCode || os.id;
        return `
          <article class="os-card ${os.isPaused ? 'is-paused' : 'is-running'}" data-os-card="${os.id}">
            <div class="os-card-top">
              <span class="os-id-group">🛠️ ${displayCode} · ${os.sector}</span>
              <span class="status-pill ${os.isPaused ? 'paused' : 'running'}">
                ${os.isPaused ? `⏸ PAUSADO (${os.pauseReason})` : '● PRODUZINDO'}
              </span>
            </div>

            <div>
              <h3 class="os-client-name">${os.client}</h3>
              <p class="os-product-desc">${os.title}</p>
              <div class="os-specs-line">
                <span class="spec-measure-badge">${os.dimensions}</span>
                <span>· ${os.qty} · prazo ${os.deadline}</span>
              </div>
            </div>

            <div class="running-timer-box">
              <div>
                <span style="font-size:0.7rem; color:var(--text-secondary); font-weight:700; text-transform:uppercase;">Equipe na OS:</span>
                <div class="team-assigned-list">👷 ${os.assignedTo.join(' + ')}</div>
              </div>
              <span class="live-timer" data-live-timer="${os.id}">${formatDuration(os.elapsedSeconds)}</span>
            </div>

            <button type="button" class="croqui-thumb-btn" data-open-details="${os.id}">
              ${renderCroquiSvg(os.croquiType, os.dimensions, false)}
              <span class="croqui-thumb-meta">
                <span class="croqui-thumb-title">Ver croqui, materiais (${os.materials.length}) e observações</span>
                <span class="croqui-thumb-sub">${os.obs}</span>
              </span>
            </button>

            <div class="running-actions">
              <button type="button" class="btn-finish-os" data-finish-os="${os.id}">
                ✓ FINALIZEI
              </button>
              <button type="button" class="btn-pause-os" data-pause-os="${os.id}">
                ${os.isPaused ? '▶ Retomar' : '⏸ Pausar'}
              </button>
            </div>
          </article>
        `;
      })
      .join('');
  }

  // 2. Renderizar Coluna É A VEZ DO SEU SETOR
  const elQueue = document.getElementById('listQueueOS');
  if (queueList.length === 0) {
    elQueue.innerHTML = `
      <div style="padding: 28px 16px; text-align: center; color: var(--text-muted); font-size: 0.9rem;">
        Sem ordens aguardando na fila imediata deste setor.
      </div>
    `;
  } else {
    elQueue.innerHTML = queueList
      .map((os) => {
        const displayCode = os.osDisplayCode || os.id;
        const stagesHtml = os.stages
          .map((st) => {
            const icon = st.status === 'done' ? '✓' : st.status === 'current' ? '●' : '';
            return `<span class="stage-chip ${st.status}">${icon} ${st.name}</span>`;
          })
          .join('');

        return `
          <article class="os-card ${os.isLate ? 'is-late' : ''}">
            <div class="os-card-top">
              <span class="os-id-group">🚚 ${displayCode} · ${os.sector}</span>
              <span class="status-pill ${os.isLate ? 'late' : 'ontime'}">
                ${os.isLate ? '🕒 ATRASADO' : `PRAZO ${os.deadline}`}
              </span>
            </div>

            <div class="os-queue-main">
              <div>
                <h3 class="os-client-name">${os.client}</h3>
                <p class="os-product-desc">${os.title}</p>
                <div class="os-specs-line">
                  <span class="spec-measure-badge">${os.dimensions}</span>
                  <span>· ${os.qty} · prazo ${os.deadline} · ${os.tag}</span>
                </div>
              </div>

              <button type="button" class="btn-peguei-giant" data-peguei-os="${os.id}">
                <span>PEGUEI</span>
                <span class="btn-peguei-sub">Iniciar etapa</span>
              </button>
            </div>

            <div class="pipeline-trail" aria-label="Etapas da Ordem de Serviço">
              ${stagesHtml}
            </div>

            <button type="button" class="croqui-thumb-btn" data-open-details="${os.id}">
              ${renderCroquiSvg(os.croquiType, os.dimensions, false)}
              <span class="croqui-thumb-meta">
                <span class="croqui-thumb-title">Ver materiais (${os.materials.length}), croqui e observações</span>
                <span class="croqui-thumb-sub">${os.obs}</span>
              </span>
            </button>
          </article>
        `;
      })
      .join('');
  }

  // 3. Renderizar Coluna A CAMINHO (DÁ PARA ADIANTAR)
  const elIncoming = document.getElementById('listIncomingOS');
  if (incomingList.length === 0) {
    elIncoming.innerHTML = `
      <div style="padding: 24px 12px; text-align: center; color: var(--text-muted); font-size: 0.85rem;">
        Nenhum trabalho em setor anterior disponível para adiantamento.
      </div>
    `;
  } else {
    elIncoming.innerHTML = incomingList
      .map((os) => {
        const displayCode = os.osDisplayCode || os.id;
        return `
          <article class="os-card is-incoming">
            <div class="os-card-top">
              <span class="os-id-group">🥞 ${displayCode} · ${os.sector}</span>
              <span class="status-pill ontime">${os.currentLocationLabel || 'Em outro setor'}</span>
            </div>

            <div>
              <h3 class="os-client-name" style="font-size: 1.05rem;">${os.client}</h3>
              <p class="os-product-desc" style="font-size: 0.86rem;">${os.title}</p>
              <div class="os-specs-line">
                <span class="spec-measure-badge">${os.dimensions}</span>
                <span>· prazo ${os.deadline}</span>
              </div>
            </div>

            <button type="button" class="croqui-thumb-btn" data-open-details="${os.id}" style="min-block-size:44px; padding:4px 8px;">
              <span class="croqui-thumb-meta">
                <span class="croqui-thumb-title" style="font-size:0.78rem;">Ver detalhes / o que adiantar</span>
                <span class="croqui-thumb-sub">${os.obs}</span>
              </span>
            </button>

            <button type="button" class="btn-adiantar" data-peguei-os="${os.id}">
              <span>⚡ Adiantar / Peguei</span>
            </button>
          </article>
        `;
      })
      .join('');
  }

  // Bind events for OS Cards
  document.querySelectorAll('[data-peguei-os]').forEach((btn) => {
    btn.addEventListener('click', () => {
      openAssignModal(btn.getAttribute('data-peguei-os'));
    });
  });

  document.querySelectorAll('[data-open-details]').forEach((btn) => {
    btn.addEventListener('click', () => {
      openOsDetailsModal(btn.getAttribute('data-open-details'));
    });
  });

  document.querySelectorAll('[data-finish-os]').forEach((btn) => {
    btn.addEventListener('click', () => {
      openFinishModal(btn.getAttribute('data-finish-os'));
    });
  });

  document.querySelectorAll('[data-pause-os]').forEach((btn) => {
    btn.addEventListener('click', () => {
      togglePauseOS(btn.getAttribute('data-pause-os'));
    });
  });
}

// ============================================================================
// MODAL 1: QUEM VAI FAZER? (INDIVIDUAL OU EQUIPE/DUPLA)
// ============================================================================

function openAssignModal(osId) {
  const os = OS_LIST.find((o) => o.id === osId);
  if (!os) return;
  state.pendingAssignOsId = osId;

  const displayCode = os.osDisplayCode || os.id;
  document.getElementById('assignOsEyebrow').textContent = `${displayCode} · ${os.client.toUpperCase()} · ${os.sector.toUpperCase()}`;

  const grid = document.getElementById('assignOperatorsGrid');
  grid.innerHTML = OPERATORS.map((op, index) => {
    const isCurrentOp = op.id === state.currentOperatorId;
    return `
      <label class="operator-card-option">
        <input type="checkbox" name="assignOperator" value="${op.name}" ${isCurrentOp || index === 0 ? 'checked' : ''}>
        <span>
          <span class="op-card-name">${isCurrentOp ? 'Eu mesmo' : op.name}</span>
          <span class="op-card-role">${op.role}</span>
        </span>
      </label>
    `;
  }).join('');

  const dlg = document.getElementById('dialogAssignTeam');
  dlg.showModal();
}

function confirmAssignOS(onlyMe = false) {
  const os = OS_LIST.find((o) => o.id === state.pendingAssignOsId);
  if (!os) return;

  let chosenNames = [];
  if (onlyMe) {
    const currentOp = OPERATORS.find((o) => o.id === state.currentOperatorId) || OPERATORS[0];
    chosenNames = [currentOp.name];
  } else {
    const checked = document.querySelectorAll('#assignOperatorsGrid input[name="assignOperator"]:checked');
    chosenNames = Array.from(checked).map((el) => el.value);
  }

  if (chosenNames.length === 0) {
    showToast('⚠️ Selecione pelo menos 1 operador para iniciar a OS.');
    return;
  }

  os.state = 'running';
  os.isPaused = false;
  os.assignedTo = chosenNames;

  // Atualizar etapa atual no pipeline
  os.stages.forEach((st) => {
    if (st.name === os.sector) {
      st.status = 'current';
      st.by = chosenNames.join(' + ');
    }
  });

  document.getElementById('dialogAssignTeam').close();
  renderHeader();
  renderSectorBar();
  renderOSBoard();
  showToast(`🚀 ${os.osDisplayCode || os.id} iniciada por ${chosenNames.join(' + ')}!`);
}

function togglePauseOS(osId) {
  const os = OS_LIST.find((o) => o.id === osId);
  if (!os) return;

  if (os.isPaused) {
    os.isPaused = false;
    os.pauseReason = '';
    showToast(`▶️ Produção retomada na ${os.osDisplayCode || os.id}.`);
  } else {
    os.isPaused = true;
    os.pauseReason = 'Aguardando material / Pausa';
    showToast(`⏸️ ${os.osDisplayCode || os.id} pausada. Cronômetro suspenso.`);
  }
  renderOSBoard();
}

// ============================================================================
// MODAL 2: DETALHES DA OS (CROQUI AMPLIADO, MATERIAIS E HISTÓRICO)
// ============================================================================

function openOsDetailsModal(osId) {
  const os = OS_LIST.find((o) => o.id === osId);
  if (!os) return;
  state.activeDetailsOsId = osId;

  const displayCode = os.osDisplayCode || os.id;
  document.getElementById('detailsOsEyebrow').textContent = `${displayCode} · SETOR: ${os.sector.toUpperCase()} · PRAZO: ${os.deadline}`;
  document.getElementById('dialogDetailsTitle').textContent = os.client;
  document.getElementById('detailsOsSubtitle').textContent = `${os.title} (${os.dimensions} · ${os.qty})`;

  document.getElementById('detailsCroquiBox').innerHTML = renderCroquiSvg(os.croquiType, os.dimensions, true);
  document.getElementById('detailsObsBox').innerHTML = `
    <strong style="font-size:0.78rem; text-transform:uppercase; color:var(--color-amber-700); display:block;">
      ⚠️ Observações Técnicas de Produção
    </strong>
    <p style="font-size:0.9rem; margin-block-start:4px; font-weight:600; color:var(--text-primary);">${os.obs}</p>
  `;

  const matContainer = document.getElementById('detailsMaterialsList');
  matContainer.innerHTML = os.materials
    .map((m) => {
      const remaining = Math.max(0, +(m.predicted - m.used).toFixed(2));
      return `
        <div style="display:flex; align-items:center; justify-content:space-between; background:var(--surface-subtle); border:1px solid var(--border-strong); padding:8px 12px; border-radius:8px; gap:8px;">
          <div>
            <strong style="font-size:0.88rem; display:block;">${m.name}</strong>
            <span style="font-size:0.78rem; color:var(--text-secondary);">
              Previsto: <strong>${formatNumberBR(m.predicted)} ${m.unit}</strong> · Já retirado: <strong>${formatNumberBR(m.used)} ${m.unit}</strong>
            </span>
          </div>
          <button type="button" class="preset-chip-btn" data-jump-mat="${m.matId}" data-jump-os="${displayCode}" data-jump-qty="${remaining}">
            Apontar ${remaining > 0 ? `(${formatNumberBR(remaining)} ${m.unit})` : ''}
          </button>
        </div>
      `;
    })
    .join('');

  matContainer.querySelectorAll('[data-jump-mat]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const matId = btn.getAttribute('data-jump-mat');
      const targetOs = btn.getAttribute('data-jump-os');
      const qty = btn.getAttribute('data-jump-qty');
      document.getElementById('dialogOsDetails').close();
      jumpToMaterialForOS(matId, targetOs, qty);
    });
  });

  const histContainer = document.getElementById('detailsHistoryList');
  histContainer.innerHTML = os.stages
    .map((st) => {
      const badgeColor = st.status === 'done' ? 'var(--color-emerald-700)' : st.status === 'current' ? 'var(--accent-primary)' : 'var(--text-muted)';
      return `
        <div style="display:flex; justify-content:space-between; padding:6px 8px; border-block-end:1px solid var(--border-subtle);">
          <span><strong style="color:${badgeColor};">${st.name}</strong> · ${st.by}</span>
          <span style="font-family:var(--font-mono); font-weight:700;">${st.duration}</span>
        </div>
      `;
    })
    .join('');

  document.getElementById('dialogOsDetails').showModal();
}

// ============================================================================
// MODAL 3: FINALIZAR ETAPA (COM CHECKLIST DE BAIXA DE ESTOQUE)
// ============================================================================

function openFinishModal(osId) {
  const os = OS_LIST.find((o) => o.id === osId);
  if (!os) return;
  state.pendingFinishOsId = osId;

  const displayCode = os.osDisplayCode || os.id;
  document.getElementById('finishOsEyebrow').textContent = `FINALIZAR ETAPA · ${displayCode} (${os.sector.toUpperCase()})`;

  // Descobrir próximo setor
  const currentIdx = os.stages.findIndex((s) => s.status === 'current');
  const nextStage = currentIdx >= 0 && currentIdx + 1 < os.stages.length
    ? os.stages[currentIdx + 1].name
    : 'Concluído / Entrega Final';

  document.getElementById('finishNextSectorInfo').innerHTML = `
    Tempo registrado: <strong>${formatDuration(os.elapsedSeconds)}</strong> · Próximo setor: <strong>${nextStage}</strong>
  `;

  const checklist = document.getElementById('finishMaterialsChecklist');
  checklist.innerHTML = os.materials
    .map((m, idx) => {
      const pending = Math.max(0, +(m.predicted - m.used).toFixed(2));
      const checked = pending > 0 ? 'checked' : '';
      return `
        <label class="operator-card-option" style="min-block-size:52px; padding:8px 12px;">
          <input type="checkbox" name="finishMatCheck" value="${idx}" ${checked}>
          <span style="flex:1;">
            <span class="op-card-name">${m.name}</span>
            <span class="op-card-role">
              ${pending > 0 ? `Dar baixa automática do saldo previsto: <strong>${formatNumberBR(pending)} ${m.unit}</strong>` : `Já baixado integralmente (${formatNumberBR(m.used)} ${m.unit})`}
            </span>
          </span>
        </label>
      `;
    })
    .join('');

  document.getElementById('dialogFinishOS').showModal();
}

function confirmFinishOS() {
  const idx = OS_LIST.findIndex((o) => o.id === state.pendingFinishOsId);
  if (idx === -1) return;
  const os = OS_LIST[idx];

  // Baixar materiais selecionados
  const checkedBoxes = document.querySelectorAll('#finishMaterialsChecklist input[name="finishMatCheck"]:checked');
  checkedBoxes.forEach((box) => {
    const mIdx = Number(box.value);
    const matRef = os.materials[mIdx];
    if (matRef) {
      const diff = Math.max(0, +(matRef.predicted - matRef.used).toFixed(2));
      if (diff > 0) {
        matRef.used = matRef.predicted;
        const catalogItem = MATERIALS_CATALOG.find((c) => c.id === matRef.matId);
        if (catalogItem) {
          catalogItem.stock = +(catalogItem.stock - diff).toFixed(2);
        }
      }
    }
  });

  // Avançar etapa ou concluir
  const currentIdx = os.stages.findIndex((s) => s.status === 'current');
  if (currentIdx >= 0) {
    os.stages[currentIdx].status = 'done';
    os.stages[currentIdx].duration = formatDuration(os.elapsedSeconds);
  }

  if (currentIdx >= 0 && currentIdx + 1 < os.stages.length) {
    const nextStageName = os.stages[currentIdx + 1].name;
    os.stages[currentIdx + 1].status = 'current';
    os.sector = nextStageName;
    os.state = 'queue';
    os.assignedTo = [];
    os.elapsedSeconds = 0;
    showToast(`✅ Etapa concluída! ${os.osDisplayCode || os.id} enviada para a fila de ${nextStageName}.`);
  } else {
    OS_LIST.splice(idx, 1);
    showToast(`🎉 ${os.osDisplayCode || os.id} finalizada em todos os setores!`);
  }

  document.getElementById('dialogFinishOS').close();
  renderHeader();
  renderSectorBar();
  renderOSBoard();
  renderMaterialView();
}

// ============================================================================
// VISTA 2: MOVIMENTAÇÃO DE ESTOQUE (MATERIAL + CALCULADORA INTELIGENTE)
// ============================================================================

const MATERIAL_CATEGORIES = ['Sugeridos OS', 'Todos', 'Lonas & Adesivos', 'Serralheria', 'Elétrica & LED', 'Pintura & Química'];

function jumpToMaterialForOS(matId, osCode, suggestedQty) {
  state.activeView = 'material';
  state.selectedMaterialId = matId;
  state.selectedMaterialWorkTarget = osCode;
  state.materialCalcMode = 'direct';
  state.materialQtyStr = String(suggestedQty || '0').replace('.', ',');
  renderHeader();
  renderMaterialView();
}

function renderMaterialView() {
  // 1. Renderizar Pílulas de Categoria
  const catContainer = document.getElementById('materialCategoryPills');
  catContainer.innerHTML = MATERIAL_CATEGORIES.map((cat) => `
    <button type="button" class="cat-pill" data-mat-cat="${cat}" aria-pressed="${state.materialCategory === cat}">
      ${cat === 'Sugeridos OS' ? '⚡ Sugeridos nas OS' : cat}
    </button>
  `).join('');

  catContainer.querySelectorAll('[data-mat-cat]').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.materialCategory = btn.getAttribute('data-mat-cat');
      renderMaterialView();
    });
  });

  // Mapear quais materiais estão previstos nas OS ativas
  const suggestedMap = {};
  OS_LIST.forEach((os) => {
    const code = os.osDisplayCode || os.id;
    os.materials.forEach((m) => {
      if (!suggestedMap[m.matId]) suggestedMap[m.matId] = [];
      suggestedMap[m.matId].push({ osCode: code, predicted: m.predicted, used: m.used });
    });
  });

  // 2. Filtrar Catálogo
  const query = state.materialSearch.trim().toLowerCase();
  const filteredMats = MATERIALS_CATALOG.filter((item) => {
    if (query && !item.name.toLowerCase().includes(query) && !item.category.toLowerCase().includes(query)) {
      return false;
    }
    if (state.materialCategory === 'Sugeridos OS') {
      return Boolean(suggestedMap[item.id]);
    }
    if (state.materialCategory !== 'Todos' && item.category !== state.materialCategory) {
      return false;
    }
    return true;
  });

  const listEl = document.getElementById('materialCatalogList');
  listEl.innerHTML = filteredMats
    .map((item) => {
      const isSelected = item.id === state.selectedMaterialId;
      const isNeg = item.stock < 0;
      const sugList = suggestedMap[item.id] || [];
      const sugBadge = sugList.length > 0
        ? `<span class="mat-os-suggested-tag">Nas OS: ${sugList.map((s) => s.osCode).join(', ')}</span>`
        : '';

      return `
        <button
          type="button"
          class="material-item-card"
          role="option"
          aria-selected="${isSelected}"
          data-select-mat="${item.id}"
        >
          <span>
            <span class="mat-item-name">${item.name}</span>
            <span class="mat-item-stock ${isNeg ? 'negative' : ''}">
              em estoque: ${formatNumberBR(item.stock)} ${item.unit}
            </span>
          </span>
          ${sugBadge}
        </button>
      `;
    })
    .join('');

  listEl.querySelectorAll('[data-select-mat]').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.selectedMaterialId = btn.getAttribute('data-select-mat');
      const newlySelected = MATERIALS_CATALOG.find((m) => m.id === state.selectedMaterialId);
      if (newlySelected && !newlySelected.supportsDimCalc) {
        state.materialCalcMode = 'direct';
      }
      renderMaterialView();
    });
  });

  // 3. Configurar Painel Direito para o Material Selecionado
  const currentMat = MATERIALS_CATALOG.find((m) => m.id === state.selectedMaterialId) || MATERIALS_CATALOG[0];
  document.getElementById('matItemHeaderTitle').textContent = currentMat.name.toUpperCase();
  document.getElementById('matSelectedUnitLabel').textContent = `QUANTIDADE (${currentMat.unit.toUpperCase()})`;
  document.getElementById('matStockSubInfo').textContent = `Em estoque: ${formatNumberBR(currentMat.stock)} ${currentMat.unit}`;

  // Abas de modo de cálculo (Direto vs Calcular L x A cm)
  const tabsEl = document.getElementById('matCalcModeTabs');
  tabsEl.hidden = !currentMat.supportsDimCalc;
  document.getElementById('btnModeDirect').setAttribute('aria-pressed', String(state.materialCalcMode === 'direct'));
  document.getElementById('btnModeDimensions').setAttribute('aria-pressed', String(state.materialCalcMode === 'dimensions'));

  const dimBox = document.getElementById('matDimCalcBox');
  dimBox.hidden = !(currentMat.supportsDimCalc && state.materialCalcMode === 'dimensions');

  if (!dimBox.hidden) {
    document.getElementById('valMatDimW').textContent = state.materialDimW || '0';
    document.getElementById('valMatDimH').textContent = state.materialDimH || '0';
    document.getElementById('btnMatDimW').setAttribute('aria-current', String(state.materialDimFocus === 'w'));
    document.getElementById('btnMatDimH').setAttribute('aria-current', String(state.materialDimFocus === 'h'));
    const wMeters = (parseFloat(state.materialDimW.replace(',', '.')) || 0) / 100;
    const hMeters = (parseFloat(state.materialDimH.replace(',', '.')) || 0) / 100;
    const area = +(wMeters * hMeters).toFixed(2);
    state.materialQtyStr = String(area).replace('.', ',');
  }

  document.getElementById('matQtyDisplay').textContent = state.materialQtyStr || '0';

  // 4. Renderizar Opções de OS ("PARA QUAL TRABALHO?")
  const uniqueOS = [];
  const seenCodes = new Set();
  OS_LIST.forEach((os) => {
    const code = os.osDisplayCode || os.id;
    if (!seenCodes.has(code)) {
      seenCodes.add(code);
      uniqueOS.push(os);
    }
  });

  const workListEl = document.getElementById('matWorkOptionsList');
  let predictedForSelectedOS = null;

  const osOptionsHtml = uniqueOS.map((os) => {
    const code = os.osDisplayCode || os.id;
    const matEntry = os.materials.find((m) => m.matId === currentMat.id);
    const isChecked = state.selectedMaterialWorkTarget === code;
    if (isChecked && matEntry) {
      predictedForSelectedOS = matEntry;
    }

    return `
      <label class="work-option-label">
        <input type="radio" name="matWorkTarget" value="${code}" ${isChecked ? 'checked' : ''}>
        <span class="work-opt-title">${code} · ${os.client}</span>
        <span class="work-opt-sub">${os.tag}</span>
        ${
          matEntry
            ? `<span class="work-opt-predicted">Previsto ${formatNumberBR(matEntry.predicted)} ${matEntry.unit} · já retirado ${formatNumberBR(matEntry.used)} ${matEntry.unit}</span>`
            : ''
        }
      </label>
    `;
  });

  const semOsChecked = state.selectedMaterialWorkTarget === 'Sem OS';
  workListEl.innerHTML = [
    `
      <label class="work-option-label">
        <input type="radio" name="matWorkTarget" value="Sem OS" ${semOsChecked ? 'checked' : ''}>
        <span class="work-opt-title">Sem OS</span>
        <span class="work-opt-sub">uso interno, teste, conserto</span>
      </label>
    `,
    ...osOptionsHtml
  ].join('');

  workListEl.querySelectorAll('input[name="matWorkTarget"]').forEach((radio) => {
    radio.addEventListener('change', () => {
      state.selectedMaterialWorkTarget = radio.value;
      renderMaterialView();
    });
  });

  // 5. Renderizar Atalhos Rápidos (1 Toque "Usar previsto da OS" + Presets do Material)
  const presetsRow = document.getElementById('matQuickPresetsRow');
  const presetButtons = [];

  if (predictedForSelectedOS) {
    const rem = Math.max(0, +(predictedForSelectedOS.predicted - predictedForSelectedOS.used).toFixed(2));
    const valToUse = rem > 0 ? rem : predictedForSelectedOS.predicted;
    presetButtons.push(`
      <button type="button" class="preset-chip-btn predicted" data-preset-val="${valToUse}">
        ⚡ Usar previsto (${formatNumberBR(valToUse)} ${currentMat.unit})
      </button>
    `);
  }

  currentMat.presets.forEach((p) => {
    presetButtons.push(`
      <button type="button" class="preset-chip-btn" data-preset-val="${p.value}">
        ${p.label}
      </button>
    `);
  });

  presetsRow.innerHTML = presetButtons.join('');
  presetsRow.querySelectorAll('[data-preset-val]').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.materialCalcMode = 'direct';
      state.materialQtyStr = String(btn.getAttribute('data-preset-val')).replace('.', ',');
      renderMaterialView();
    });
  });
}

function handleMaterialKeypad(key) {
  const currentMat = MATERIALS_CATALOG.find((m) => m.id === state.selectedMaterialId) || MATERIALS_CATALOG[0];

  if (currentMat.supportsDimCalc && state.materialCalcMode === 'dimensions') {
    const prop = state.materialDimFocus === 'w' ? 'materialDimW' : 'materialDimH';
    let cur = state[prop];
    if (key === 'backspace') {
      cur = cur.slice(0, -1);
    } else if (key !== ',') {
      cur = cur === '0' ? key : cur + key;
    }
    state[prop] = cur || '0';
    renderMaterialView();
    return;
  }

  let s = state.materialQtyStr;
  if (key === 'backspace') {
    s = s.length > 1 ? s.slice(0, -1) : '0';
  } else if (key === ',') {
    if (!s.includes(',')) s += ',';
  } else {
    s = s === '0' ? key : s + key;
  }
  state.materialQtyStr = s;
  renderMaterialView();
}

function submitMaterialMovement(isReturn = false) {
  const currentMat = MATERIALS_CATALOG.find((m) => m.id === state.selectedMaterialId);
  if (!currentMat) return;

  const qty = parseFloat(state.materialQtyStr.replace(',', '.')) || 0;
  if (qty <= 0) {
    showToast('⚠️ Digite ou selecione uma quantidade maior que zero.');
    return;
  }

  if (isReturn) {
    currentMat.stock = +(currentMat.stock + qty).toFixed(2);
    showToast(`↩️ Devolvido: ${formatNumberBR(qty)} ${currentMat.unit} de ${currentMat.name}.`);
  } else {
    currentMat.stock = +(currentMat.stock - qty).toFixed(2);
    // Atualizar na OS se vinculada
    if (state.selectedMaterialWorkTarget !== 'Sem OS') {
      OS_LIST.forEach((os) => {
        const code = os.osDisplayCode || os.id;
        if (code === state.selectedMaterialWorkTarget) {
          const entry = os.materials.find((m) => m.matId === currentMat.id);
          if (entry) {
            entry.used = +(entry.used + qty).toFixed(2);
          } else {
            os.materials.push({
              matId: currentMat.id,
              name: currentMat.name,
              predicted: qty,
              used: qty,
              unit: currentMat.unit
            });
          }
        }
      });
    }
    showToast(`✅ Retirado: ${formatNumberBR(qty)} ${currentMat.unit} de ${currentMat.name} (${state.selectedMaterialWorkTarget}).`);
  }

  state.materialQtyStr = '0';
  renderHeader();
  renderMaterialView();
}

// ============================================================================
// VISTA 3: CHAPAS (DESENHO 2D FIEL AO MODELO + TECLADO INTEGRADO)
// ============================================================================

function renderChapasView() {
  // 1. Submodo: Cortei de uma chapa vs Cadastrar sobra ou chapa
  document.getElementById('tabChapaCut').setAttribute('aria-pressed', String(state.chapaSubmode === 'cut'));
  document.getElementById('tabChapaRegister').setAttribute('aria-pressed', String(state.chapaSubmode === 'register'));

  document.getElementById('chapaDimsHeading').textContent =
    state.chapaSubmode === 'cut'
      ? 'MEDIDAS DO PEDAÇO CORTADO (CM)'
      : 'MEDIDAS DA NOVA CHAPA OU SOBRA (CM)';

  document.getElementById('btnChapaSubmit').textContent =
    state.chapaSubmode === 'cut' ? 'CORTEI' : 'CADASTRAR CHAPA';

  // 2. Botões de Tipo de Chapa
  const typeContainer = document.getElementById('chapaTypePills');
  typeContainer.innerHTML = SHEET_TYPES.map((t) => `
    <button type="button" class="sheet-type-btn" data-sheet-type="${t}" aria-pressed="${state.selectedSheetType === t}">
      ${t}
    </button>
  `).join('');

  typeContainer.querySelectorAll('[data-sheet-type]').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.selectedSheetType = btn.getAttribute('data-sheet-type');
      const firstOfType = SHEETS_INVENTORY.find((s) => s.type === state.selectedSheetType);
      if (firstOfType) state.selectedSheetId = firstOfType.id;
      renderChapasView();
    });
  });

  // 3. Campos de Largura e Altura (foco no teclado integrado)
  document.getElementById('btnChapaFocusW').setAttribute('aria-current', String(state.chapaFocusField === 'w'));
  document.getElementById('btnChapaFocusH').setAttribute('aria-current', String(state.chapaFocusField === 'h'));
  document.getElementById('valChapaW').textContent = state.chapaWStr ? `${state.chapaWStr} cm` : '—';
  document.getElementById('valChapaH').textContent = state.chapaHStr ? `${state.chapaHStr} cm` : '—';

  // 4. Seletor de OS para o corte
  const osPillsContainer = document.getElementById('chapaOsPills');
  if (state.chapaSubmode === 'cut') {
    document.getElementById('chapaTargetLabel').textContent = 'PARA QUAL TRABALHO?';
    const targets = ['Sem OS', 'OS-39 · Cliente Balcão', 'OS-36 · CS Comunicação', 'OS-41 · Padaria Pão Dourado', 'OS-47 · Auto Posto'];
    osPillsContainer.innerHTML = targets
      .map((t) => `
        <button type="button" class="chapa-os-btn" data-chapa-os="${t}" aria-pressed="${state.selectedChapaWorkTarget === t}">
          ${t}
        </button>
      `)
      .join('');
    osPillsContainer.querySelectorAll('[data-chapa-os]').forEach((btn) => {
      btn.addEventListener('click', () => {
        state.selectedChapaWorkTarget = btn.getAttribute('data-chapa-os');
        renderChapasView();
      });
    });
  } else {
    document.getElementById('chapaTargetLabel').textContent = 'CLASSIFICAÇÃO DA CHAPA';
    const kinds = ['sobra (retalho aproveitável)', 'inteira (nova no estoque)'];
    osPillsContainer.innerHTML = kinds
      .map((k) => `
        <button type="button" class="chapa-os-btn" data-chapa-os="${k}" aria-pressed="${state.selectedChapaWorkTarget === k}">
          ${k}
        </button>
      `)
      .join('');
    osPillsContainer.querySelectorAll('[data-chapa-os]').forEach((btn) => {
      btn.addEventListener('click', () => {
        state.selectedChapaWorkTarget = btn.getAttribute('data-chapa-os');
        renderChapasView();
      });
    });
  }

  // 5. Filtrar Chapas deste tipo (Sobras primeiro, inteiras por último)
  const sheetsOfType = SHEETS_INVENTORY
    .filter((s) => s.type === state.selectedSheetType)
    .sort((a, b) => (a.kind === 'sobra' && b.kind !== 'sobra' ? -1 : 1));

  let activeSheet = sheetsOfType.find((s) => s.id === state.selectedSheetId) || sheetsOfType[0];
  if (activeSheet) {
    state.selectedSheetId = activeSheet.id;
  }

  // 6. Desenhar 2D da Chapa Selecionada (fiel à imagem 5)
  const stageContainer = document.getElementById('sheet2dContainer');
  if (activeSheet) {
    document.getElementById('stageSheetCode').textContent = activeSheet.id;
    document.getElementById('stageSheetMeta').textContent =
      `${activeSheet.type} · ${activeSheet.widthCm} × ${activeSheet.heightCm} cm · livre ${formatNumberBR(activeSheet.freeAreaM2)} m²`;

    const wInput = parseInt(state.chapaWStr, 10) || 0;
    const hInput = parseInt(state.chapaHStr, 10) || 0;
    const hintEl = document.getElementById('stageSheetStatusHint');
    if (wInput > 0 && hInput > 0) {
      const cutAreaM2 = +((wInput * hInput) / 10000).toFixed(2);
      hintEl.textContent = `Corte: ${wInput} × ${hInput} cm (${formatNumberBR(cutAreaM2)} m²)`;
    } else {
      hintEl.textContent = 'Digite L × A no teclado ao lado';
    }

    stageContainer.innerHTML = buildSheet2DSvg(activeSheet, false);
  }

  // 7. Renderizar Fita Inferior de Chapas ("CHAPAS DESTE TIPO — SOBRAS PRIMEIRO, INTEIRAS POR ÚLTIMO")
  const stripEl = document.getElementById('sheetStripList');
  stripEl.innerHTML = sheetsOfType
    .map((sheet) => {
      const isSelected = activeSheet && sheet.id === activeSheet.id;
      return `
        <button
          type="button"
          class="sheet-mini-card"
          role="option"
          aria-selected="${isSelected}"
          data-select-sheet="${sheet.id}"
        >
          <span class="sheet-mini-title">${sheet.id}</span>
          <div>${buildSheet2DSvg(sheet, true)}</div>
          <span class="sheet-mini-foot">
            ${sheet.kind} · ${sheet.widthCm} × ${sheet.heightCm} cm · ${formatNumberBR(sheet.freeAreaM2)} m² livres
          </span>
        </button>
      `;
    })
    .join('');

  stripEl.querySelectorAll('[data-select-sheet]').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.selectedSheetId = btn.getAttribute('data-select-sheet');
      renderChapasView();
    });
  });
}

function buildSheet2DSvg(sheet, isMini = false) {
  // Calcula proporção visual da chapa mantendo limites agradáveis
  const ratio = sheet.widthCm / sheet.heightCm;
  let rectW = isMini ? 110 : 280;
  let rectH = Math.round(rectW / ratio);

  const maxH = isMini ? 54 : 155;
  if (rectH > maxH) {
    rectH = maxH;
    rectW = Math.round(rectH * ratio);
  }
  rectW = Math.max(isMini ? 28 : 80, rectW);
  rectH = Math.max(isMini ? 18 : 55, rectH);

  const fillRed = sheet.kind === 'inteira' && isMini ? '#ffffff' : '#ff0800';
  const cutsRects = (sheet.cuts || [])
    .map((c) => {
      const cx = (c.xPct / 100) * rectW;
      const cy = (c.yPct / 100) * rectH;
      const cw = (c.wPct / 100) * rectW;
      const ch = (c.hPct / 100) * rectH;
      return `
        <rect x="${cx}" y="${cy}" width="${cw}" height="${ch}" fill="url(#hatchPattern)" stroke="#78716c" stroke-width="1"/>
      `;
    })
    .join('');

  if (isMini) {
    return `
      <svg aria-hidden="true" width="${rectW + 4}" height="${rectH + 4}" viewBox="-2 -2 ${rectW + 4} ${rectH + 4}">
        <defs>
          <pattern id="hatchPattern" width="6" height="6" patternTransform="rotate(45 0 0)" patternUnits="userSpaceOnUse">
            <rect width="6" height="6" fill="#ece8e1"/>
            <line x1="0" y1="0" x2="0" y2="6" stroke="#a8a29e" stroke-width="2"/>
          </pattern>
        </defs>
        <rect x="0" y="0" width="${rectW}" height="${rectH}" fill="${fillRed}" stroke="#1c1917" stroke-width="2"/>
        ${cutsRects}
      </svg>
    `;
  }

  return `
    <svg role="img" width="${rectW + 90}" height="${rectH + 65}" viewBox="-55 -15 ${rectW + 90} ${rectH + 65}">
      <title>Representação 2D da chapa ${sheet.id} (${sheet.widthCm} por ${sheet.heightCm} cm)</title>
      <defs>
        <pattern id="hatchPattern" width="8" height="8" patternTransform="rotate(45 0 0)" patternUnits="userSpaceOnUse">
          <rect width="8" height="8" fill="#ece8e1"/>
          <line x1="0" y1="0" x2="0" y2="8" stroke="#a8a29e" stroke-width="2.5"/>
        </pattern>
      </defs>
      <rect x="0" y="0" width="${rectW}" height="${rectH}" fill="#ff0800" stroke="#1c1917" stroke-width="4"/>
      ${cutsRects}
      <!-- Cota Altura (Esquerda) -->
      <text
        x="-16"
        y="${rectH / 2}"
        text-anchor="middle"
        fill="#57534e"
        font-size="18"
        font-family="sans-serif"
        transform="rotate(-90, -16, ${rectH / 2})"
      >${sheet.heightCm} cm</text>
      <!-- Cota Largura (Base) -->
      <text
        x="${rectW / 2}"
        y="${rectH + 32}"
        text-anchor="middle"
        fill="#57534e"
        font-size="18"
        font-family="sans-serif"
      >${sheet.widthCm} cm</text>
    </svg>
  `;
}

function handleChapaKeypad(key) {
  const field = state.chapaFocusField === 'w' ? 'chapaWStr' : 'chapaHStr';
  let val = state[field];

  if (key === 'clear') {
    state.chapaWStr = '';
    state.chapaHStr = '';
  } else if (key === 'backspace') {
    state[field] = val.slice(0, -1);
  } else if (val.length < 4) {
    state[field] = val === '0' ? key : val + key;
  }
  renderChapasView();
}

function submitChapaAction() {
  const wCm = parseInt(state.chapaWStr, 10) || 0;
  const hCm = parseInt(state.chapaHStr, 10) || 0;

  if (wCm <= 0 || hCm <= 0) {
    showToast('⚠️ Digite a Largura (cm) e a Altura (cm) no teclado numérico.');
    return;
  }

  if (state.chapaSubmode === 'register') {
    const newCode = `CH-${SHEETS_INVENTORY.length + 4}`;
    const areaM2 = +((wCm * hCm) / 10000).toFixed(2);
    const isInteira = state.selectedChapaWorkTarget.startsWith('inteira');
    SHEETS_INVENTORY.unshift({
      id: newCode,
      type: state.selectedSheetType,
      kind: isInteira ? 'inteira' : 'sobra',
      widthCm: wCm,
      heightCm: hCm,
      freeAreaM2: areaM2,
      cuts: []
    });
    state.selectedSheetId = newCode;
    state.chapaWStr = '';
    state.chapaHStr = '';
    state.chapaSubmode = 'cut';
    renderChapasView();
    showToast(`✅ ${newCode} (${state.selectedSheetType} ${wCm}×${hCm}cm) cadastrada no estoque!`);
    return;
  }

  const sheet = SHEETS_INVENTORY.find((s) => s.id === state.selectedSheetId);
  if (!sheet) return;

  if (wCm > sheet.widthCm || hCm > sheet.heightCm) {
    showToast(`⚠️ Corte (${wCm}×${hCm}cm) maior que as dimensões da chapa ${sheet.id} (${sheet.widthCm}×${sheet.heightCm}cm). Tente girar 90°!`);
    return;
  }

  const cutArea = +((wCm * hCm) / 10000).toFixed(2);
  sheet.freeAreaM2 = Math.max(0, +(sheet.freeAreaM2 - cutArea).toFixed(2));
  sheet.kind = 'sobra';

  const wPct = Math.min(95, Math.round((wCm / sheet.widthCm) * 100));
  const hPct = Math.min(95, Math.round((hCm / sheet.heightCm) * 100));
  const offsetCount = sheet.cuts.length;
  sheet.cuts.push({
    xPct: Math.min(100 - wPct, offsetCount * 12),
    yPct: 0,
    wPct,
    hPct
  });

  state.chapaWStr = '';
  state.chapaHStr = '';
  renderChapasView();
  showToast(`✂️ Corte de ${wCm}×${hCm}cm registrado na chapa ${sheet.id} (${state.selectedChapaWorkTarget})!`);
}

// ============================================================================
// TELA DE BLOQUEIO / PIN RÁPIDO COM AVATARES
// ============================================================================

function renderPinLockScreen() {
  const overlay = document.getElementById('pinLockOverlay');
  overlay.hidden = !state.pinLocked;
  if (!state.pinLocked) return;

  const grid = document.getElementById('pinQuickUsersGrid');
  grid.innerHTML = OPERATORS.map((op) => {
    const isSelected = op.id === state.pinTargetOperatorId;
    return `
      <button type="button" class="pin-user-card" data-pin-user="${op.id}" aria-pressed="${isSelected}">
        <span class="operator-avatar" style="inline-size:38px; block-size:38px; font-size:1rem;">${op.initials}</span>
        <span>
          <strong style="display:block; font-size:0.95rem;">${op.name}</strong>
          <span style="font-size:0.75rem; color:#a1a1aa;">PIN Demo: ${op.pin}</span>
        </span>
      </button>
    `;
  }).join('');

  grid.querySelectorAll('[data-pin-user]').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.pinTargetOperatorId = btn.getAttribute('data-pin-user');
      state.pinInput = '';
      renderPinLockScreen();
    });
  });

  const targetOp = OPERATORS.find((o) => o.id === state.pinTargetOperatorId) || OPERATORS[0];
  document.getElementById('pinSelectedUserLabel').textContent = `PIN de ${targetOp.name.split(' ')[0]} (Demo: ${targetOp.pin})`;

  const dots = document.querySelectorAll('#pinDotsBox .pin-dot');
  dots.forEach((dot, idx) => {
    dot.classList.toggle('filled', idx < state.pinInput.length);
  });
}

function handlePinKey(key) {
  const targetOp = OPERATORS.find((o) => o.id === state.pinTargetOperatorId) || OPERATORS[0];
  if (key === 'clear') {
    state.pinInput = '';
    renderPinLockScreen();
    return;
  }
  if (key === 'enter') {
    state.currentOperatorId = targetOp.id;
    state.pinLocked = false;
    state.pinInput = '';
    state.inactivitySeconds = 60;
    renderPinLockScreen();
    renderHeader();
    showToast(`👋 Bem-vindo ao totem, ${targetOp.name}!`);
    return;
  }
  if (state.pinInput.length < 4) {
    state.pinInput += key;
    renderPinLockScreen();
    if (state.pinInput.length === 4) {
      setTimeout(() => {
        state.currentOperatorId = targetOp.id;
        state.pinLocked = false;
        state.pinInput = '';
        state.inactivitySeconds = 60;
        renderPinLockScreen();
        renderHeader();
        showToast(`👋 Bem-vindo ao totem, ${targetOp.name}!`);
      }, 180);
    }
  }
}

// ============================================================================
// TIMERS E EVENT LISTENERS GLOBAIS
// ============================================================================

function setupEventListeners() {
  // Renovação automática do timer de inatividade a cada toque
  document.getElementById('tabletViewport').addEventListener('pointerdown', () => {
    state.inactivitySeconds = 60;
    document.getElementById('inactivitySeconds').textContent = '60s';
  });

  // Navegação principal no topo
  document.querySelectorAll('[data-nav-view]').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.activeView = btn.getAttribute('data-nav-view');
      renderHeader();
      if (state.activeView === 'os') renderOSBoard();
      if (state.activeView === 'material') renderMaterialView();
      if (state.activeView === 'chapas') renderChapasView();
      if (state.activeView === 'acm360') renderAcm360Studio();
    });
  });

  // Mostrar/ocultar setores vazios (0)
  document.getElementById('btnToggleZeroSectors').addEventListener('click', () => {
    state.showZeroSectors = !state.showZeroSectors;
    renderSectorBar();
  });

  // Sair / Bloquear PIN
  const lockFn = () => {
    state.pinLocked = true;
    state.pinInput = '';
    renderPinLockScreen();
  };
  document.getElementById('btnHeaderExit').addEventListener('click', lockFn);
  document.getElementById('btnSimLockPin').addEventListener('click', lockFn);

  // Botões do Simulador de Viewport (Moldura Tablet 11" vs Tela Cheia)
  const btnSimTablet = document.getElementById('btnSimTablet');
  const btnSimFull = document.getElementById('btnSimFullscreen');
  btnSimTablet.addEventListener('click', () => {
    document.body.setAttribute('data-viewport-mode', 'tablet');
    btnSimTablet.setAttribute('aria-pressed', 'true');
    btnSimFull.setAttribute('aria-pressed', 'false');
  });
  btnSimFull.addEventListener('click', () => {
    document.body.setAttribute('data-viewport-mode', 'fullscreen');
    btnSimFull.setAttribute('aria-pressed', 'true');
    btnSimTablet.setAttribute('aria-pressed', 'false');
  });

  // Modal 1: Confirmar Equipe / Individual
  document.getElementById('btnConfirmAssign').addEventListener('click', () => confirmAssignOS(false));
  document.getElementById('btnQuickOnlyMe').addEventListener('click', () => confirmAssignOS(true));

  // Modal 3: Confirmar Finalização de Etapa
  document.getElementById('btnConfirmFinishOS').addEventListener('click', confirmFinishOS);
  document.getElementById('btnFinishGoChapas').addEventListener('click', () => {
    document.getElementById('dialogFinishOS').close();
    state.activeView = 'chapas';
    renderHeader();
    renderChapasView();
  });
  document.getElementById('btnFinishGoMaterial').addEventListener('click', () => {
    document.getElementById('dialogFinishOS').close();
    state.activeView = 'material';
    renderHeader();
    renderMaterialView();
  });

  // Vista Material: Busca, Modos de Cálculo, Teclado e Botões Peguei/Devolvi
  document.getElementById('materialSearchInput').addEventListener('input', (e) => {
    state.materialSearch = e.target.value;
    if (state.materialSearch && state.materialCategory === 'Sugeridos OS') {
      state.materialCategory = 'Todos';
    }
    renderMaterialView();
  });

  document.getElementById('btnModeDirect').addEventListener('click', () => {
    state.materialCalcMode = 'direct';
    renderMaterialView();
  });
  document.getElementById('btnModeDimensions').addEventListener('click', () => {
    state.materialCalcMode = 'dimensions';
    renderMaterialView();
  });
  document.getElementById('btnMatDimW').addEventListener('click', () => {
    state.materialDimFocus = 'w';
    state.materialDimW = '0';
    renderMaterialView();
  });
  document.getElementById('btnMatDimH').addEventListener('click', () => {
    state.materialDimFocus = 'h';
    state.materialDimH = '0';
    renderMaterialView();
  });

  document.querySelectorAll('[data-mat-key]').forEach((btn) => {
    btn.addEventListener('click', () => {
      handleMaterialKeypad(btn.getAttribute('data-mat-key'));
    });
  });

  document.getElementById('btnMatSubmitPeguei').addEventListener('click', () => submitMaterialMovement(false));
  document.getElementById('btnMatSubmitDevolvi').addEventListener('click', () => submitMaterialMovement(true));

  // Vista Chapas: Abas, Foco Largura/Altura, Girar 90°, Teclado Numérico e Submit
  document.getElementById('tabChapaCut').addEventListener('click', () => {
    state.chapaSubmode = 'cut';
    state.selectedChapaWorkTarget = 'Sem OS';
    renderChapasView();
  });
  document.getElementById('tabChapaRegister').addEventListener('click', () => {
    state.chapaSubmode = 'register';
    state.selectedChapaWorkTarget = 'sobra (retalho aproveitável)';
    renderChapasView();
  });

  document.getElementById('btnChapaFocusW').addEventListener('click', () => {
    state.chapaFocusField = 'w';
    renderChapasView();
  });
  document.getElementById('btnChapaFocusH').addEventListener('click', () => {
    state.chapaFocusField = 'h';
    renderChapasView();
  });
  document.getElementById('btnChapaRotate').addEventListener('click', () => {
    const temp = state.chapaWStr;
    state.chapaWStr = state.chapaHStr;
    state.chapaHStr = temp;
    renderChapasView();
  });

  document.querySelectorAll('[data-chapa-key]').forEach((btn) => {
    btn.addEventListener('click', () => {
      handleChapaKeypad(btn.getAttribute('data-chapa-key'));
    });
  });

  document.getElementById('btnChapaSubmit').addEventListener('click', submitChapaAction);

  // Teclado PIN
  document.querySelectorAll('[data-pin-key]').forEach((btn) => {
    btn.addEventListener('click', () => {
      handlePinKey(btn.getAttribute('data-pin-key'));
    });
  });

  // Loop de 1 segundo para cronômetros das OS em execução e timeout do PIN
  setInterval(() => {
    OS_LIST.forEach((os) => {
      if (os.state === 'running' && !os.isPaused) {
        os.elapsedSeconds += 1;
        const badge = document.querySelector(`[data-live-timer="${os.id}"]`);
        if (badge) badge.textContent = formatDuration(os.elapsedSeconds);
      }
    });

    const anyModalOpen = Boolean(document.querySelector('dialog[open]'));
    if (!state.pinLocked && !anyModalOpen) {
      state.inactivitySeconds = Math.max(0, state.inactivitySeconds - 1);
      document.getElementById('inactivitySeconds').textContent = `${state.inactivitySeconds}s`;
      if (state.inactivitySeconds === 0) {
        state.pinLocked = true;
        renderPinLockScreen();
      }
    }
  }, 1000);
}

// ============================================================================
// MÓDULO HÍBRIDO ACM360 STUDIO (ESTRUTURAS METÁLICAS, BANDEJAS ACM & DXF CNC)
// Baseado na engenharia reversa de ACM360_v1.1.92.rbz (A002, A003, cutplan.js,
// nesting_bundle.js) e integrado ao plugin SketchUp CS_ACM360_v1.0.0.rbz
// ============================================================================

const ACM360_TUBE_PROFILES = [
  { id: 1,  code: 'M15x15', name: 'Metalon 15x15mm',                   w: 15.0,  h: 15.0, wall: 1.2, color: '#2563EB' },
  { id: 2,  code: 'M16x16', name: 'Metalon 16x16mm',                   w: 16.0,  h: 16.0, wall: 1.2, color: '#3B82F6' },
  { id: 3,  code: 'M20x20', name: 'Metalon 20x20mm',                   w: 20.0,  h: 20.0, wall: 1.2, color: '#0284C7' },
  { id: 4,  code: 'M20x30', name: 'Metalon 20x30mm',                   w: 20.0,  h: 30.0, wall: 1.2, color: '#0D9488' },
  { id: 5,  code: 'M20x40', name: 'Metalon 20x40mm',                   w: 20.0,  h: 40.0, wall: 1.2, color: '#059669' },
  { id: 6,  code: 'M25x50', name: 'Metalon 25x50mm',                   w: 25.0,  h: 50.0, wall: 1.5, color: '#16A34A' },
  { id: 7,  code: 'M25x75', name: 'Metalon 25x75mm',                   w: 25.0,  h: 75.0, wall: 1.5, color: '#65A30D' },
  { id: 8,  code: 'M30x30', name: 'Metalon 30x30mm',                   w: 30.0,  h: 30.0, wall: 1.2, color: '#D97706' },
  { id: 9,  code: 'M40x40', name: 'Metalon 40x40mm',                   w: 40.0,  h: 40.0, wall: 1.5, color: '#EA580C' },
  { id: 10, code: 'M50x30', name: 'Metalon 50x30mm',                   w: 50.0,  h: 30.0, wall: 1.5, color: '#DC2626' },
  { id: 11, code: 'M50x50', name: 'Metalon 50x50mm',                   w: 50.0,  h: 50.0, wall: 1.5, color: '#E11D48' },
  { id: 12, code: 'M80x80', name: 'Metalon 80x80mm',                   w: 80.0,  h: 80.0, wall: 2.0, color: '#9333EA' },
  { id: 13, code: 'A25x25', name: 'Alumínio 1" (25,4x25,4mm)',         w: 25.4,  h: 25.4, wall: 1.5, color: '#64748B' },
  { id: 14, code: 'A38x25', name: 'Alumínio 1.1/2x1" (38,1x25,4mm)',   w: 38.1,  h: 25.4, wall: 1.5, color: '#475569' },
  { id: 15, code: 'A38x50', name: 'Alumínio 1.1/2x2" (38,1x50,8mm)',   w: 38.1,  h: 50.8, wall: 1.5, color: '#334155' },
  { id: 16, code: 'A50x25', name: 'Alumínio 2x1" (50,8x25,4mm)',       w: 50.8,  h: 25.4, wall: 1.5, color: '#0891B2' },
  { id: 17, code: 'A50x50', name: 'Alumínio 2x2" (50,8x50,8mm)',       w: 50.8,  h: 50.8, wall: 1.8, color: '#0369A1' },
  { id: 18, code: 'A76x25', name: 'Alumínio 3x1" (76,2x25,4mm)',       w: 76.2,  h: 25.4, wall: 1.8, color: '#4F46E5' },
  { id: 19, code: 'A76x38', name: 'Alumínio 3x1.1/2" (76,2x38,1mm)',   w: 76.2,  h: 38.1, wall: 2.0, color: '#7C3AED' },
  { id: 20, code: 'A101x30', name: 'Alumínio 4x1.1/2" (101,6x30,1mm)', w: 101.6, h: 30.1, wall: 2.0, color: '#C026D3' },
  { id: 21, code: 'A101x50', name: 'Alumínio 4x2" (101,6x50,8mm)',     w: 101.6, h: 50.8, wall: 2.0, color: '#DB2777' }
];

const acmStudioState = {
  subtab: 'frame', // 'frame' | 'trays'
  canvasMode: 'combined', // 'combined' | 'unfold' | 'bars'
  lastModel: null
};

// Configurações M12 (acm360-settings.js): a salva e um rascunho em edição na aba 4
let acmSettings = loadAcmSettings();
let acmSettingsDraft = cloneJson(acmSettings);

function escAcm(v) {
  return String(v == null ? '' : v).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

// Catálogo de fábrica + bitolas próprias, com preço por metro
function getAcmProfiles() {
  const custom = acmSettings.custom_profiles.map((p) => ({
    id: Number(p.id),
    code: String(p.code || ''),
    name: String(p.name || ''),
    w: Number(p.w_mm),
    h: Number(p.h_mm),
    wall: Number(p.wall_mm),
    color: p.color || '#64748B',
    custom: true
  }));
  return [...ACM360_TUBE_PROFILES, ...custom].map((p) => ({ ...p, priceM: acmSettings.profile_prices[String(p.id)] || 0 }));
}

function findAcmProfile(id) {
  const all = getAcmProfiles();
  return all.find((p) => p.id === Number(id)) || all[4];
}

function getOrientedSection(profile, rot) {
  const sMin = Math.min(profile.w, profile.h);
  const sMax = Math.max(profile.w, profile.h);
  return Number(rot) === 2 ? [sMax, sMin] : [sMin, sMax];
}

function readAcmStudioInputs() {
  return {
    widthMm: Math.max(200, Number(document.getElementById('inpAcmFrameW')?.value || 3600)),
    heightMm: Math.max(200, Number(document.getElementById('inpAcmFrameH')?.value || 1800)),
    profileFrameId: Number(document.getElementById('selAcmProfileFrame')?.value || 5),
    profileTravId: Number(document.getElementById('selAcmProfileTrav')?.value || 3),
    cornerType: document.getElementById('selAcmCornerType')?.value || 'encosto',
    rotCorda: Number(document.getElementById('selAcmRotCorda')?.value || 1),
    openSide: Number(document.getElementById('selAcmOpenSide')?.value || 0),
    travV: Math.max(0, Number(document.getElementById('inpAcmTravV')?.value || 2)),
    travH: Math.max(0, Number(document.getElementById('inpAcmTravH')?.value || 1)),
    barStrategy: document.getElementById('selAcmBarStrategy')?.value || 'economia',
    material: document.getElementById('selAcmMaterial')?.value || 'Aço Carbono',
    colorMode: document.getElementById('selAcmColorMode')?.value || 'tipo',
    cols: Math.max(1, Number(document.getElementById('inpAcmGridCols')?.value || 3)),
    rows: Math.max(1, Number(document.getElementById('inpAcmGridRows')?.value || 2)),
    jointMm: Math.max(0, Number(document.getElementById('inpAcmJointMm')?.value || 10)),
    edgeType: document.getElementById('selAcmEdgeType')?.value || 'dobra',
    returnMm: Math.max(0, Number(document.getElementById('inpAcmReturnMm')?.value || 50)),
    abaMm: Math.max(0, Number(document.getElementById('inpAcmAbaMm')?.value || 20)),
    bendFactor: Math.max(0, Number(document.getElementById('inpAcmBendFactor')?.value || activeAcmPreset(acmSettings).bend_factor_mm)),
    acmPreset: document.getElementById('selAcmPreset')?.value || acmSettings.acm_preset,
    fresa: document.getElementById('selAcmFresa')?.value || 'V90',
    cornerTrat: document.getElementById('selAcmCornerTrat')?.value || 'esquadria',
    syncJuntas: Boolean(document.getElementById('chkAcmSyncJuntas')?.checked),
    // Fixação da estrutura na parede (M4): ancoragem, espera (afastador) ou nenhuma
    wallFastener: (() => {
      const v = document.getElementById('selAcmFastenerType')?.value;
      if (v === 'nenhum') return '';
      return ['ancoragem', 'espera'].includes(v) ? v : 'ancoragem'; // valores antigos (F001..F003) caem na ancoragem
    })(),
    fastenerSpacing: Math.max(100, Number(document.getElementById('inpAcmFastenerSpacing')?.value || acmSettings.fastener_spacing_mm)),
    vhbType: document.getElementById('selAcmVhbType')?.value || acmSettings.tape,
    sealant: document.getElementById('selAcmSealant')?.value || 'PU40_CINZA'
  };
}

function computeAcmStudioModel(cfg) {
  const profF = findAcmProfile(cfg.profileFrameId);
  const profT = findAcmProfile(cfg.profileTravId);
  const [fw, fd] = getOrientedSection(profF, cfg.rotCorda);
  const [tw, td] = getOrientedSection(profT, 1);

  const W = cfg.widthMm;
  const H = cfg.heightMm;
  const openLeft = cfg.openSide === 1 || cfg.openSide === 3;
  const openRight = cfg.openSide === 2 || cfg.openSide === 3;
  const espEsq = openLeft ? 0 : fw;
  const espDir = openRight ? 0 : fw;
  const cutDeg = cfg.cornerType === 'esquadria' ? 45 : 0;
  const barMm = acmSettings.bar_mm;
  const kerfMm = acmSettings.kerf_mm;
  const preset = acmSettings.acm_presets.find((p) => p.id === cfg.acmPreset) || activeAcmPreset(acmSettings);
  const tape = findAcmTape(acmSettings, cfg.vhbType);

  const tubes = [];
  const seams = [];

  const pushSegmented = (base) => {
    if (base.len <= barMm + 1e-3) {
      tubes.push(base);
      return;
    }
    const nBars = Math.ceil(base.len / barMm);
    const pts = [];
    if (cfg.barStrategy === 'iguais') {
      const step = base.len / nBars;
      for (let i = 1; i < nBars; i++) pts.push(Math.round(step * i * 10) / 10);
    } else {
      for (let pos = barMm; pos < base.len - 1e-3; pos += barMm) pts.push(pos);
    }
    seams.push({ slot: base.id, axis: base.axis, x: base.x, z: base.z, pts });
    const bounds = [0, ...pts, base.len];
    for (let i = 0; i < bounds.length - 1; i++) {
      const segLen = Math.round((bounds[i + 1] - bounds[i]) * 10) / 10;
      tubes.push({
        ...base,
        id: `${base.id}.${i + 1}`,
        name: `${base.name} (trecho ${i + 1})`,
        x: base.axis === 'x' ? base.x + bounds[i] : base.x,
        z: base.axis === 'z' ? base.z + bounds[i] : base.z,
        w: base.axis === 'x' ? segLen : base.w,
        h: base.axis === 'z' ? segLen : base.h,
        len: segLen,
        cutA: i === 0 ? base.cutA : 0,
        cutB: i === bounds.length - 2 ? base.cutB : 0
      });
    }
  };

  if (!openLeft) {
    const z0 = cfg.cornerType === 'passante_h' ? fw : 0;
    const h0 = cfg.cornerType === 'passante_h' ? H - 2 * fw : H;
    pushSegmented({
      id: 'C1', name: 'Lateral Esquerda', role: 'quadro', axis: 'z',
      x: 0, z: z0, w: fw, h: h0, len: h0,
      profile: profF, cutA: cutDeg, cutB: cutDeg
    });
  }
  if (!openRight) {
    const z0 = cfg.cornerType === 'passante_h' ? fw : 0;
    const h0 = cfg.cornerType === 'passante_h' ? H - 2 * fw : H;
    pushSegmented({
      id: 'C2', name: 'Lateral Direita', role: 'quadro', axis: 'z',
      x: W - fw, z: z0, w: fw, h: h0, len: h0,
      profile: profF, cutA: cutDeg, cutB: cutDeg
    });
  }

  const xSupInf = cfg.cornerType === 'encosto' ? espEsq : 0;
  const wSupInf = cfg.cornerType === 'encosto' ? W - espEsq - espDir : W;

  pushSegmented({
    id: 'INF', name: 'Travessa Inferior', role: 'quadro', axis: 'x',
    x: xSupInf, z: 0, w: wSupInf, h: fw, len: wSupInf,
    profile: profF, cutA: cutDeg, cutB: cutDeg
  });
  pushSegmented({
    id: 'SUP', name: 'Travessa Superior', role: 'quadro', axis: 'x',
    x: xSupInf, z: H - fw, w: wSupInf, h: fw, len: wSupInf,
    profile: profF, cutA: cutDeg, cutB: cutDeg
  });

  // Bandejas ACM da Malha
  const trayW = Math.round(((W - (cfg.cols - 1) * cfg.jointMm) / cfg.cols) * 10) / 10;
  const trayH = Math.round(((H - (cfg.rows - 1) * cfg.jointMm) / cfg.rows) * 10) / 10;

  // Posições dos Montantes Verticais e Travessas Horizontais
  const innerW = W - espEsq - espDir;
  const innerH = H - 2 * fw;
  const vXs = [];
  const hZs = [];

  if (cfg.syncJuntas && cfg.cols > 1) {
    for (let c = 1; c < cfg.cols; c++) {
      const jCenter = c * trayW + (c - 0.5) * cfg.jointMm;
      vXs.push(jCenter - tw / 2);
    }
  } else if (cfg.travV > 0) {
    const stepX = (innerW - cfg.travV * tw) / (cfg.travV + 1);
    for (let i = 1; i <= cfg.travV; i++) {
      vXs.push(espEsq + i * stepX + (i - 1) * tw);
    }
  }

  if (cfg.syncJuntas && cfg.rows > 1) {
    for (let r = 1; r < cfg.rows; r++) {
      const jCenter = r * trayH + (r - 0.5) * cfg.jointMm;
      hZs.push(jCenter - tw / 2);
    }
  } else if (cfg.travH > 0) {
    const stepZ = (innerH - cfg.travH * tw) / (cfg.travH + 1);
    for (let j = 1; j <= cfg.travH; j++) {
      hZs.push(fw + j * stepZ + (j - 1) * tw);
    }
  }

  vXs.forEach((vx, idx) => {
    pushSegmented({
      id: `M${idx + 1}`, name: `Montante ${idx + 1}`, role: 'montantes', axis: 'z',
      x: Math.round(vx * 10) / 10, z: fw, w: tw, h: innerH, len: innerH,
      profile: profT, cutA: 0, cutB: 0
    });
  });

  hZs.forEach((hz, jdx) => {
    pushSegmented({
      id: `T${jdx + 1}`, name: `Travessa ${jdx + 1}`, role: 'travessas', axis: 'x',
      x: espEsq, z: Math.round(hz * 10) / 10, w: innerW, h: tw, len: innerW,
      profile: profT, cutA: 0, cutB: 0
    });
  });

  // Planificação da Bandeja ACM típica
  const k = cfg.bendFactor;
  let extSide = 0;
  let foldsOffsets = [];
  if (cfg.edgeType === 'dobra') {
    extSide = Math.max(0, cfg.returnMm - k);
    foldsOffsets = [extSide];
  } else if (cfg.edgeType === 'dobra_aba') {
    const rEff = Math.max(0, cfg.returnMm - k);
    const aEff = Math.max(0, cfg.abaMm - k);
    extSide = rEff + aEff;
    foldsOffsets = [aEff, aEff + rEff];
  } else if (cfg.edgeType === 'refile') {
    extSide = Math.max(5, cfg.returnMm || acmSettings.refile_tab_mm);
    foldsOffsets = [];
  }

  const flatW = Math.round((trayW + 2 * extSide) * 10) / 10;
  const flatH = Math.round((trayH + 2 * extSide) * 10) / 10;
  const totalTrays = cfg.cols * cfg.rows;
  const singleAreaM2 = (flatW * flatH) / 1000000;
  const totalAcmAreaM2 = Math.round(singleAreaM2 * totalTrays * 100) / 100;

  // FFD 1D Bin Packing de Barras (comprimento da barra nas Configurações)
  const barsByProfile = {};
  tubes.forEach((tb) => {
    const key = tb.profile.name;
    if (!barsByProfile[key]) {
      barsByProfile[key] = { profile: tb.profile, pieces: [], bars: [] };
    }
    const extraA = tb.cutA > 0 ? kerfMm * (1 / Math.cos((tb.cutA * Math.PI) / 180) - 1) : 0;
    const extraB = tb.cutB > 0 ? kerfMm * (1 / Math.cos((tb.cutB * Math.PI) / 180) - 1) : 0;
    const stockMm = Math.round((tb.len + extraA + extraB) * 10) / 10;
    barsByProfile[key].pieces.push({ ...tb, stockMm });
  });

  let totalBarsCount = 0;
  Object.values(barsByProfile).forEach((grp) => {
    const sorted = [...grp.pieces].sort((a, b) => b.stockMm - a.stockMm);
    sorted.forEach((p) => {
      let placed = false;
      for (const bar of grp.bars) {
        if (bar.rem + 1e-3 >= p.stockMm + kerfMm) {
          bar.pieces.push(p);
          bar.used += p.stockMm + kerfMm;
          bar.rem -= p.stockMm + kerfMm;
          placed = true;
          break;
        }
      }
      if (!placed) {
        grp.bars.push({ pieces: [p], used: p.stockMm, rem: Math.max(0, barMm - p.stockMm) });
      }
    });
    totalBarsCount += grp.bars.length;
  });

  const totalLinearM = Math.round((tubes.reduce((acc, t) => acc + t.len, 0) / 1000) * 100) / 100;

  // Cálculo de Ferragens, Colagem VHB e Fixadores (Módulos M3, M4 e M8)
  const trayPerimM = (2 * (trayW + trayH)) / 1000;
  // Mesma regra do relatório (acm360-report.js): reforços a cada ~400 mm quando a bandeja passa de 450 mm
  const stiffenerM = trayH > 450 ? (Math.max(Math.floor(trayW / 400) - 1, 0) * (trayH - 100)) / 1000 : 0;
  const singleTrayTapeM = trayPerimM + stiffenerM;
  const totalTapeM = Math.round(singleTrayTapeM * totalTrays * 10) / 10;
  const vhbRolls = Math.max(1, Math.ceil(totalTapeM / tape.roll_m));
  const primerCans = Math.max(1, Math.ceil(totalTapeM / 100));

  // Fixadores pela mesma regra do plugin (acm360-report.js · estimateFasteners)
  const edge = { type: cfg.edgeType, return_mm: cfg.returnMm };
  const fastenerSettings = { ...acmSettings, fastener_spacing_mm: cfg.fastenerSpacing };
  const trayFix = AcmReport.estimateFasteners({
    trays: [{ w_mm: trayW, h_mm: trayH, thickness_mm: preset.thickness_mm, quantity: 1, edges: { inf: edge, sup: edge, esq: edge, dir: edge } }]
  }, fastenerSettings);
  const fasteners = AcmReport.estimateFasteners({
    trays: [{ w_mm: trayW, h_mm: trayH, thickness_mm: preset.thickness_mm, quantity: totalTrays, edges: { inf: edge, sup: edge, esq: edge, dir: edge } }],
    tubes: tubes.map((tb) => ({ axis: tb.axis, length_mm: tb.len, d_mm: tb.profile === profF ? fd : td })),
    wall: cfg.wallFastener
  }, fastenerSettings);
  const cantoneirasPerTray = trayFix.cantoneiras;
  const totalCantoneiras = fasteners.cantoneiras;
  const totalAnchors = fasteners.anchors;
  const totalScrews = Object.entries(fasteners.items)
    .filter(([name]) => /autobrocante/i.test(name))
    .reduce((acc, [, qty]) => acc + qty, 0);
  const totalSealantTubes = Math.max(1, Math.ceil(((cfg.cols * (cfg.rows - 1) + cfg.rows * (cfg.cols - 1)) * 1.5) / 10));

  const bom = {
    vhbTapeM: totalTapeM,
    vhbRolls,
    tapeName: tape.name,
    tapeRollM: tape.roll_m,
    primerCans,
    cantoneirasPerTray,
    totalCantoneiras,
    totalAnchors,
    fastenerPieces: fasteners.pieces,
    fastenerItems: fasteners.items,
    totalScrews,
    totalSealantTubes
  };

  return {
    cfg,
    W,
    H,
    tubes,
    seams,
    trayW,
    trayH,
    extSide,
    foldsOffsets,
    flatW,
    flatH,
    totalTrays,
    totalAcmAreaM2,
    barsByProfile,
    totalBarsCount,
    totalLinearM,
    bom,
    barMm,
    preset,
    sheetW: acmSettings.acm_sheet_w_mm,
    sheetH: acmSettings.acm_sheet_h_mm
  };
}

function renderAcm360Studio() {
  syncAcmSettingSelects();

  const cfg = readAcmStudioInputs();
  const model = computeAcmStudioModel(cfg);
  acmStudioState.lastModel = model;

  const badge = document.getElementById('badgeAcm360Items');
  if (badge) badge.textContent = `${model.tubes.length + model.totalTrays}`;

  // Atualizar cabeçalho do Stage CAD
  const titleEl = document.getElementById('acmStageTitle');
  const subEl = document.getElementById('acmStageSubtitle');
  if (titleEl && subEl) {
    if (acmStudioState.canvasMode === 'combined') {
      titleEl.textContent = `ESTRUTURA + BANDEJAS ACM · ${model.W} × ${model.H} MM`;
    } else if (acmStudioState.canvasMode === 'unfold') {
      titleEl.textContent = `PLANIFICAÇÃO 2D CNC (P01) · ABERTA ${model.flatW} × ${model.flatH} MM`;
    } else {
      titleEl.textContent = `PLANO DE CORTE 1D DE BARRAS (${model.barMm} MM) · ${model.totalBarsCount} BARRA(S)`;
    }
    subEl.textContent = `${model.totalTrays} bandeja(s) (${model.totalAcmAreaM2} m²) · ${model.tubes.length} tubos (${model.totalLinearM} m) · ${model.totalBarsCount} barra(s) de ${model.barMm} mm`;
  }

  // Renderizar SVG conforme aba ativa
  const canvasBox = document.getElementById('acm360CanvasContainer');
  if (canvasBox) {
    if (acmStudioState.canvasMode === 'combined') {
      canvasBox.innerHTML = renderAcmCombinedSvg(model);
    } else if (acmStudioState.canvasMode === 'unfold') {
      canvasBox.innerHTML = renderAcmUnfoldSvg(model);
    } else {
      canvasBox.innerHTML = renderAcmBarsSvg(model);
    }
  }

  // Renderizar Tabela de Lista de Corte Consolidada
  const tbody = document.getElementById('acmCutlistTbody');
  if (tbody) {
    const rowsHtml = [];
    model.tubes.forEach((tb) => {
      const cutLabel = tb.cutA > 0 || tb.cutB > 0 ? `∠ ${tb.cutA}° / ${tb.cutB}°` : 'Reto 0°';
      rowsHtml.push(`
        <tr>
          <th>${tb.id} · ${tb.name}</th>
          <td>${tb.profile.name} (${cfg.material})</td>
          <td>${cutLabel}</td>
          <td><strong>${tb.len} mm</strong></td>
        </tr>
      `);
    });
    rowsHtml.push(`
      <tr>
        <th>P01..P${String(model.totalTrays).padStart(2, '0')} (${model.totalTrays}×)</th>
        <td>Bandeja ACM ${model.preset.thickness_mm}mm (${escAcm(model.preset.name)}) · Fresa ${cfg.fresa} (${cfg.edgeType})</td>
        <td>Frente ${model.trayW}×${model.trayH}mm · Retorno ${cfg.returnMm}mm</td>
        <td><strong>Planificada: ${model.flatW} × ${model.flatH} mm (${model.totalAcmAreaM2} m²)</strong></td>
      </tr>
    `);
    if (model.bom) {
      rowsHtml.push(`
        <tr>
          <th>Ferragens &amp; Fixadores</th>
          <td>Cantoneiras bandeja → estrutura${cfg.wallFastener ? ' + ' + (cfg.wallFastener === 'espera' ? 'esperas' : 'ancoragens') + ' na parede' : ''}</td>
          <td>${model.bom.totalCantoneiras} cantoneiras · ${model.bom.totalAnchors} ${cfg.wallFastener === 'espera' ? 'esperas' : 'ancoragens'} · ${model.bom.totalScrews} autobrocantes</td>
          <td><strong>Colagem: ${model.bom.vhbRolls} rolos ${escAcm(model.bom.tapeName)} (${model.bom.vhbTapeM}m)</strong></td>
        </tr>
      `);
    }
    tbody.innerHTML = rowsHtml.join('');
  }

  // Renderizar Quadro de Resumo de Ferragens e Materiais (M3, M4, M8)
  const bomBox = document.getElementById('acmBomSummaryBox');
  if (bomBox && model.bom) {
    const b = model.bom;
    bomBox.innerHTML = `
      <div style="display:grid; grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)); gap: 8px;">
        <div style="background:rgba(0,0,0,0.3); padding:8px 10px; border-radius:6px; border:1px solid #444;">
          <div style="font-size:0.72rem; color:#94A3B8; font-weight:700;">${escAcm(b.tapeName).toUpperCase()}</div>
          <strong style="color:#FBBF24; font-size:1.05rem;">${b.vhbRolls} rolos</strong>
          <div style="font-size:0.7rem; color:#64748B;">(${b.vhbTapeM} m · rolo ${b.tapeRollM} m)</div>
        </div>
        <div style="background:rgba(0,0,0,0.3); padding:8px 10px; border-radius:6px; border:1px solid #444;">
          <div style="font-size:0.72rem; color:#94A3B8; font-weight:700;">PRIMER 3M AP111</div>
          <strong style="color:#38BDF8; font-size:1.05rem;">${b.primerCans} frasco(s)</strong>
          <div style="font-size:0.7rem; color:#64748B;">(250 ml p/ adesão)</div>
        </div>
        <div style="background:rgba(0,0,0,0.3); padding:8px 10px; border-radius:6px; border:1px solid #444;">
          <div style="font-size:0.72rem; color:#94A3B8; font-weight:700;">CANTONEIRAS</div>
          <strong style="color:#34D399; font-size:1.05rem;">${b.totalCantoneiras} un</strong>
          <div style="font-size:0.7rem; color:#64748B;">(${b.cantoneirasPerTray} un / bandeja)</div>
        </div>
        <div style="background:rgba(0,0,0,0.3); padding:8px 10px; border-radius:6px; border:1px solid #444;">
          <div style="font-size:0.72rem; color:#94A3B8; font-weight:700;">AUTOBROCANTES</div>
          <strong style="color:#F87171; font-size:1.05rem;">${b.totalScrews} un</strong>
          <div style="font-size:0.7rem; color:#64748B;">(Autobrocante vedação)</div>
        </div>
        <div style="background:rgba(0,0,0,0.3); padding:8px 10px; border-radius:6px; border:1px solid #444;">
          <div style="font-size:0.72rem; color:#94A3B8; font-weight:700;">SELANTE PU40</div>
          <strong style="color:#C084FC; font-size:1.05rem;">${b.totalSealantTubes} tubo(s)</strong>
          <div style="font-size:0.7rem; color:#64748B;">(Cartucho 400g juntas)</div>
        </div>
      </div>
    `;
  }
}

function resolveWebTubeColor(tb, colorMode, idx) {
  if (colorMode === 'unica') return '#94A3B8';
  if (colorMode === 'comprimento') {
    const pal = ['#38BDF8', '#34D399', '#FBBF24', '#F87171', '#A78BFA', '#F472B6'];
    return pal[Math.round(tb.len) % pal.length];
  }
  return tb.profile.color || '#38BDF8';
}

function renderAcmCombinedSvg(m) {
  const pad = 42;
  const vbW = 680;
  const vbH = 310;
  const scale = Math.min((vbW - pad * 2) / m.W, (vbH - pad * 2) / m.H);
  const drawW = m.W * scale;
  const drawH = m.H * scale;
  const ox = (vbW - drawW) / 2;
  const oy = (vbH - drawH) / 2;

  let tubesSvg = '';
  m.tubes.forEach((tb, idx) => {
    const x = ox + tb.x * scale;
    const y = oy + (m.H - tb.z - tb.h) * scale;
    const w = Math.max(2.5, tb.w * scale);
    const h = Math.max(2.5, tb.h * scale);
    const col = resolveWebTubeColor(tb, m.cfg.colorMode, idx);
    tubesSvg += `<rect x="${x.toFixed(1)}" y="${y.toFixed(1)}" width="${w.toFixed(1)}" height="${h.toFixed(1)}" fill="${col}" stroke="#0F172A" stroke-width="1"/>`;
  });

  // Bandejas ACM translúcidas sobre a estrutura para visualizar juntas + apoio
  let traysSvg = '';
  for (let r = 0; r < m.cfg.rows; r++) {
    for (let c = 0; c < m.cfg.cols; c++) {
      const idx = r * m.cfg.cols + c + 1;
      const tx = ox + c * (m.trayW + m.cfg.jointMm) * scale;
      const ty = oy + (m.H - (r + 1) * m.trayH - r * m.cfg.jointMm) * scale;
      const tw = m.trayW * scale;
      const th = m.trayH * scale;
      traysSvg += `
        <rect x="${tx.toFixed(1)}" y="${ty.toFixed(1)}" width="${tw.toFixed(1)}" height="${th.toFixed(1)}"
          fill="rgba(220, 38, 38, 0.14)" stroke="#F87171" stroke-width="1.4" stroke-dasharray="5 3"/>
        <text x="${(tx + tw / 2).toFixed(1)}" y="${(ty + th / 2 + 4).toFixed(1)}"
          text-anchor="middle" fill="#FDE047" font-family="monospace" font-size="11" font-weight="800">
          P${String(idx).padStart(2, '0')} (${m.trayW}×${m.trayH})
        </text>
      `;
    }
  }

  return `
    <svg viewBox="0 0 ${vbW} ${vbH}" width="100%" height="100%" role="img" aria-label="Vista combinada da estrutura metálica e bandejas de ACM">
      <rect x="0" y="0" width="${vbW}" height="${vbH}" fill="#090D16" rx="8"/>
      ${tubesSvg}
      ${traysSvg}
      <text x="${ox + drawW / 2}" y="${oy - 12}" text-anchor="middle" fill="#38BDF8" font-family="monospace" font-size="12" font-weight="800">
        ↔ LARGURA TOTAL: ${m.W} mm (${m.cfg.cols} col × ${m.trayW} mm | junta ${m.cfg.jointMm} mm)
      </text>
      <text x="${ox + drawW + 12}" y="${oy + drawH / 2}" fill="#34D399" font-family="monospace" font-size="11" font-weight="800">
        ↕ ${m.H} mm
      </text>
    </svg>
  `;
}

function renderAcmUnfoldSvg(m) {
  const pad = 38;
  const vbW = 680;
  const vbH = 310;
  const scale = Math.min((vbW - pad * 2) / m.flatW, (vbH - pad * 2) / m.flatH);
  const dw = m.flatW * scale;
  const dh = m.flatH * scale;
  const ox = (vbW - dw) / 2;
  const oy = (vbH - dh) / 2;
  const ext = m.extSide * scale;
  const fw = m.trayW * scale;
  const fh = m.trayH * scale;

  // Polígono de corte com entalhe nos 4 cantos (ACM_CORTE vermelho)
  const pts = [
    [ox + ext, oy],
    [ox + ext + fw, oy],
    [ox + ext + fw, oy + ext],
    [ox + dw, oy + ext],
    [ox + dw, oy + ext + fh],
    [ox + ext + fw, oy + ext + fh],
    [ox + ext + fw, oy + dh],
    [ox + ext, oy + dh],
    [ox + ext, oy + ext + fh],
    [ox, oy + ext + fh],
    [ox, oy + ext],
    [ox + ext, oy + ext]
  ].map((p) => `${p[0].toFixed(1)},${p[1].toFixed(1)}`).join(' ');

  let foldsSvg = '';
  if (m.extSide > 0) {
    // Retângulo interno de vinco principal (ACM_VINCO magenta)
    foldsSvg += `
      <rect x="${(ox + ext).toFixed(1)}" y="${(oy + ext).toFixed(1)}" width="${fw.toFixed(1)}" height="${fh.toFixed(1)}"
        fill="none" stroke="#EC4899" stroke-width="2" stroke-dasharray="6 4"/>
    `;
    if (m.foldsOffsets.length === 2) {
      const aPx = m.foldsOffsets[0] * scale;
      foldsSvg += `
        <line x1="${(ox + aPx).toFixed(1)}" y1="${(oy + ext).toFixed(1)}" x2="${(ox + aPx).toFixed(1)}" y2="${(oy + ext + fh).toFixed(1)}" stroke="#EC4899" stroke-width="1.4" stroke-dasharray="4 3"/>
        <line x1="${(ox + dw - aPx).toFixed(1)}" y1="${(oy + ext).toFixed(1)}" x2="${(ox + dw - aPx).toFixed(1)}" y2="${(oy + ext + fh).toFixed(1)}" stroke="#EC4899" stroke-width="1.4" stroke-dasharray="4 3"/>
        <line x1="${(ox + ext).toFixed(1)}" y1="${(oy + aPx).toFixed(1)}" x2="${(ox + ext + fw).toFixed(1)}" y2="${(oy + aPx).toFixed(1)}" stroke="#EC4899" stroke-width="1.4" stroke-dasharray="4 3"/>
        <line x1="${(ox + ext).toFixed(1)}" y1="${(oy + dh - aPx).toFixed(1)}" x2="${(ox + ext + fw).toFixed(1)}" y2="${(oy + dh - aPx).toFixed(1)}" stroke="#EC4899" stroke-width="1.4" stroke-dasharray="4 3"/>
      `;
    }
  }

  return `
    <svg viewBox="0 0 ${vbW} ${vbH}" width="100%" height="100%" role="img" aria-label="Planificação 2D da bandeja ACM com camadas DXF">
      <rect x="0" y="0" width="${vbW}" height="${vbH}" fill="#090D16" rx="8"/>
      <polygon points="${pts}" fill="#1E293B" stroke="#EF4444" stroke-width="2.4"/>
      ${foldsSvg}
      <text x="${ox + dw / 2}" y="${oy + dh / 2 - 4}" text-anchor="middle" fill="#F8FAFC" font-family="monospace" font-size="13" font-weight="800">
        P01 · FACE ${m.trayW} × ${m.trayH} MM
      </text>
      <text x="${ox + dw / 2}" y="${oy + dh / 2 + 15}" text-anchor="middle" fill="#F472B6" font-family="monospace" font-size="11" font-weight="700">
        ABERTA: ${m.flatW} × ${m.flatH} MM (Fator dobra: -${m.cfg.bendFactor}mm)
      </text>
      <text x="${ox + dw / 2}" y="${oy - 12}" text-anchor="middle" fill="#EF4444" font-family="monospace" font-size="11" font-weight="800">
        ■ VERMELHO: LAYER ACM_CORTE   |   --- MAGENTA: LAYER ACM_VINCO (${m.cfg.fresa})
      </text>
    </svg>
  `;
}

function renderAcmBarsSvg(m) {
  const vbW = 680;
  const vbH = 310;
  const barMm = m.barMm;
  const padX = 28;
  const barW = vbW - padX * 2 - 90;
  let y = 34;
  let barsHtml = '';

  Object.values(m.barsByProfile).forEach((grp) => {
    barsHtml += `<text x="${padX}" y="${y}" fill="#38BDF8" font-family="monospace" font-size="11.5" font-weight="800">${escAcm(grp.profile.name)} (${grp.bars.length} barra[s] de ${barMm}mm)</text>`;
    y += 8;
    grp.bars.slice(0, 5).forEach((bar, bIdx) => {
      barsHtml += `<rect x="${padX}" y="${y}" width="${barW}" height="22" fill="#1E293B" stroke="#475569" rx="3"/>`;
      let curX = padX;
      bar.pieces.forEach((p, pIdx) => {
        const pw = Math.max(8, (p.stockMm / barMm) * barW);
        const col = pIdx % 2 === 0 ? grp.profile.color : '#0284C7';
        barsHtml += `
          <rect x="${curX.toFixed(1)}" y="${y}" width="${pw.toFixed(1)}" height="22" fill="${col}" stroke="#0F172A" stroke-width="1"/>
          <text x="${(curX + pw / 2).toFixed(1)}" y="${y + 15}" text-anchor="middle" fill="#FFFFFF" font-family="monospace" font-size="9.5" font-weight="800">
            ${p.id}:${p.len}${p.cutA > 0 ? '∠' : ''}
          </text>
        `;
        curX += pw;
      });
      barsHtml += `<text x="${padX + barW + 8}" y="${y + 15}" fill="#94A3B8" font-family="monospace" font-size="10.5" font-weight="700">Sobra ${Math.round(bar.rem)}mm</text>`;
      y += 30;
    });
    y += 8;
  });

  return `
    <svg viewBox="0 0 ${vbW} ${vbH}" width="100%" height="100%" role="img" aria-label="Plano de corte de barras 1D FFD ${barMm}mm">
      <rect x="0" y="0" width="${vbW}" height="${vbH}" fill="#090D16" rx="8"/>
      ${barsHtml}
    </svg>
  `;
}

function downloadAcm360Dxf() {
  const m = acmStudioState.lastModel || computeAcmStudioModel(readAcmStudioInputs());
  const w = m.flatW;
  const h = m.flatH;
  const ext = m.extSide;
  const fw = m.trayW;
  const fh = m.trayH;

  const dxfLine = (layer, x1, y1, x2, y2) =>
    `0\nLINE\n8\n${layer}\n10\n${x1.toFixed(4)}\n20\n${y1.toFixed(4)}\n30\n0.0\n11\n${x2.toFixed(4)}\n21\n${y2.toFixed(4)}\n31\n0.0\n`;

  let dxf = `999\nDXF generated by CS_ACM360 Studio - AC1009\n0\nSECTION\n2\nHEADER\n9\n$ACADVER\n1\nAC1009\n9\n$INSUNITS\n70\n4\n0\nENDSEC\n`;
  dxf += `0\nSECTION\n2\nTABLES\n0\nTABLE\n2\nLAYER\n70\n5\n`;
  dxf += `0\nLAYER\n2\nACM_CHAPA\n70\n0\n62\n7\n6\nCONTINUOUS\n`;
  dxf += `0\nLAYER\n2\nACM_CORTE\n70\n0\n62\n1\n6\nCONTINUOUS\n`;
  dxf += `0\nLAYER\n2\nACM_VINCO\n70\n0\n62\n174\n6\nCONTINUOUS\n`;
  dxf += `0\nLAYER\n2\nACM_DIRECAO\n70\n0\n62\n8\n6\nCONTINUOUS\n`;
  dxf += `0\nLAYER\n2\nACM_ETIQUETAS\n70\n0\n62\n7\n6\nCONTINUOUS\n`;
  dxf += `0\nENDTAB\n0\nENDSEC\n0\nSECTION\n2\nENTITIES\n`;

  // Contorno da Chapa padrão (Configurações)
  const sw = m.sheetW;
  const sh = m.sheetH;
  dxf += dxfLine('ACM_CHAPA', 0, 0, sw, 0);
  dxf += dxfLine('ACM_CHAPA', sw, 0, sw, sh);
  dxf += dxfLine('ACM_CHAPA', sw, sh, 0, sh);
  dxf += dxfLine('ACM_CHAPA', 0, sh, 0, 0);

  // Peça planificada com entalhes de canto (ACM_CORTE)
  const ox = 15;
  const oy = 15;
  const pts = [
    [ox + ext, oy],
    [ox + ext + fw, oy],
    [ox + ext + fw, oy + ext],
    [ox + w, oy + ext],
    [ox + w, oy + ext + fh],
    [ox + ext + fw, oy + ext + fh],
    [ox + ext + fw, oy + h],
    [ox + ext, oy + h],
    [ox + ext, oy + ext + fh],
    [ox, oy + ext + fh],
    [ox, oy + ext],
    [ox + ext, oy + ext]
  ];
  for (let i = 0; i < pts.length; i++) {
    const p1 = pts[i];
    const p2 = pts[(i + 1) % pts.length];
    dxf += dxfLine('ACM_CORTE', p1[0], p1[1], p2[0], p2[1]);
  }

  // Linhas de vinco (ACM_VINCO)
  if (ext > 0) {
    dxf += dxfLine('ACM_VINCO', ox + ext, oy + ext, ox + ext + fw, oy + ext);
    dxf += dxfLine('ACM_VINCO', ox + ext + fw, oy + ext, ox + ext + fw, oy + ext + fh);
    dxf += dxfLine('ACM_VINCO', ox + ext + fw, oy + ext + fh, ox + ext, oy + ext + fh);
    dxf += dxfLine('ACM_VINCO', ox + ext, oy + ext + fh, ox + ext, oy + ext);
  }

  dxf += `0\nTEXT\n8\nACM_ETIQUETAS\n10\n${(ox + w / 2).toFixed(2)}\n20\n${(oy + h / 2).toFixed(2)}\n30\n0.0\n40\n24.0\n1\nP01 (${w}x${h}mm)\n0\nENDSEC\n0\nEOF\n`;

  const blob = new Blob([dxf], { type: 'application/dxf' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `ACM360_Plano_Corte_${m.W}x${m.H}mm.dxf`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
  showToast(`✓ DXF CNC exportado (Camadas: ACM_CHAPA, ACM_CORTE, ACM_VINCO, ACM_ETIQUETAS)`);
}

// M8: o relatório usa o mesmo acm360-report.js do plugin SketchUp
function buildAcm360Report() {
  const m = acmStudioState.lastModel || computeAcmStudioModel(readAcmStudioInputs());
  const familyOf = (p) => {
    const custom = acmSettings.custom_profiles.find((c) => Number(c.id) === p.id);
    if (custom) return custom.family;
    return p.code.startsWith('A') ? 'aluminio' : 'metalon';
  };
  const profiles = getAcmProfiles().map((p) => ({
    id: p.id, name: p.name, family: familyOf(p), w_mm: p.w, h_mm: p.h, wall_mm: p.wall, price_m: p.priceM
  }));
  const tubes = m.tubes.map((tb) => ({
    id: tb.id,
    name: tb.name,
    frame: `Fachada ${m.W}x${m.H} mm`,
    profile_id: tb.profile.id,
    profile_name: tb.profile.name,
    wall_mm: tb.profile.wall,
    material: familyOf(tb.profile) === 'aluminio' ? 'Alumínio' : 'Aço Carbono',
    length_mm: tb.len,
    cut_a_deg: tb.cutA,
    cut_b_deg: tb.cutB
  }));
  const now = new Date();
  return AcmReport.buildAcmReport({
    projectName: `Fachada ACM ${m.W}x${m.H} mm`,
    date: `${now.toLocaleDateString('pt-BR')} ${now.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })}`,
    tubes,
    trays: [{
      code: 'P01-P' + String(m.totalTrays).padStart(2, '0'), name: `Bandeja ${m.trayW}x${m.trayH} mm`, quantity: m.totalTrays,
      front_w_mm: m.trayW, front_h_mm: m.trayH, flat_w_mm: m.flatW, flat_h_mm: m.flatH, thickness_mm: m.preset.thickness_mm
    }],
    fasteners: {
      ...m.bom.fastenerPieces,
      ...m.bom.fastenerItems,
      'Selante PU40 (cartucho 400 g)': m.bom.totalSealantTubes
    }
  }, acmSettings, profiles);
}

function downloadAcmBlob(data, type, filename) {
  const url = URL.createObjectURL(new Blob([data], { type }));
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

function downloadAcm360Csv() {
  const r = buildAcm360Report();
  downloadAcmBlob('\uFEFF' + AcmReport.reportToCsv(r), 'text/csv;charset=utf-8;', `ACM360_Relatorio_${r.project_name.replace(/\W+/g, '_')}.csv`);
  showToast('✓ Lista de corte e plano de barras exportados em CSV!');
}

function downloadAcm360Xlsx() {
  const r = buildAcm360Report();
  downloadAcmBlob(AcmReport.reportToXlsx(r), 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', `ACM360_Relatorio_${r.project_name.replace(/\W+/g, '_')}.xlsx`);
  showToast('✓ Relatório exportado em Excel (XLSX)!');
}

function printAcm360Report() {
  const w = window.open('', '_blank');
  if (!w) {
    showToast('Permita pop-ups deste site para imprimir o relatório.');
    return;
  }
  w.document.write(AcmReport.reportToHtml(buildAcm360Report(), acmSettings));
  w.document.close();
}

function createErpOsFromAcm360() {
  const m = acmStudioState.lastModel || computeAcmStudioModel(readAcmStudioInputs());
  const newId = `OS-${45 + OS_LIST.length}`;
  const profFrame = findAcmProfile(m.cfg.profileFrameId);
  const newOs = {
    id: newId,
    client: 'Projeto ACM360 Studio',
    title: `Fachada ACM (${m.totalTrays} Bandejas) + Gradil ${profFrame.name}`,
    dimensions: `${(m.W / 1000).toFixed(2).replace('.', ',')} × ${(m.H / 1000).toFixed(2).replace('.', ',')} m`,
    qty: '1 conj',
    deadline: '28/10/26',
    tag: 'fachada acm360',
    isLate: false,
    sector: 'CNC',
    state: 'queue',
    assignedTo: [],
    elapsedSeconds: 0,
    isPaused: false,
    pauseReason: '',
    obs: `Gerado pelo ACM360 Studio: ${m.totalTrays} bandejas planificadas (${m.flatW}×${m.flatH}mm, fresa ${m.cfg.fresa}) + ${m.tubes.length} tubos (${m.totalBarsCount} barras de ${m.barMm}mm, corte ${m.cfg.cornerType}). Fixadores: ${m.bom.totalCantoneiras} cantoneiras, ${m.bom.totalAnchors} ${m.cfg.wallFastener === 'espera' ? 'esperas' : 'ancoragens'}, ${m.bom.vhbRolls} rolos ${m.bom.tapeName}.`,
    croquiType: 'fachada',
    stages: [
      { name: 'Criação/Projetos', status: 'done', by: 'ACM360 Studio', duration: 'Automático' },
      { name: 'CNC', status: 'current', by: '—', duration: '—' },
      { name: 'Serralheria', status: 'todo', by: '—', duration: '—' },
      { name: 'Montagem', status: 'todo', by: '—', duration: '—' },
      { name: 'Instalação', status: 'todo', by: '—', duration: '—' }
    ],
    materials: [
      { matId: 'mat-metalon-20', name: `${profFrame.name} (${m.totalBarsCount} barras de ${m.barMm}mm)`, predicted: m.totalLinearM, used: 0, unit: 'ml' },
      { matId: 'mat-adesivo-avery', name: `Chapas ACM ${m.preset.thickness_mm}mm Planificadas (${m.totalTrays} pçs)`, predicted: m.totalAcmAreaM2, used: 0, unit: 'm²' },
      { matId: 'mat-vhb-tape', name: `${m.bom.tapeName} (${m.bom.vhbRolls} rolos de ${m.bom.tapeRollM}m)`, predicted: m.bom.vhbTapeM, used: 0, unit: 'ml' },
      ...Object.entries({ ...m.bom.fastenerPieces, ...m.bom.fastenerItems }).map(([name, qty], i) => ({
        matId: `mat-fix-${i + 1}`, name, predicted: qty, used: 0, unit: 'un'
      }))
    ]
  };
  OS_LIST.unshift(newOs);
  state.activeView = 'os';
  state.selectedSector = 'Todos';
  renderHeader();
  renderSectorBar();
  renderOSBoard();
  showToast(`🚀 ${newId} criada no Quadro de Produção com ${m.totalBarsCount} barra(s), ${m.totalTrays} bandeja(s) ACM e ${m.bom.vhbRolls} rolos VHB!`);
}

// ============================================================================
// M12 · CONFIGURAÇÕES DO ACM360 STUDIO
// ============================================================================

function fillAcmSelect(sel, items, preferred) {
  if (!sel) return;
  const keep = sel.value || String(preferred);
  const signature = items.map((i) => `${i.value}:${i.label}`).join('|');
  if (sel.dataset.signature !== signature) {
    sel.innerHTML = '';
    items.forEach((i) => sel.add(new Option(i.label, i.value)));
    sel.dataset.signature = signature;
  }
  sel.value = items.some((i) => String(i.value) === keep) ? keep : String(preferred);
}

// Mantém os seletores do Studio de acordo com bitolas, chapas e fitas cadastradas
function syncAcmSettingSelects() {
  const profiles = getAcmProfiles().map((p) => ({ value: p.id, label: p.name }));
  fillAcmSelect(document.getElementById('selAcmProfileFrame'), profiles, 5);
  fillAcmSelect(document.getElementById('selAcmProfileTrav'), profiles, 3);
  fillAcmSelect(document.getElementById('selAcmPreset'), acmSettings.acm_presets.map((p) => ({ value: p.id, label: p.name })), acmSettings.acm_preset);
  fillAcmSelect(document.getElementById('selAcmVhbType'), acmSettings.tapes.map((t) => ({ value: t.id, label: t.name })), acmSettings.tape);
  const lbl = document.getElementById('lblAcmBarMm');
  if (lbl) lbl.textContent = String(acmSettings.bar_mm);
}

// Preenche os campos do projeto com os padrões salvos (ao abrir e ao salvar configurações)
function applyAcmSettingsDefaults() {
  syncAcmSettingSelects();
  const set = (id, value) => {
    const el = document.getElementById(id);
    if (el) el.value = String(value);
  };
  set('inpAcmReturnMm', acmSettings.default_return_mm);
  set('inpAcmAbaMm', acmSettings.default_aba_mm);
  set('inpAcmJointMm', acmSettings.default_joint_mm);
  set('inpAcmFastenerSpacing', acmSettings.fastener_spacing_mm);
  set('selAcmFresa', acmSettings.fresa_type);
  set('selAcmBarStrategy', acmSettings.seam_strategy);
  set('selAcmColorMode', acmSettings.color_mode);
  set('selAcmPreset', acmSettings.acm_preset);
  set('selAcmVhbType', acmSettings.tape);
  set('inpAcmBendFactor', activeAcmPreset(acmSettings).bend_factor_mm);
}

function renderAcmSettingsPanel() {
  const d = acmSettingsDraft;
  document.querySelectorAll('[data-acm-setting]').forEach((el) => {
    const key = el.getAttribute('data-acm-setting');
    if (key === 'acm_preset') {
      fillAcmSelect(el, d.acm_presets.map((p) => ({ value: p.id, label: p.name })), d.acm_preset);
      el.value = d.acm_preset;
    } else if (key === 'tape') {
      fillAcmSelect(el, d.tapes.map((t) => ({ value: t.id, label: t.name })), d.tape);
      el.value = d.tape;
    } else if (d[key] !== undefined) {
      el.value = String(d[key]);
    }
  });

  const num = (list, idx, field, val, step = 'any') =>
    `<input type="number" step="${step}" data-list="${list}" data-idx="${idx}" data-field="${field}" value="${escAcm(val)}" aria-label="${field}">`;
  const txt = (list, idx, field, val) =>
    `<input type="text" data-list="${list}" data-idx="${idx}" data-field="${field}" value="${escAcm(val)}" aria-label="${field}">`;
  const del = (list, idx) =>
    `<button type="button" class="acm-action-btn secondary" data-acm-del="${list}" data-idx="${idx}" aria-label="Remover">×</button>`;
  const price = (id) =>
    `<input type="number" step="0.01" min="0" data-price-id="${id}" value="${escAcm(d.profile_prices[String(id)] || '')}" aria-label="Preço por metro">`;

  document.getElementById('setAcmPresetsBody').innerHTML = d.acm_presets.map((p, i) => `
    <tr><td>${txt('acm_presets', i, 'name', p.name)}</td><td>${num('acm_presets', i, 'thickness_mm', p.thickness_mm, '0.5')}</td>
    <td>${num('acm_presets', i, 'bend_factor_mm', p.bend_factor_mm, '0.1')}</td><td>${del('acm_presets', i)}</td></tr>`).join('');

  document.getElementById('setAcmTapesBody').innerHTML = d.tapes.map((t, i) => `
    <tr><td>${txt('tapes', i, 'name', t.name)}</td><td>${num('tapes', i, 'width_mm', t.width_mm)}</td>
    <td>${num('tapes', i, 'roll_m', t.roll_m)}</td><td>${num('tapes', i, 'price', t.price, '0.01')}</td><td>${del('tapes', i)}</td></tr>`).join('');

  const rows = ACM360_TUBE_PROFILES.map((p) => `
    <tr><td>${escAcm(p.name)}</td><td>${price(p.id)}</td><td>${p.w} × ${p.h} × ${p.wall}</td><td></td></tr>`);
  d.custom_profiles.forEach((p, i) => {
    rows.push(`
      <tr><td>${txt('custom_profiles', i, 'name', p.name)}</td><td>${price(p.id)}</td>
      <td style="display:flex; gap:4px;">${num('custom_profiles', i, 'w_mm', p.w_mm)}${num('custom_profiles', i, 'h_mm', p.h_mm)}${num('custom_profiles', i, 'wall_mm', p.wall_mm, '0.1')}
      <input type="color" data-list="custom_profiles" data-idx="${i}" data-field="color" value="${escAcm(p.color || '#64748B')}" aria-label="Cor"></td>
      <td>${del('custom_profiles', i)}</td></tr>`);
  });
  document.getElementById('setAcmProfilesBody').innerHTML = rows.join('');

  const logo = document.getElementById('imgAcmLogoPreview');
  if (logo) {
    logo.hidden = !d.company_logo;
    if (d.company_logo) logo.src = d.company_logo;
  }
  const btnRemove = document.getElementById('btnAcmLogoRemove');
  if (btnRemove) btnRemove.hidden = !d.company_logo;
}

function onAcmSettingsInput(el) {
  const d = acmSettingsDraft;
  const value = el.type === 'number' ? Number(el.value) : el.value;
  if (el.hasAttribute('data-price-id')) {
    d.profile_prices[el.getAttribute('data-price-id')] = Number(el.value) || 0;
  } else if (el.hasAttribute('data-list')) {
    const item = d[el.getAttribute('data-list')][Number(el.getAttribute('data-idx'))];
    if (!item) return;
    item[el.getAttribute('data-field')] = value;
    if (el.getAttribute('data-field') === 'name') {
      fillAcmSelect(document.getElementById('setAcmPresetDefault'), d.acm_presets.map((p) => ({ value: p.id, label: p.name })), d.acm_preset);
      fillAcmSelect(document.getElementById('setAcmTapeDefault'), d.tapes.map((t) => ({ value: t.id, label: t.name })), d.tape);
    }
  } else if (el.hasAttribute('data-acm-setting')) {
    d[el.getAttribute('data-acm-setting')] = value;
  }
}

function addAcmSettingsRow(list) {
  const d = acmSettingsDraft;
  const stamp = Date.now().toString(36);
  if (list === 'acm_presets') {
    d.acm_presets.push({ id: `p_${stamp}`, name: `Fornecedor ${d.acm_presets.length + 1}`, thickness_mm: 3, bend_factor_mm: 1.5 });
  } else if (list === 'tapes') {
    d.tapes.push({ id: `t_${stamp}`, name: `Fita ${d.tapes.length + 1}`, width_mm: 19, roll_m: 33, price: 0 });
  } else if (list === 'custom_profiles') {
    const nextId = Math.max(99, ...d.custom_profiles.map((p) => Number(p.id) || 0)) + 1;
    d.custom_profiles.push({ id: nextId, code: `X${nextId}`, name: 'Bitola própria', family: 'metalon', w_mm: 30, h_mm: 30, wall_mm: 1.2, color: '#64748B' });
  }
  renderAcmSettingsPanel();
}

function removeAcmSettingsRow(list, idx) {
  const d = acmSettingsDraft;
  if (list !== 'custom_profiles' && d[list].length <= 1) {
    showToast('É preciso manter pelo menos um item.');
    return;
  }
  const [removed] = d[list].splice(idx, 1);
  if (list === 'custom_profiles' && removed) delete d.profile_prices[String(removed.id)];
  if (list === 'acm_presets' && removed?.id === d.acm_preset) d.acm_preset = d.acm_presets[0].id;
  if (list === 'tapes' && removed?.id === d.tape) d.tape = d.tapes[0].id;
  renderAcmSettingsPanel();
}

function commitAcmSettings(next, message) {
  acmSettings = normalizeAcmSettings(next);
  acmSettingsDraft = cloneJson(acmSettings);
  const stored = saveAcmSettings(acmSettings);
  applyAcmSettingsDefaults();
  renderAcmSettingsPanel();
  renderAcm360Studio();
  showToast(stored ? message : `${message} (só nesta sessão: o navegador bloqueou o armazenamento)`);
}

function setupAcmSettingsListeners() {
  const panel = document.getElementById('acmPanelSettingsControls');
  if (!panel) return;

  const handler = (e) => {
    const el = e.target;
    if (el.matches('input, select') && el.type !== 'file') onAcmSettingsInput(el);
  };
  panel.addEventListener('input', handler);
  panel.addEventListener('change', handler);
  panel.addEventListener('click', (e) => {
    const add = e.target.closest('[data-acm-add]');
    const del = e.target.closest('[data-acm-del]');
    if (add) addAcmSettingsRow(add.getAttribute('data-acm-add'));
    if (del) removeAcmSettingsRow(del.getAttribute('data-acm-del'), Number(del.getAttribute('data-idx')));
  });

  document.getElementById('setAcmLogo')?.addEventListener('change', (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    if (file.size > ACM360_LOGO_MAX_BYTES) {
      showToast('Logo maior que 300 KB. Reduza a imagem e tente de novo.');
      e.target.value = '';
      return;
    }
    const reader = new FileReader();
    reader.onload = () => {
      acmSettingsDraft.company_logo = String(reader.result);
      renderAcmSettingsPanel();
    };
    reader.readAsDataURL(file);
  });
  document.getElementById('btnAcmLogoRemove')?.addEventListener('click', () => {
    acmSettingsDraft.company_logo = '';
    document.getElementById('setAcmLogo').value = '';
    renderAcmSettingsPanel();
  });

  document.getElementById('btnAcmSettingsSave')?.addEventListener('click', () => {
    commitAcmSettings(acmSettingsDraft, '💾 Configurações salvas');
  });
  document.getElementById('btnAcmSettingsReset')?.addEventListener('click', () => {
    commitAcmSettings({}, '↺ Configurações voltaram ao padrão de fábrica');
  });
  document.getElementById('btnAcmSettingsExport')?.addEventListener('click', () => {
    const blob = new Blob([JSON.stringify(exportAcmSettingsPayload(acmSettings), null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'CS_ACM360_config.json';
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  });
  document.getElementById('inpAcmSettingsImport')?.addEventListener('change', (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      try {
        commitAcmSettings(importAcmSettingsPayload(JSON.parse(String(reader.result))), `📥 Configurações importadas de ${file.name}`);
      } catch (err) {
        showToast(`Erro ao importar configurações: ${err.message}`);
      }
      e.target.value = '';
    };
    reader.readAsText(file);
  });

  document.getElementById('selAcmPreset')?.addEventListener('change', (e) => {
    const p = acmSettings.acm_presets.find((x) => x.id === e.target.value);
    if (p) document.getElementById('inpAcmBendFactor').value = String(p.bend_factor_mm);
  });
}

function setupAcm360StudioListeners() {
  const tabFrame = document.getElementById('tabAcmModeFrame');
  const tabTrays = document.getElementById('tabAcmModeTrays');
  const tabBOM = document.getElementById('tabAcmModeBOM');
  const tabSettings = document.getElementById('tabAcmModeSettings');
  const panelFrame = document.getElementById('acmPanelFrameControls');
  const panelTrays = document.getElementById('acmPanelTrayControls');
  const panelBOM = document.getElementById('acmPanelBOMControls');
  const panelSettings = document.getElementById('acmPanelSettingsControls');

  const switchTab = (activeTab, activePanel) => {
    [tabFrame, tabTrays, tabBOM, tabSettings].forEach((t) => {
      if (t) t.setAttribute('aria-pressed', String(t === activeTab));
    });
    [panelFrame, panelTrays, panelBOM, panelSettings].forEach((p) => {
      if (p) p.hidden = (p !== activePanel);
    });
  };

  if (tabFrame && tabTrays) {
    tabFrame.addEventListener('click', () => switchTab(tabFrame, panelFrame));
    tabTrays.addEventListener('click', () => switchTab(tabTrays, panelTrays));
    if (tabBOM) tabBOM.addEventListener('click', () => switchTab(tabBOM, panelBOM));
    if (tabSettings) tabSettings.addEventListener('click', () => switchTab(tabSettings, panelSettings));
  }
  setupAcmSettingsListeners();

  document.querySelectorAll('[data-acm-canvas]').forEach((btn) => {
    btn.addEventListener('click', () => {
      acmStudioState.canvasMode = btn.getAttribute('data-acm-canvas');
      document.querySelectorAll('[data-acm-canvas]').forEach((b) => {
        b.setAttribute('aria-pressed', String(b === btn));
      });
      renderAcm360Studio();
    });
  });

  const inputIds = [
    'inpAcmFrameW', 'inpAcmFrameH', 'selAcmProfileFrame', 'selAcmProfileTrav',
    'selAcmCornerType', 'selAcmRotCorda', 'selAcmOpenSide', 'inpAcmTravV',
    'inpAcmTravH', 'selAcmBarStrategy', 'selAcmMaterial', 'selAcmColorMode',
    'inpAcmGridCols', 'inpAcmGridRows', 'inpAcmJointMm', 'selAcmEdgeType',
    'inpAcmReturnMm', 'inpAcmAbaMm', 'inpAcmBendFactor', 'selAcmFresa',
    'selAcmCornerTrat', 'chkAcmSyncJuntas', 'selAcmFastenerType',
    'inpAcmFastenerSpacing', 'selAcmVhbType', 'selAcmSealant', 'selAcmPreset'
  ];
  inputIds.forEach((id) => {
    const el = document.getElementById(id);
    if (el) {
      el.addEventListener('input', renderAcm360Studio);
      el.addEventListener('change', renderAcm360Studio);
    }
  });

  document.getElementById('btnAcmSyncStructure')?.addEventListener('click', () => {
    const cols = Math.max(1, Number(document.getElementById('inpAcmGridCols')?.value || 3));
    const rows = Math.max(1, Number(document.getElementById('inpAcmGridRows')?.value || 2));
    document.getElementById('inpAcmTravV').value = String(Math.max(0, cols - 1));
    document.getElementById('inpAcmTravH').value = String(Math.max(0, rows - 1));
    const chk = document.getElementById('chkAcmSyncJuntas');
    if (chk) chk.checked = true;
    acmStudioState.canvasMode = 'combined';
    document.querySelectorAll('[data-acm-canvas]').forEach((b) => {
      b.setAttribute('aria-pressed', String(b.getAttribute('data-acm-canvas') === 'combined'));
    });
    renderAcm360Studio();
    showToast(`⚡ Estrutura alinhada às juntas das ${cols * rows} bandejas ACM (${cols - 1} montantes × ${rows - 1} travessas)`);
  });

  document.getElementById('btnAcmExportDxf')?.addEventListener('click', downloadAcm360Dxf);
  document.getElementById('btnAcmExportCsv')?.addEventListener('click', downloadAcm360Csv);
  document.getElementById('btnAcmExportXlsx')?.addEventListener('click', downloadAcm360Xlsx);
  document.getElementById('btnAcmPrintReport')?.addEventListener('click', printAcm360Report);
  document.getElementById('btnAcmCreateErpOS')?.addEventListener('click', createErpOsFromAcm360);

  document.getElementById('inpAcmImportJson')?.addEventListener('change', (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      try {
        const data = JSON.parse(String(reader.result));
        if (data.frames && data.frames[0] && data.frames[0].params) {
          const p = data.frames[0].params;
          if (p.width_mm) document.getElementById('inpAcmFrameW').value = p.width_mm;
          if (p.height_mm) document.getElementById('inpAcmFrameH').value = p.height_mm;
          if (p.profile_corda) document.getElementById('selAcmProfileFrame').value = p.profile_corda;
          if (p.profile_travessa) document.getElementById('selAcmProfileTrav').value = p.profile_travessa;
        }
        renderAcm360Studio();
        showToast(`📥 Projeto SketchUp "${data.project_name || file.name}" importado com sucesso!`);
      } catch (err) {
        showToast(`Erro ao ler JSON: ${err.message}`);
      }
    };
    reader.readAsText(file);
  });
}

// Inicializar tudo
document.addEventListener('DOMContentLoaded', () => {
  initDialogLightDismissFallback();
  renderHeader();
  renderSectorBar();
  renderOSBoard();
  renderMaterialView();
  renderChapasView();
  setupEventListeners();
  setupAcm360StudioListeners();
  applyAcmSettingsDefaults();
  renderAcmSettingsPanel();
  renderAcm360Studio();
});
