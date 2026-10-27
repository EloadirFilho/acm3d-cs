# encoding: UTF-8
# ==============================================================================
# CS_ACM360_BETA::AcmTrayKernel
# Construtor e Editor de Bandejas de ACM 3D (retornos, abas, refile, cantos 45°),
# Leitura Automática de Bandejas ACM -> Geração de Estrutura Metálica (ler_acm),
# Colagem (Fita Dupla-Face e Tiras de Reforço). Fixadores: hardware_fasteners.rb (M4).
# ==============================================================================

require 'json'

module CS_ACM360_BETA
  module AcmTrayKernel
    MM_TO_INCH = 1.0 / 25.4

    def self.mm(val)
      val.to_f * MM_TO_INCH
    end

    def self.to_mm(inch_val)
      (inch_val.to_f * 25.4).round(2)
    end

    # Cria ou atualiza uma Bandeja ACM Paramétrica 3D (ou conjunto de bandejas em malha)
    def self.create_or_update_tray(params = {}, existing_group = nil)
      model = Sketchup.active_model
      return nil unless model

      cfg = normalize_tray_params(params)
      op_name = existing_group ? 'Editar Bandeja ACM (CS ACM360)' : 'Criar Bandeja ACM (CS ACM360)'
      model.start_operation(op_name, true)

      begin
        if existing_group && existing_group.valid?
          grp = existing_group
          grp.entities.clear!
        else
          grp = model.active_entities.add_group
        end

        grp.name = cfg['name']
        FrameKernel.ensure_layer(model, 'CS_ACM360_Bandejas_ACM', grp)

        draw_tray_3d(model, grp.entities, cfg)
        flat_data = UnfoldDxfEngine.compute_tray_unfold(cfg)

        grp.set_attribute(Catalog::ATTR_DICT, 'kind', 'acm_tray')
        grp.set_attribute(Catalog::ATTR_DICT, 'version', CS_ACM360_BETA::PLUGIN_VERSION)
        grp.set_attribute(Catalog::ATTR_DICT, 'tray_json', JSON.generate(cfg))
        grp.set_attribute(Catalog::ATTR_DICT, 'unfold_json', JSON.generate(flat_data))
        HardwareFasteners.reapply(grp)

        model.commit_operation
        model.selection.clear
        model.selection.add(grp)
        grp
      rescue StandardError => e
        model.abort_operation
        UI.messagebox("Erro ao gerar Bandeja ACM: #{e.message}")
        nil
      end
    end

    # Cria uma fachada / malha de múltiplas Bandejas ACM + Estrutura Metálica integrada opcional
    def self.create_facade_grid(grid_params = {})
      model = Sketchup.active_model
      return nil unless model

      cols      = (grid_params['cols'] || 3).to_i.clamp(1, 20)
      rows      = (grid_params['rows'] || 2).to_i.clamp(1, 10)
      total_w   = (grid_params['total_w_mm'] || 3600.0).to_f.clamp(200.0, 50000.0)
      total_h   = (grid_params['total_h_mm'] || 1800.0).to_f.clamp(200.0, 20000.0)
      joint_mm  = (grid_params['joint_mm'] || Settings.get('default_joint_mm')).to_f.clamp(0.0, 50.0)
      return_mm = (grid_params['return_mm'] || Settings.get('default_return_mm')).to_f.clamp(15.0, 300.0)
      aba_mm    = (grid_params['aba_mm'] || 0.0).to_f.clamp(0.0, 100.0)
      color_hex = (grid_params['color_hex'] || '#27272A').to_s
      with_frame = grid_params['generate_frame'] != false

      tray_w = ((total_w - (cols - 1) * joint_mm) / cols.to_f).round(2)
      tray_h = ((total_h - (rows - 1) * joint_mm) / rows.to_f).round(2)

      model.start_operation('Criar Painel de Bandejas ACM (CS ACM360)', true)
      begin
        created_trays = []
        side_type = aba_mm > 0 ? 'dobra_aba' : 'dobra'

        (0...rows).each do |r|
          (0...cols).each do |c|
            idx = r * cols + c + 1
            ox = c * (tray_w + joint_mm)
            oz = r * (tray_h + joint_mm)
            t_cfg = normalize_tray_params(
              'name'       => "Bandeja P#{format('%02d', idx)}",
              'code'       => "P#{format('%02d', idx)}",
              'width_mm'   => tray_w,
              'height_mm'  => tray_h,
              'origin_x_mm'=> ox,
              'origin_y_mm'=> 0.0,
              'origin_z_mm'=> oz,
              'color_hex'  => color_hex,
              'edges'      => {
                'sup' => { 'type' => side_type, 'return_mm' => return_mm, 'aba_mm' => aba_mm },
                'inf' => { 'type' => side_type, 'return_mm' => return_mm, 'aba_mm' => aba_mm },
                'esq' => { 'type' => side_type, 'return_mm' => return_mm, 'aba_mm' => aba_mm },
                'dir' => { 'type' => side_type, 'return_mm' => return_mm, 'aba_mm' => aba_mm }
              }
            )
            grp = model.active_entities.add_group
            grp.name = t_cfg['name']
            FrameKernel.ensure_layer(model, 'CS_ACM360_Bandejas_ACM', grp)
            draw_tray_3d(model, grp.entities, t_cfg)
            flat_data = UnfoldDxfEngine.compute_tray_unfold(t_cfg)
            grp.set_attribute(Catalog::ATTR_DICT, 'kind', 'acm_tray')
            grp.set_attribute(Catalog::ATTR_DICT, 'tray_json', JSON.generate(t_cfg))
            grp.set_attribute(Catalog::ATTR_DICT, 'unfold_json', JSON.generate(flat_data))
            created_trays << grp
          end
        end

        if with_frame
          create_frame_from_trays(created_trays, grid_params, false)
        end

        model.commit_operation
        model.selection.clear
        created_trays.each { |g| model.selection.add(g) }
        created_trays
      rescue StandardError => e
        model.abort_operation
        UI.messagebox("Erro ao criar malha de bandejas: #{e.message}")
        nil
      end
    end

    # LEITURA AUTOMÁTICA DE BANDEJAS ACM -> ESTRUTURA METÁLICA (`ler_acm`)
    # Analisa os envelopes das bandejas ACM selecionadas, encontra as juntas
    # verticais e horizontais e gera a estrutura metálica atrás delas!
    def self.create_frame_from_trays(tray_groups = nil, options = {}, own_operation = true)
      model = Sketchup.active_model
      return nil unless model

      groups = tray_groups || model.selection.grep(Sketchup::Group)
      if groups.empty?
        # Se nada selecionado, busca todas as bandejas ACM do modelo
        groups = model.active_entities.grep(Sketchup::Group).select do |g|
          g.get_attribute(Catalog::ATTR_DICT, 'kind') == 'acm_tray'
        end
      end

      if groups.empty?
        UI.messagebox('Nenhuma bandeja ACM encontrada na seleção ou no modelo.')
        return nil
      end

      boxes = []
      max_return = 50.0
      groups.each do |g|
        bb = g.bounds
        next if bb.empty?
        raw_json = g.get_attribute(Catalog::ATTR_DICT, 'tray_json')
        if raw_json
          parsed = JSON.parse(raw_json) rescue nil
          if parsed && parsed['edges']
            ret = parsed['edges'].values.map { |e| e['return_mm'].to_f }.max
            max_return = [max_return, ret].max if ret
          end
        end
        boxes << {
          min_x: to_mm(bb.min.x), max_x: to_mm(bb.max.x),
          min_y: to_mm(bb.min.y), max_y: to_mm(bb.max.y),
          min_z: to_mm(bb.min.z), max_z: to_mm(bb.max.z)
        }
      end

      return nil if boxes.empty?

      env_min_x = boxes.map { |b| b[:min_x] }.min
      env_max_x = boxes.map { |b| b[:max_x] }.max
      env_min_z = boxes.map { |b| b[:min_z] }.min
      env_max_z = boxes.map { |b| b[:max_z] }.max
      env_max_y = boxes.map { |b| b[:max_y] }.max

      total_w = (env_max_x - env_min_x).round(2)
      total_h = (env_max_z - env_min_z).round(2)

      # Detecta juntas verticais (entre max_x de uma coluna e min_x da próxima)
      x_splits = []
      sorted_x = boxes.map { |b| [b[:min_x], b[:max_x]] }.uniq { |pair| pair[0].round(0) }.sort_by(&:first)
      (0...(sorted_x.length - 1)).each do |i|
        joint_center = ((sorted_x[i][1] + sorted_x[i + 1][0]) / 2.0) - env_min_x
        x_splits << joint_center.round(2) if joint_center > 40.0 && joint_center < (total_w - 40.0)
      end

      # Detecta juntas horizontais (entre max_z de uma linha e min_z da próxima)
      z_splits = []
      sorted_z = boxes.map { |b| [b[:min_z], b[:max_z]] }.uniq { |pair| pair[0].round(0) }.sort_by(&:first)
      (0...(sorted_z.length - 1)).each do |j|
        joint_center = ((sorted_z[j][1] + sorted_z[j + 1][0]) / 2.0) - env_min_z
        z_splits << joint_center.round(2) if joint_center > 40.0 && joint_center < (total_h - 40.0)
      end

      # Verifica se há vão grande (> 1200 mm) sem montante intermediário e adiciona reforço se necessário
      if x_splits.empty? && total_w > 1300.0
        n_auto = (total_w / 1000.0).floor
        step = total_w / (n_auto + 1).to_f
        x_splits = (1..n_auto).map { |k| (k * step).round(2) }
      end

      frame_params = {
        'name'             => "Estrutura ACM (#{total_w.round(0)}x#{total_h.round(0)}mm)",
        'width_mm'         => total_w,
        'height_mm'        => total_h,
        'profile_corda'    => options['profile_corda'] || 5,    # Metalon 20x40mm
        'rot_corda'        => options['rot_corda'] || 1,
        'profile_travessa' => options['profile_travessa'] || 3, # Metalon 20x20mm
        'rot_travessa'     => options['rot_travessa'] || 1,
        'material'         => options['material'] || 'aco_carbono',
        'corner_type'      => options['corner_type'] || 'encosto',
        'folga_frente_mm'  => env_max_y, # Posiciona a estrutura logo atrás do retorno das bandejas
        'custom_v_xs_mm'   => x_splits,
        'custom_h_zs_mm'   => z_splits,
        'trav_v_count'     => x_splits.length,
        'trav_h_count'     => z_splits.length
      }

      model.start_operation('Criar Estrutura das Bandejas ACM', true) if own_operation
      begin
        frame_grp = FrameKernel.create_or_update_frame(frame_params)
        if frame_grp && (env_min_x.abs > 0.01 || env_min_z.abs > 0.01)
          tr = Geom::Transformation.translation(Geom::Vector3d.new(mm(env_min_x), 0, mm(env_min_z)))
          frame_grp.transform!(tr)
        end
        model.commit_operation if own_operation
        frame_grp
      rescue StandardError => e
        model.abort_operation if own_operation
        raise e
      end
    end

    # Espessura e fator de dobra vêm da chapa ACM ativa nas Configurações (M12),
    # a não ser que a bandeja traga valores próprios; ficam gravados na bandeja.
    def self.normalize_tray_params(raw = {})
      st = Settings.all
      preset = st['acm_presets'].find { |p| p['id'] == raw['acm_preset'].to_s } || Settings.acm_preset
      edges_in = raw['edges'].is_a?(Hash) ? raw['edges'] : {}
      norm_edge = lambda do |side|
        e = edges_in[side] || edges_in[side.to_sym] || {}
        {
          'type'      => (e['type'] || raw['default_edge_type'] || 'dobra').to_s, # corte | dobra | dobra_aba | refile
          'return_mm' => (e['return_mm'] || raw['return_mm'] || st['default_return_mm']).to_f.clamp(0.0, 400.0),
          'aba_mm'    => (e['aba_mm'] || raw['aba_mm'] || st['default_aba_mm']).to_f.clamp(0.0, 150.0),
          'aba_side'  => (e['aba_side'] || 'dentro').to_s # dentro | fora
        }
      end

      {
        'id'             => (raw['id'] || "TRAY_#{Time.now.to_i}_#{rand(100..999)}").to_s,
        'code'           => (raw['code'] || 'P01').to_s,
        'name'           => (raw['name'] || 'Bandeja ACM 01').to_s,
        'quantity'       => (raw['quantity'] || 1).to_i.clamp(1, 500),
        'width_mm'       => (raw['width_mm'] || 1200.0).to_f.clamp(80.0, 10000.0),
        'height_mm'      => (raw['height_mm'] || 800.0).to_f.clamp(80.0, 10000.0),
        'origin_x_mm'    => (raw['origin_x_mm'] || 0.0).to_f,
        'origin_y_mm'    => (raw['origin_y_mm'] || 0.0).to_f,
        'origin_z_mm'    => (raw['origin_z_mm'] || 0.0).to_f,
        'acm_preset'     => (raw['acm_preset'] || preset['id']).to_s,
        'thickness_mm'   => (raw['thickness_mm'] || preset['thickness_mm']).to_f,
        'bend_factor_mm' => (raw['bend_factor_mm'] || preset['bend_factor_mm']).to_f,
        'refile_tab_mm'  => (raw['refile_tab_mm'] || st['refile_tab_mm']).to_f,
        'fresa_type'     => (raw['fresa_type'] || st['fresa_type']).to_s,
        'corner_treatment'=> (raw['corner_treatment'] || 'esquadria').to_s, # esquadria | aberto | sobreposto
        'color_hex'      => (raw['color_hex'] || '#27272A').to_s,
        'dupla_face'     => raw['dupla_face'] != false,
        'tiras_reforco'  => !!raw['tiras_reforco'],
        'edges'          => {
          'sup' => norm_edge.call('sup'),
          'inf' => norm_edge.call('inf'),
          'esq' => norm_edge.call('esq'),
          'dir' => norm_edge.call('dir')
        }
      }
    end

    # Desenha a bandeja de ACM dobrada em 3D no SketchUp (face frontal + retornos + abas)
    def self.draw_tray_3d(model, entities, cfg)
      ox = mm(cfg['origin_x_mm'])
      oy = mm(cfg['origin_y_mm'])
      oz = mm(cfg['origin_z_mm'])
      w  = mm(cfg['width_mm'])
      h  = mm(cfg['height_mm'])
      th = mm(cfg['thickness_mm'])

      mat = FrameKernel.ensure_material(model, "CS_ACM_#{cfg['color_hex']}", cfg['color_hex'])

      # 1. Face Frontal
      front_grp = entities.add_group
      front_grp.name = 'Face Frontal ACM'
      pts_f = [
        Geom::Point3d.new(ox,     oy, oz),
        Geom::Point3d.new(ox + w, oy, oz),
        Geom::Point3d.new(ox + w, oy, oz + h),
        Geom::Point3d.new(ox,     oy, oz + h)
      ]
      f_face = front_grp.entities.add_face(pts_f)
      if f_face
        f_face.reverse! if f_face.normal.y < 0
        f_face.pushpull(th)
      end
      front_grp.material = mat

      # 2. Retornos Laterais (sup, inf, esq, dir) indo para trás (+Y)
      edges = cfg['edges'] || {}

      # Retorno Inferior
      if edges['inf'] && %w[dobra dobra_aba].include?(edges['inf']['type']) && edges['inf']['return_mm'].to_f > 0
        ret = mm(edges['inf']['return_mm'])
        g = entities.add_group
        g.name = 'Retorno Inferior'
        face = g.entities.add_face([
          Geom::Point3d.new(ox,     oy + th,       oz),
          Geom::Point3d.new(ox + w, oy + th,       oz),
          Geom::Point3d.new(ox + w, oy + th + ret, oz),
          Geom::Point3d.new(ox,     oy + th + ret, oz)
        ])
        if face
          face.reverse! if face.normal.z < 0
          face.pushpull(th)
        end
        g.material = mat
      end

      # Retorno Superior
      if edges['sup'] && %w[dobra dobra_aba].include?(edges['sup']['type']) && edges['sup']['return_mm'].to_f > 0
        ret = mm(edges['sup']['return_mm'])
        g = entities.add_group
        g.name = 'Retorno Superior'
        face = g.entities.add_face([
          Geom::Point3d.new(ox,     oy + th,       oz + h - th),
          Geom::Point3d.new(ox + w, oy + th,       oz + h - th),
          Geom::Point3d.new(ox + w, oy + th + ret, oz + h - th),
          Geom::Point3d.new(ox,     oy + th + ret, oz + h - th)
        ])
        if face
          face.reverse! if face.normal.z < 0
          face.pushpull(th)
        end
        g.material = mat
      end

      # Retorno Esquerdo
      if edges['esq'] && %w[dobra dobra_aba].include?(edges['esq']['type']) && edges['esq']['return_mm'].to_f > 0
        ret = mm(edges['esq']['return_mm'])
        g = entities.add_group
        g.name = 'Retorno Esquerdo'
        face = g.entities.add_face([
          Geom::Point3d.new(ox,      oy + th,       oz),
          Geom::Point3d.new(ox + th, oy + th,       oz),
          Geom::Point3d.new(ox + th, oy + th + ret, oz),
          Geom::Point3d.new(ox,      oy + th + ret, oz)
        ])
        if face
          face.reverse! if face.normal.z < 0
          face.pushpull(h)
        end
        g.material = mat
      end

      # Retorno Direito
      if edges['dir'] && %w[dobra dobra_aba].include?(edges['dir']['type']) && edges['dir']['return_mm'].to_f > 0
        ret = mm(edges['dir']['return_mm'])
        g = entities.add_group
        g.name = 'Retorno Direito'
        face = g.entities.add_face([
          Geom::Point3d.new(ox + w - th, oy + th,       oz),
          Geom::Point3d.new(ox + w,      oy + th,       oz),
          Geom::Point3d.new(ox + w,      oy + th + ret, oz),
          Geom::Point3d.new(ox + w - th, oy + th + ret, oz)
        ])
        if face
          face.reverse! if face.normal.z < 0
          face.pushpull(h)
        end
        g.material = mat
      end
    end
  end
end
