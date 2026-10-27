# encoding: UTF-8
# ==============================================================================
# CS_ACM360_BETA::Catalog
# Catálogo fiel das 21 bitolas de tubos (Metalon e Alumínio), materiais,
# cores por tipo/comprimento e padrões de chapas/fresas de ACM.
# Extraído das especificações de referência A002_params e A003_params.
# ==============================================================================

module CS_ACM360_BETA
  module Catalog
    ATTR_DICT = 'CS_ACM360_DATA'.freeze

    # Catálogo oficial das 21 bitolas (largura_mm x altura_mm, espessura padrão mm)
    TUBE_PROFILES = [
      { id: 1,  code: 'M15x15', name: 'Metalon 15x15mm',                   family: 'metalon',  w_mm: 15.0,  h_mm: 15.0, wall_mm: 1.2, color: '#2563EB' },
      { id: 2,  code: 'M16x16', name: 'Metalon 16x16mm',                   family: 'metalon',  w_mm: 16.0,  h_mm: 16.0, wall_mm: 1.2, color: '#3B82F6' },
      { id: 3,  code: 'M20x20', name: 'Metalon 20x20mm',                   family: 'metalon',  w_mm: 20.0,  h_mm: 20.0, wall_mm: 1.2, color: '#0284C7' },
      { id: 4,  code: 'M20x30', name: 'Metalon 20x30mm',                   family: 'metalon',  w_mm: 20.0,  h_mm: 30.0, wall_mm: 1.2, color: '#0D9488' },
      { id: 5,  code: 'M20x40', name: 'Metalon 20x40mm',                   family: 'metalon',  w_mm: 20.0,  h_mm: 40.0, wall_mm: 1.2, color: '#059669' },
      { id: 6,  code: 'M25x50', name: 'Metalon 25x50mm',                   family: 'metalon',  w_mm: 25.0,  h_mm: 50.0, wall_mm: 1.5, color: '#16A34A' },
      { id: 7,  code: 'M25x75', name: 'Metalon 25x75mm',                   family: 'metalon',  w_mm: 25.0,  h_mm: 75.0, wall_mm: 1.5, color: '#65A30D' },
      { id: 8,  code: 'M30x30', name: 'Metalon 30x30mm',                   family: 'metalon',  w_mm: 30.0,  h_mm: 30.0, wall_mm: 1.2, color: '#D97706' },
      { id: 9,  code: 'M40x40', name: 'Metalon 40x40mm',                   family: 'metalon',  w_mm: 40.0,  h_mm: 40.0, wall_mm: 1.5, color: '#EA580C' },
      { id: 10, code: 'M50x30', name: 'Metalon 50x30mm',                   family: 'metalon',  w_mm: 50.0,  h_mm: 30.0, wall_mm: 1.5, color: '#DC2626' },
      { id: 11, code: 'M50x50', name: 'Metalon 50x50mm',                   family: 'metalon',  w_mm: 50.0,  h_mm: 50.0, wall_mm: 1.5, color: '#E11D48' },
      { id: 12, code: 'M80x80', name: 'Metalon 80x80mm',                   family: 'metalon',  w_mm: 80.0,  h_mm: 80.0, wall_mm: 2.0, color: '#9333EA' },
      { id: 13, code: 'A25x25', name: 'Alumínio 1" (25,4x25,4mm)',         family: 'aluminio', w_mm: 25.4,  h_mm: 25.4, wall_mm: 1.5, color: '#64748B' },
      { id: 14, code: 'A38x25', name: 'Alumínio 1.1/2x1" (38,1x25,4mm)',   family: 'aluminio', w_mm: 38.1,  h_mm: 25.4, wall_mm: 1.5, color: '#475569' },
      { id: 15, code: 'A38x50', name: 'Alumínio 1.1/2x2" (38,1x50,8mm)',   family: 'aluminio', w_mm: 38.1,  h_mm: 50.8, wall_mm: 1.5, color: '#334155' },
      { id: 16, code: 'A50x25', name: 'Alumínio 2x1" (50,8x25,4mm)',       family: 'aluminio', w_mm: 50.8,  h_mm: 25.4, wall_mm: 1.5, color: '#0891B2' },
      { id: 17, code: 'A50x50', name: 'Alumínio 2x2" (50,8x50,8mm)',       family: 'aluminio', w_mm: 50.8,  h_mm: 50.8, wall_mm: 1.8, color: '#0369A1' },
      { id: 18, code: 'A76x25', name: 'Alumínio 3x1" (76,2x25,4mm)',       family: 'aluminio', w_mm: 76.2,  h_mm: 25.4, wall_mm: 1.8, color: '#4F46E5' },
      { id: 19, code: 'A76x38', name: 'Alumínio 3x1.1/2" (76,2x38,1mm)',   family: 'aluminio', w_mm: 76.2,  h_mm: 38.1, wall_mm: 2.0, color: '#7C3AED' },
      { id: 20, code: 'A101x30', name: 'Alumínio 4x1.1/2" (101,6x30,1mm)', family: 'aluminio', w_mm: 101.6, h_mm: 30.1, wall_mm: 2.0, color: '#C026D3' },
      { id: 21, code: 'A101x50', name: 'Alumínio 4x2" (101,6x50,8mm)',     family: 'aluminio', w_mm: 101.6, h_mm: 50.8, wall_mm: 2.0, color: '#DB2777' }
    ].freeze

    MATERIALS = {
      'aco_carbono' => 'Aço Carbono',
      'galvanizado' => 'Galvanizado',
      'aluminio'    => 'Alumínio'
    }.freeze

    CORNER_TYPES = {
      'encosto'    => 'Por Dentro (Corte Reto)',
      'passante_h' => 'Por Fora (Travessa Passante)',
      'esquadria'  => 'Meia-Esquadria (45°)'
    }.freeze

    OPEN_SIDES = {
      0 => 'Nenhum (Fechado)',
      1 => 'Esquerdo Aberto',
      2 => 'Direito Aberto',
      3 => 'Ambos Abertos'
    }.freeze

    ACM_COLORS = [
      { id: 'preto_fosco',    name: 'ACM Preto Fosco',    hex: '#27272A' },
      { id: 'branco_brilho',  name: 'ACM Branco Brilho',  hex: '#F4F4F5' },
      { id: 'prata_metalico', name: 'ACM Prata Metálico', hex: '#94A3B8' },
      { id: 'vermelho_vivo',  name: 'ACM Vermelho',       hex: '#DC2626' },
      { id: 'azul_royal',     name: 'ACM Azul Royal',     hex: '#1D4ED8' },
      { id: 'amarelo_ouro',   name: 'ACM Amarelo Ouro',   hex: '#EAB308' }
    ].freeze

    # Padrões de fábrica do M12 (sobrescritos pela máquina e pelo modelo em Settings).
    # Mesmo formato do JSON CS_ACM360_SETTINGS_V1 usado pelo painel web.
    DEFAULT_SETTINGS = {
      # Geral / Estruturas
      'bar_mm'              => 6000.0,
      'kerf_mm'             => 3.0,
      'seam_strategy'       => 'economia', # economia | iguais
      'color_mode'          => 'tipo',     # tipo | comprimento | unica
      # ACM
      'acm_sheet_w_mm'      => 5000.0,
      'acm_sheet_h_mm'      => 1220.0,
      'acm_core'            => 'PE',       # PE | FR
      'fresa_type'          => 'V90',      # V90 | V135 | U
      'refile_tab_mm'       => 15.0,
      'default_return_mm'   => 50.0,
      'default_aba_mm'      => 20.0,
      'default_joint_mm'    => 10.0,
      'nest_gap_mm'         => 8.0,
      'nest_margin_mm'      => 10.0,
      # Fator de dobra por fornecedor/espessura (calibrar com peça de teste)
      'acm_preset'          => 'generico_3',
      'acm_presets'         => [
        { 'id' => 'generico_3', 'name' => 'Genérico 3 mm', 'thickness_mm' => 3.0, 'bend_factor_mm' => 1.5 },
        { 'id' => 'generico_4', 'name' => 'Genérico 4 mm', 'thickness_mm' => 4.0, 'bend_factor_mm' => 2.0 }
      ],
      # Fixadores (M4): cantoneira bandeja → estrutura usa spacing/offset; ancoragem e espera
      # (estrutura → parede) usam anchor_*; standoff_mm é o afastamento da espera até a parede
      'fastener_spacing_mm' => 400.0,
      'fastener_offset_mm'  => 70.0,
      'anchor_spacing_mm'   => 800.0,
      'anchor_margin_mm'    => 150.0,
      'standoff_mm'         => 100.0,
      'fastener_specs'      => [
        { 'id' => 'cantoneira', 'name' => 'Cantoneira bandeja → estrutura',
          'leg_a_mm' => 25.0, 'leg_b_mm' => 25.0, 'length_mm' => 40.0, 'thickness_mm' => 2.0,
          'items' => [{ 'name' => 'Rebite alumínio 4,8×12', 'qty' => 2 }, { 'name' => 'Parafuso autobrocante 4,2×19', 'qty' => 2 }] },
        { 'id' => 'ancoragem', 'name' => 'Ancoragem estrutura → parede',
          'leg_a_mm' => 50.0, 'leg_b_mm' => 50.0, 'length_mm' => 50.0, 'thickness_mm' => 3.0,
          'items' => [{ 'name' => 'Parafuso autobrocante 4,2×19', 'qty' => 2 }, { 'name' => 'Bucha S8', 'qty' => 2 }, { 'name' => 'Parafuso 5,5×50', 'qty' => 2 }] },
        { 'id' => 'espera', 'name' => 'Espera (afastador)',
          'leg_a_mm' => 40.0, 'leg_b_mm' => 50.0, 'length_mm' => 50.0, 'thickness_mm' => 3.0,
          'items' => [{ 'name' => 'Parafuso autobrocante 4,2×19', 'qty' => 2 }, { 'name' => 'Bucha S8', 'qty' => 2 }, { 'name' => 'Parafuso 5,5×50', 'qty' => 2 }] }
      ],
      # Fitas dupla face
      'tape'                => 'vhb_4910',
      'tapes'               => [
        { 'id' => 'vhb_4910', 'name' => '3M VHB 4910 (1,1 mm)', 'width_mm' => 19.0, 'roll_m' => 33.0, 'price' => 0.0 },
        { 'id' => 'vhb_4941', 'name' => '3M VHB 4941 (1,6 mm)', 'width_mm' => 19.0, 'roll_m' => 33.0, 'price' => 0.0 },
        { 'id' => 'vhb_4955', 'name' => '3M VHB 4955 (2,0 mm)', 'width_mm' => 19.0, 'roll_m' => 33.0, 'price' => 0.0 }
      ],
      # Bitolas próprias (id >= 100) e preço por metro de qualquer bitola ({ "id" => R$/m })
      'custom_profiles'     => [],
      'profile_prices'      => {},
      # Cabeçalho de impressão
      'company_name'        => 'CS Comunicação',
      'company_phone'       => '',
      'company_email'       => '',
      'company_logo'        => '' # data URI, até 300 KB
    }.freeze

    def self.find_profile(id_or_code)
      all = defined?(Settings) ? Settings.profiles : TUBE_PROFILES
      all.find { |p| p[:id].to_s == id_or_code.to_s || p[:code].to_s.casecmp(id_or_code.to_s).zero? || p[:name] == id_or_code.to_s } || TUBE_PROFILES[4]
    end

    # Retorna [largura_frontal_mm, profundidade_y_mm] conforme orientação:
    # rot = 1 (Menor para frente) | rot = 2 (Maior para frente)
    def self.oriented_section(profile, rot = 1)
      s_min = [profile[:w_mm], profile[:h_mm]].min
      s_max = [profile[:w_mm], profile[:h_mm]].max
      if rot.to_i == 2
        [s_max, s_min]
      else
        [s_min, s_max]
      end
    end
  end
end
