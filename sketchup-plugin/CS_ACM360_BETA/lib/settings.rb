# encoding: UTF-8
# ==============================================================================
# CS_ACM360_BETA::Settings  (Módulo M12 — Configurações)
# Configurações em três camadas, da menor para a maior prioridade:
#   1. Catalog::DEFAULT_SETTINGS (padrão de fábrica)
#   2. Máquina   -> Sketchup.write_default('CS_ACM360_BETA', 'settings_json')
#   3. Modelo    -> attribute_dictionary 'CS_ACM360_SETTINGS' do .skp
# Salvar grava nas duas camadas, para o projeto abrir igual em outro computador.
# ==============================================================================

require 'json'

module CS_ACM360_BETA
  module Settings
    SCHEMA     = 'CS_ACM360_SETTINGS_V1'.freeze
    PREFS_KEY  = 'settings_json'.freeze
    MODEL_DICT = 'CS_ACM360_SETTINGS'.freeze
    LOGO_MAX_BYTES = 300 * 1024

    # Limites [min, max] dos campos numéricos
    NUMERIC_RANGES = {
      'bar_mm'              => [1000.0, 12000.0],
      'kerf_mm'             => [0.0, 15.0],
      'acm_sheet_w_mm'      => [500.0, 10000.0],
      'acm_sheet_h_mm'      => [500.0, 3000.0],
      'refile_tab_mm'       => [0.0, 100.0],
      'default_return_mm'   => [0.0, 400.0],
      'default_aba_mm'      => [0.0, 150.0],
      'default_joint_mm'    => [0.0, 50.0],
      'nest_gap_mm'         => [0.0, 100.0],
      'nest_margin_mm'      => [0.0, 200.0],
      'fastener_spacing_mm' => [100.0, 2000.0],
      'fastener_offset_mm'  => [0.0, 500.0]
    }.freeze

    @cache = nil
    @cache_model_id = nil

    # Configuração efetiva (fábrica < máquina < modelo). O cache é refeito ao trocar de modelo.
    def self.all
      model_id = Sketchup.active_model && Sketchup.active_model.object_id
      if @cache.nil? || @cache_model_id != model_id
        merged = deep_dup(Catalog::DEFAULT_SETTINGS)
        merged.merge!(read_machine)
        merged.merge!(read_model)
        @cache = normalize(merged)
        @cache_model_id = model_id
      end
      @cache
    end

    def self.get(key)
      all[key.to_s]
    end

    def self.invalidate!
      @cache = nil
    end

    # Grava na máquina e no modelo ativo. Retorna a configuração normalizada.
    def self.save(raw)
      cfg = normalize(deep_dup(Catalog::DEFAULT_SETTINGS).merge(raw.is_a?(Hash) ? raw : {}))
      json = JSON.generate(cfg)
      Sketchup.write_default(PLUGIN_ID, PREFS_KEY, json)
      model = Sketchup.active_model
      if model
        model.start_operation('Salvar Configurações (CS ACM360)', true, false, true)
        model.set_attribute(MODEL_DICT, PREFS_KEY, json)
        model.commit_operation
      end
      invalidate!
      all
    end

    # Volta ao padrão de fábrica nesta máquina e neste modelo
    def self.reset!
      save({})
    end

    # Pacote de troca com o painel web (mesmo formato de import/export)
    def self.export_payload
      { 'schema' => SCHEMA }.merge(all)
    end

    def self.import_payload(data)
      data = JSON.parse(data) if data.is_a?(String)
      raise ArgumentError, 'Arquivo não é uma configuração CS ACM360.' unless data.is_a?(Hash) && data['schema'] == SCHEMA
      save(data.reject { |k, _| k == 'schema' })
    end

    # --------------------------------------------------------------------------
    # Atalhos usados pelos kernels
    # --------------------------------------------------------------------------
    def self.acm_preset
      presets = all['acm_presets']
      presets.find { |p| p['id'] == all['acm_preset'] } || presets.first
    end

    def self.acm_thickness_mm
      acm_preset['thickness_mm'].to_f
    end

    def self.bend_factor_mm
      acm_preset['bend_factor_mm'].to_f
    end

    def self.tape
      tapes = all['tapes']
      tapes.find { |t| t['id'] == all['tape'] } || tapes.first
    end

    # Catálogo de fábrica + bitolas cadastradas pelo usuário, com preço por metro
    def self.profiles
      prices = all['profile_prices']
      custom = all['custom_profiles'].map do |p|
        {
          id: p['id'].to_i, code: p['code'].to_s, name: p['name'].to_s, family: p['family'].to_s,
          w_mm: p['w_mm'].to_f, h_mm: p['h_mm'].to_f, wall_mm: p['wall_mm'].to_f,
          color: p['color'].to_s, custom: true
        }
      end
      (Catalog::TUBE_PROFILES + custom).map do |p|
        p.merge(price_m: prices[p[:id].to_s].to_f)
      end
    end

    # --------------------------------------------------------------------------
    # Leitura e normalização
    # --------------------------------------------------------------------------
    def self.read_machine
      parse_json(Sketchup.read_default(PLUGIN_ID, PREFS_KEY, nil))
    end

    def self.read_model
      model = Sketchup.active_model
      model ? parse_json(model.get_attribute(MODEL_DICT, PREFS_KEY)) : {}
    end

    def self.parse_json(str)
      return {} if str.nil? || str.to_s.empty?
      parsed = JSON.parse(str.to_s)
      parsed.is_a?(Hash) ? parsed : {}
    rescue JSON::ParserError
      {}
    end

    def self.normalize(cfg)
      defaults = Catalog::DEFAULT_SETTINGS
      out = {}
      defaults.each_key { |k| out[k] = cfg.key?(k) ? cfg[k] : deep_dup(defaults[k]) }

      NUMERIC_RANGES.each do |k, (lo, hi)|
        v = Float(out[k]) rescue defaults[k]
        out[k] = v.clamp(lo, hi)
      end
      out['seam_strategy'] = 'economia' unless %w[economia iguais].include?(out['seam_strategy'])
      out['color_mode']    = 'tipo'     unless %w[tipo comprimento unica].include?(out['color_mode'])
      out['acm_core']      = 'PE'       unless %w[PE FR].include?(out['acm_core'])
      out['fresa_type']    = 'V90'      unless %w[V90 V135 U].include?(out['fresa_type'])

      out['acm_presets'] = normalize_list(out['acm_presets'], defaults['acm_presets']) do |p|
        {
          'id'             => p['id'].to_s,
          'name'           => p['name'].to_s,
          'thickness_mm'   => p['thickness_mm'].to_f.clamp(1.0, 10.0),
          'bend_factor_mm' => p['bend_factor_mm'].to_f.clamp(0.0, 10.0)
        }
      end
      out['tapes'] = normalize_list(out['tapes'], defaults['tapes']) do |t|
        {
          'id'       => t['id'].to_s,
          'name'     => t['name'].to_s,
          'width_mm' => t['width_mm'].to_f.clamp(1.0, 100.0),
          'roll_m'   => t['roll_m'].to_f.clamp(1.0, 500.0),
          'price'    => [t['price'].to_f, 0.0].max
        }
      end
      out['acm_preset'] = out['acm_presets'].first['id'] unless out['acm_presets'].any? { |p| p['id'] == out['acm_preset'] }
      out['tape']       = out['tapes'].first['id']       unless out['tapes'].any? { |t| t['id'] == out['tape'] }

      out['custom_profiles'] = Array(out['custom_profiles']).select { |p| p.is_a?(Hash) && p['id'].to_i >= 100 && p['w_mm'].to_f > 0 && p['h_mm'].to_f > 0 }
      out['profile_prices']  = (out['profile_prices'].is_a?(Hash) ? out['profile_prices'] : {})
                               .transform_keys(&:to_s).transform_values { |v| [v.to_f, 0.0].max }

      %w[company_name company_phone company_email company_logo].each { |k| out[k] = out[k].to_s }
      out['company_logo'] = '' if out['company_logo'].bytesize > LOGO_MAX_BYTES * 4 / 3 + 64 # base64 de 300 KB
      out
    end

    # Mantém só itens válidos (com id e nome); lista vazia volta ao padrão
    def self.normalize_list(list, fallback)
      items = Array(list).select { |i| i.is_a?(Hash) && !i['id'].to_s.empty? && !i['name'].to_s.empty? }
      items = deep_dup(fallback) if items.empty?
      items.map { |i| yield i }
    end

    def self.deep_dup(obj)
      JSON.parse(JSON.generate(obj))
    end
  end
end
