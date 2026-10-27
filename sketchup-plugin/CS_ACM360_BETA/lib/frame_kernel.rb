# encoding: UTF-8
# ==============================================================================
# CS_ACM360_BETA::FrameKernel
# Construtor Paramétrico 3D de Estruturas Metálicas (Gradil, Tubos, Travessas,
# Montantes, Emendas de Produção, Cortes Retos/Meia-Esquadria e Modos de Cor).
# Reproduz e aprimora a lógica geométrica do ACM360 (A002 e A003).
# ==============================================================================

require 'json'

module CS_ACM360_BETA
  module FrameKernel
    MM_TO_INCH = 1.0 / 25.4

    def self.mm(val)
      (val.to_f * MM_TO_INCH)
    end

    def self.to_mm(inch_val)
      (inch_val.to_f * 25.4).round(2)
    end

    # Gera ou atualiza uma estrutura metálica paramétrica 3D no modelo ativo do SketchUp
    def self.create_or_update_frame(params = {}, existing_group = nil)
      model = Sketchup.active_model
      return nil unless model

      cfg = normalize_params(params)
      op_name = existing_group ? 'Atualizar Estrutura Dinâmica (CS ACM360)' : 'Criar Estrutura Dinâmica (CS ACM360)'
      model.start_operation(op_name, true)

      begin
        if existing_group && existing_group.valid?
          root_group = existing_group
          root_group.entities.clear!
        else
          root_group = model.active_entities.add_group
        end

        root_group.name = cfg['name']
        ensure_layer(model, 'CS_ACM360_Estruturas', root_group)

        # Calcula a lista completa de tubos (Quadro + Montantes + Travessas + Emendas)
        recipe = compute_frame_tubes(cfg)

        # Desenha cada tubo como subgrupo sólido identificável
        quadro_grp    = root_group.entities.add_group
        quadro_grp.name = 'Quadro Principal'
        montantes_grp = root_group.entities.add_group
        montantes_grp.name = 'Montantes'
        travessas_grp = root_group.entities.add_group
        travessas_grp.name = 'Travessas'

        recipe[:tubes].each do |tube|
          parent = case tube[:group_role]
                   when 'quadro'    then quadro_grp
                   when 'montantes' then montantes_grp
                   else                  travessas_grp
                   end
          draw_tube_3d(model, parent.entities, tube, cfg['color_mode'])
        end

        # Remove subgrupos vazios
        [quadro_grp, montantes_grp, travessas_grp].each do |g|
          g.erase! if g.valid? && g.entities.length.zero?
        end

        # Desenha guia de folga de ACM se ativada
        draw_clearance_guide(model, root_group.entities, cfg) if cfg['guia_folga']

        # Salva metadados paramétricos e lista de corte no dicionário do grupo
        save_frame_attributes(root_group, cfg, recipe)

        model.commit_operation
        model.selection.clear
        model.selection.add(root_group)
        root_group
      rescue StandardError => e
        model.abort_operation
        UI.messagebox("Erro ao gerar estrutura: #{e.message}")
        nil
      end
    end

    # Cria um Tubo Avulso paramétrico
    def self.create_single_tube(params = {})
      model = Sketchup.active_model
      return nil unless model

      profile = Catalog.find_profile(params['profile_id'] || 5)
      len_mm  = (params['length_mm'] || 2000.0).to_f.clamp(10.0, 24000.0)
      rot     = (params['rot'] || 1).to_i
      cut_a   = (params['cut_a_deg'] || 0.0).to_f.clamp(0.0, 75.0)
      cut_b   = (params['cut_b_deg'] || 0.0).to_f.clamp(0.0, 75.0)
      mat_key = params['material'] || 'aco_carbono'
      fx, fy  = Catalog.oriented_section(profile, rot)

      model.start_operation('Novo Tubo Avulso (CS ACM360)', true)
      begin
        grp = model.active_entities.add_group
        grp.name = params['name'] || "Tubo Avulso #{profile[:name]}"
        ensure_layer(model, 'CS_ACM360_Estruturas', grp)

        tube = {
          id: 'T01',
          slot: 'tubo_avulso_1',
          name: grp.name,
          group_role: 'quadro',
          axis: 'x',
          x_mm: 0.0, y_mm: 0.0, z_mm: 0.0,
          w_mm: len_mm, d_mm: fy, h_mm: fx,
          length_mm: len_mm,
          profile_id: profile[:id],
          profile_name: profile[:name],
          wall_mm: profile[:wall_mm],
          material: Catalog::MATERIALS[mat_key] || 'Aço Carbono',
          cut_a_deg: cut_a,
          cut_b_deg: cut_b,
          color: profile[:color]
        }
        draw_tube_3d(model, grp.entities, tube, 'tipo')
        grp.set_attribute(Catalog::ATTR_DICT, 'kind', 'single_tube')
        grp.set_attribute(Catalog::ATTR_DICT, 'params_json', JSON.generate(params))
        grp.set_attribute(Catalog::ATTR_DICT, 'tubes_json', JSON.generate([tube]))
        model.commit_operation
        model.selection.clear
        model.selection.add(grp)
        grp
      rescue StandardError => e
        model.abort_operation
        UI.messagebox("Erro ao criar tubo avulso: #{e.message}")
        nil
      end
    end

    # Barra comercial e perda da serra vêm sempre das Configurações (M12), não do grupo
    def self.normalize_params(raw = {})
      st = Settings.all
      {
        'name'             => (raw['name'] || 'Estrutura Gradil #01').to_s,
        'width_mm'         => (raw['width_mm'] || 3000.0).to_f.clamp(100.0, 50000.0),
        'height_mm'        => (raw['height_mm'] || 1500.0).to_f.clamp(100.0, 20000.0),
        'profile_corda'    => (raw['profile_corda'] || 5).to_i,      # Metalon 20x40mm
        'rot_corda'        => (raw['rot_corda'] || 1).to_i,          # 1=Menor p/ frente, 2=Maior p/ frente
        'profile_travessa' => (raw['profile_travessa'] || 3).to_i,   # Metalon 20x20mm
        'rot_travessa'     => (raw['rot_travessa'] || 1).to_i,
        'material'         => (raw['material'] || 'aco_carbono').to_s,
        'corner_type'      => (raw['corner_type'] || 'encosto').to_s, # encosto | passante_h | esquadria
        'open_side'        => (raw['open_side'] || 0).to_i,          # 0=Fechado, 1=Esq, 2=Dir, 3=Ambos
        'trav_h_count'     => (raw['trav_h_count'] || 1).to_i.clamp(0, 30),
        'trav_v_count'     => (raw['trav_v_count'] || 2).to_i.clamp(0, 40),
        'trav_align'       => (raw['trav_align'] || 'frente').to_s,  # frente | centro | atras
        'desloc_sup_mm'    => (raw['desloc_sup_mm'] || 0.0).to_f,
        'desloc_inf_mm'    => (raw['desloc_inf_mm'] || 0.0).to_f,
        'desloc_todas_mm'  => (raw['desloc_todas_mm'] || 0.0).to_f,
        'folga_esq_mm'     => (raw['folga_esq_mm'] || 0.0).to_f.clamp(0.0, 500.0),
        'folga_dir_mm'     => (raw['folga_dir_mm'] || 0.0).to_f.clamp(0.0, 500.0),
        'folga_sup_mm'     => (raw['folga_sup_mm'] || 0.0).to_f.clamp(0.0, 500.0),
        'folga_inf_mm'     => (raw['folga_inf_mm'] || 0.0).to_f.clamp(0.0, 500.0),
        'folga_frente_mm'  => (raw['folga_frente_mm'] || 0.0).to_f.clamp(0.0, 500.0),
        'acm_esp_mm'       => (raw['acm_esp_mm'] || Settings.acm_thickness_mm).to_f,
        'guia_folga'       => !!raw['guia_folga'],
        'bar_mm'           => st['bar_mm'],
        'kerf_mm'          => st['kerf_mm'],
        'seam_strategy'    => (raw['seam_strategy'] || st['seam_strategy']).to_s,
        'color_mode'       => (raw['color_mode'] || st['color_mode']).to_s,
        'custom_v_xs_mm'   => raw['custom_v_xs_mm'].is_a?(Array) ? raw['custom_v_xs_mm'].map(&:to_f) : nil,
        'custom_h_zs_mm'   => raw['custom_h_zs_mm'].is_a?(Array) ? raw['custom_h_zs_mm'].map(&:to_f) : nil,
        'seam_overrides'   => raw['seam_overrides'].is_a?(Hash) ? raw['seam_overrides'] : {}
      }
    end

    # Calcula todos os tubos 3D e segmentos de barra com base nas fórmulas A002/A003
    def self.compute_frame_tubes(cfg)
      prof_frame = Catalog.find_profile(cfg['profile_corda'])
      prof_trav  = Catalog.find_profile(cfg['profile_travessa'])
      mat_label  = Catalog::MATERIALS[cfg['material']] || 'Aço Carbono'

      # Seção orientada: [face_frontal_mm, profundidade_y_mm]
      fw_f, fd_y = Catalog.oriented_section(prof_frame, cfg['rot_corda'])
      tw_f, td_y = Catalog.oriented_section(prof_trav, cfg['rot_travessa'])

      # Limites úteis descontando folgas (b1..b5 de A002_params)
      x0 = cfg['folga_esq_mm']
      x1 = cfg['width_mm'] - cfg['folga_dir_mm']
      z0 = cfg['folga_inf_mm']
      z1 = cfg['height_mm'] - cfg['folga_sup_mm']
      y0 = cfg['folga_frente_mm']

      eff_w = [x1 - x0, fw_f * 2.5].max
      eff_h = [z1 - z0, fw_f * 2.5].max

      open_left  = (cfg['open_side'] == 1 || cfg['open_side'] == 3)
      open_right = (cfg['open_side'] == 2 || cfg['open_side'] == 3)
      esp_esq    = open_left  ? 0.0 : fw_f
      esp_dir    = open_right ? 0.0 : fw_f

      corner = cfg['corner_type'] # encosto | passante_h | esquadria
      cut_deg = corner == 'esquadria' ? 45.0 : 0.0

      tubes = []
      seams_info = []

      # Helper que divide um tubo longo se passar de bar_mm
      add_segmented_tube = lambda do |base_tube|
        bar_mm = cfg['bar_mm']
        total_len = base_tube[:length_mm]
        if total_len <= bar_mm + 1e-4
          tubes << base_tube
        else
          pts = compute_seam_positions(base_tube[:slot], total_len, bar_mm, cfg['seam_strategy'], cfg['seam_overrides'])
          seams_info << {
            slot: base_tube[:slot],
            name: base_tube[:name],
            desc: "#{base_tube[:profile_name]} - #{base_tube[:wall_mm]}mm",
            length: total_len.round(1),
            vertical: base_tube[:axis] == 'z',
            seams: pts
          }
          bounds = [0.0] + pts + [total_len]
          (0...(bounds.length - 1)).each do |idx|
            s_start = bounds[idx]
            s_end   = bounds[idx + 1]
            seg_len = (s_end - s_start).round(2)
            seg = base_tube.dup
            seg[:id]   = "#{base_tube[:id]}.#{idx + 1}"
            seg[:name] = "#{base_tube[:name]} (trecho #{idx + 1})"
            seg[:length_mm] = seg_len
            if base_tube[:axis] == 'x'
              seg[:x_mm] = base_tube[:x_mm] + s_start
              seg[:w_mm] = seg_len
            else
              seg[:z_mm] = base_tube[:z_mm] + s_start
              seg[:h_mm] = seg_len
            end
            # Pontas internas na emenda têm corte reto (0°)
            seg[:cut_a_deg] = idx == 0 ? base_tube[:cut_a_deg] : 0.0
            seg[:cut_b_deg] = (idx == bounds.length - 2) ? base_tube[:cut_b_deg] : 0.0
            tubes << seg
          end
        end
      end

      # 1. Montante Lateral Esquerdo (c1 / latEsq)
      unless open_left
        z_c1 = (corner == 'passante_h') ? (z0 + fw_f) : z0
        h_c1 = (corner == 'passante_h') ? (eff_h - 2.0 * fw_f) : eff_h
        add_segmented_tube.call({
          id: 'C1', slot: 'c1', name: 'Lateral esquerda da moldura', group_role: 'quadro',
          axis: 'z', x_mm: x0, y_mm: y0, z_mm: z_c1,
          w_mm: fw_f, d_mm: fd_y, h_mm: h_c1, length_mm: h_c1.round(2),
          profile_id: prof_frame[:id], profile_name: prof_frame[:name], wall_mm: prof_frame[:wall_mm],
          material: mat_label, cut_a_deg: cut_deg, cut_b_deg: cut_deg, color: prof_frame[:color]
        })
      end

      # 2. Montante Lateral Direito (c2 / latDir)
      unless open_right
        z_c2 = (corner == 'passante_h') ? (z0 + fw_f) : z0
        h_c2 = (corner == 'passante_h') ? (eff_h - 2.0 * fw_f) : eff_h
        add_segmented_tube.call({
          id: 'C2', slot: 'c2', name: 'Lateral direita da moldura', group_role: 'quadro',
          axis: 'z', x_mm: x0 + eff_w - fw_f, y_mm: y0, z_mm: z_c2,
          w_mm: fw_f, d_mm: fd_y, h_mm: h_c2, length_mm: h_c2.round(2),
          profile_id: prof_frame[:id], profile_name: prof_frame[:name], wall_mm: prof_frame[:wall_mm],
          material: mat_label, cut_a_deg: cut_deg, cut_b_deg: cut_deg, color: prof_frame[:color]
        })
      end

      # 3. Travessa Inferior (inf) e Superior (sup) da moldura
      x_sup_inf = (corner == 'encosto') ? (x0 + esp_esq) : x0
      w_sup_inf = (corner == 'encosto') ? (eff_w - esp_esq - esp_dir) : eff_w

      add_segmented_tube.call({
        id: 'INF', slot: 'inf', name: 'Travessa inferior da moldura', group_role: 'quadro',
        axis: 'x', x_mm: x_sup_inf, y_mm: y0, z_mm: z0,
        w_mm: w_sup_inf, d_mm: fd_y, h_mm: fw_f, length_mm: w_sup_inf.round(2),
        profile_id: prof_frame[:id], profile_name: prof_frame[:name], wall_mm: prof_frame[:wall_mm],
        material: mat_label, cut_a_deg: cut_deg, cut_b_deg: cut_deg, color: prof_frame[:color]
      })

      add_segmented_tube.call({
        id: 'SUP', slot: 'sup', name: 'Travessa superior da moldura', group_role: 'quadro',
        axis: 'x', x_mm: x_sup_inf, y_mm: y0, z_mm: z0 + eff_h - fw_f,
        w_mm: w_sup_inf, d_mm: fd_y, h_mm: fw_f, length_mm: w_sup_inf.round(2),
        profile_id: prof_frame[:id], profile_name: prof_frame[:name], wall_mm: prof_frame[:wall_mm],
        material: mat_label, cut_a_deg: cut_deg, cut_b_deg: cut_deg, color: prof_frame[:color]
      })

      # Alinhamento Y das travessas internas em relação ao quadro (Frente / Centro / Atrás)
      y_trav = case cfg['trav_align']
               when 'centro' then y0 + (fd_y - td_y) / 2.0
               when 'atras'  then y0 + (fd_y - td_y)
               else               y0
               end

      # 4. Montantes Verticais Internos
      inner_w = eff_w - esp_esq - esp_dir
      inner_h = eff_h - 2.0 * fw_f
      v_positions = if cfg['custom_v_xs_mm'] && !cfg['custom_v_xs_mm'].empty?
                      cfg['custom_v_xs_mm'].map { |px| px.to_f - tw_f / 2.0 }
                    else
                      n_v = cfg['trav_v_count'].to_i
                      if n_v > 0
                        step_x = (inner_w - n_v * tw_f) / (n_v + 1).to_f
                        (1..n_v).map { |i| x0 + esp_esq + i * step_x + (i - 1) * tw_f }
                      else
                        []
                      end
                    end

      v_positions.each_with_index do |vx, idx|
        next if inner_h <= 1.0
        add_segmented_tube.call({
          id: "M#{idx + 1}", slot: "montante_#{idx + 1}", name: "Montante #{idx + 1}", group_role: 'montantes',
          axis: 'z', x_mm: vx.round(2), y_mm: y_trav.round(2), z_mm: (z0 + fw_f).round(2),
          w_mm: tw_f, d_mm: td_y, h_mm: inner_h.round(2), length_mm: inner_h.round(2),
          profile_id: prof_trav[:id], profile_name: prof_trav[:name], wall_mm: prof_trav[:wall_mm],
          material: mat_label, cut_a_deg: 0.0, cut_b_deg: 0.0, color: prof_trav[:color]
        })
      end

      # 5. Travessas Horizontais Internos (com suporte a deslocamentos A002: sup, inf, todas)
      h_positions = if cfg['custom_h_zs_mm'] && !cfg['custom_h_zs_mm'].empty?
                      cfg['custom_h_zs_mm'].map { |pz| pz.to_f - tw_f / 2.0 }
                    else
                      n_h = cfg['trav_h_count'].to_i
                      if n_h > 0
                        avail_z = inner_h - cfg['desloc_sup_mm'] - cfg['desloc_inf_mm']
                        step_z  = (avail_z - n_h * tw_f) / (n_h + 1).to_f
                        (1..n_h).map do |j|
                          z0 + fw_f + cfg['desloc_inf_mm'] + cfg['desloc_todas_mm'] + j * step_z + (j - 1) * tw_f
                        end
                      else
                        []
                      end
                    end

      h_positions.each_with_index do |hz, jdx|
        next if inner_w <= 1.0
        add_segmented_tube.call({
          id: "T#{jdx + 1}", slot: "travessa_#{jdx + 1}", name: "Travessa #{jdx + 1}", group_role: 'travessas',
          axis: 'x', x_mm: (x0 + esp_esq).round(2), y_mm: y_trav.round(2), z_mm: hz.round(2),
          w_mm: inner_w.round(2), d_mm: td_y, h_mm: tw_f, length_mm: inner_w.round(2),
          profile_id: prof_trav[:id], profile_name: prof_trav[:name], wall_mm: prof_trav[:wall_mm],
          material: mat_label, cut_a_deg: 0.0, cut_b_deg: 0.0, color: prof_trav[:color]
        })
      end

      {
        tubes: tubes,
        seams: seams_info,
        summary: summarize_tubes(tubes, cfg['bar_mm'], cfg['kerf_mm'])
      }
    end

    # Regera todas as estruturas paramétricas do modelo (ex.: após mudar a barra comercial)
    def self.regenerate_all_frames(model = Sketchup.active_model)
      return 0 unless model
      frames = model.active_entities.grep(Sketchup::Group).select do |g|
        g.get_attribute(Catalog::ATTR_DICT, 'kind') == 'parametric_frame'
      end
      frames.each do |grp|
        params = JSON.parse(grp.get_attribute(Catalog::ATTR_DICT, 'params_json').to_s) rescue {}
        create_or_update_frame(params, grp)
      end
      model.selection.clear
      frames.size
    end

    # Calcula posições de emenda (mm a partir do início do tubo)
    def self.compute_seam_positions(slot, total_len, bar_mm, strategy, overrides)
      ov = overrides && (overrides[slot] || overrides[slot.to_sym])
      if ov && ov['positions'].is_a?(Array) && !ov['positions'].empty?
        valid = ov['positions'].map(&:to_f).select { |p| p > 50.0 && p < total_len - 50.0 }.sort
        return valid unless valid.empty?
      end

      n_bars = (total_len / bar_mm).ceil
      return [] if n_bars <= 1

      if strategy == 'iguais'
        step = total_len / n_bars.to_f
        (1...n_bars).map { |i| (step * i).round(1) }
      else
        # Barra inteira + complemento
        pts = []
        pos = bar_mm
        while pos < total_len - 1e-3
          pts << pos.round(1)
          pos += bar_mm
        end
        pts
      end
    end

    # Consolida lista de corte e calcula barras necessárias (FFD 1D com compensação angular kerf/cos(theta))
    def self.summarize_tubes(tubes, bar_mm = 6000.0, kerf_mm = 3.0)
      total_linear_m = 0.0
      by_group = {}

      tubes.each do |t|
        len = t[:length_mm].to_f
        total_linear_m += len / 1000.0
        key = "#{t[:material]}|#{t[:profile_name]}|#{t[:wall_mm]}"
        by_group[key] ||= {
          material: t[:material],
          profile_name: t[:profile_name],
          wall_mm: t[:wall_mm],
          color: t[:color],
          pieces: []
        }
        extra_kerf = [t[:cut_a_deg].to_f, t[:cut_b_deg].to_f].sum do |ang|
          ang > 0.05 ? kerf_mm * ((1.0 / Math.cos(ang * Math::PI / 180.0)) - 1.0) : 0.0
        end
        by_group[key][:pieces] << {
          id: t[:id],
          name: t[:name],
          len_mm: len.round(1),
          stock_mm: (len + extra_kerf).round(2),
          cut_a: t[:cut_a_deg],
          cut_b: t[:cut_b_deg]
        }
      end

      # FFD Bin Packing por tipo de tubo
      total_bars = 0
      groups_out = by_group.values.map do |g|
        sorted = g[:pieces].sort_by { |p| -p[:stock_mm] }
        bars = []
        sorted.each do |p|
          placed = false
          bars.each do |b|
            needed = p[:stock_mm] + kerf_mm
            if b[:remaining_mm] + 1e-3 >= needed
              b[:pieces] << p
              b[:used_mm] += needed
              b[:remaining_mm] -= needed
              placed = true
              break
            end
          end
          unless placed
            bars << {
              pieces: [p],
              used_mm: p[:stock_mm],
              remaining_mm: [bar_mm - p[:stock_mm], 0.0].max
            }
          end
        end
        total_bars += bars.length
        used_sum = bars.sum { |b| b[:used_mm] }
        denom    = [bars.length * bar_mm, 1.0].max
        g.merge(
          bars_count: bars.length,
          utilization_pct: ((used_sum / denom) * 100.0).round(1),
          bars: bars
        )
      end

      {
        total_pieces: tubes.length,
        total_linear_m: total_linear_m.round(2),
        total_bars: total_bars,
        bar_mm: bar_mm,
        kerf_mm: kerf_mm,
        groups: groups_out
      }
    end

    # Desenha um tubo 3D no SketchUp (com chanfro 45° real nas extremidades quando esquadria!)
    def self.draw_tube_3d(model, entities, tube, color_mode = 'tipo')
      grp = entities.add_group
      grp.name = "#{tube[:id]} - #{tube[:name]} (#{tube[:length_mm].round(0)}mm)"

      x0 = mm(tube[:x_mm])
      y0 = mm(tube[:y_mm])
      z0 = mm(tube[:z_mm])
      w  = mm(tube[:w_mm])
      d  = mm(tube[:d_mm])
      h  = mm(tube[:h_mm])

      pts_front = nil
      if tube[:cut_a_deg].to_f == 45.0 && tube[:cut_b_deg].to_f == 45.0 && tube[:group_role] == 'quadro'
        # Meia-esquadria 45° no plano frontal X-Z (fiel ao bloco A003)
        pts_front = case tube[:slot]
                    when 'inf'
                      [
                        Geom::Point3d.new(x0, y0, z0),
                        Geom::Point3d.new(x0 + w, y0, z0),
                        Geom::Point3d.new(x0 + w - h, y0, z0 + h),
                        Geom::Point3d.new(x0 + h, y0, z0 + h)
                      ]
                    when 'sup'
                      [
                        Geom::Point3d.new(x0 + h, y0, z0),
                        Geom::Point3d.new(x0 + w - h, y0, z0),
                        Geom::Point3d.new(x0 + w, y0, z0 + h),
                        Geom::Point3d.new(x0, y0, z0 + h)
                      ]
                    when 'c1'
                      [
                        Geom::Point3d.new(x0, y0, z0),
                        Geom::Point3d.new(x0 + w, y0, z0 + w),
                        Geom::Point3d.new(x0 + w, y0, z0 + h - w),
                        Geom::Point3d.new(x0, y0, z0 + h)
                      ]
                    when 'c2'
                      [
                        Geom::Point3d.new(x0 + w, y0, z0),
                        Geom::Point3d.new(x0 + w, y0, z0 + h),
                        Geom::Point3d.new(x0, y0, z0 + h - w),
                        Geom::Point3d.new(x0, y0, z0 + w)
                      ]
                    end
      end
      # Tubo horizontal com corte inclinado (tubo avulso, trecho com emenda): trapézio no plano X-Z.
      # A face maior fica embaixo; na travessa superior da moldura ela fica em cima.
      if pts_front.nil? && tube[:axis] == 'x' && (tube[:cut_a_deg].to_f > 0.0 || tube[:cut_b_deg].to_f > 0.0)
        la = h * Math.tan(tube[:cut_a_deg].to_f.clamp(0.0, 75.0).degrees)
        lb = h * Math.tan(tube[:cut_b_deg].to_f.clamp(0.0, 75.0).degrees)
        pts_front = if tube[:slot].to_s == 'sup'
                      [
                        Geom::Point3d.new(x0 + la, y0, z0),
                        Geom::Point3d.new(x0 + w - lb, y0, z0),
                        Geom::Point3d.new(x0 + w, y0, z0 + h),
                        Geom::Point3d.new(x0, y0, z0 + h)
                      ]
                    else
                      [
                        Geom::Point3d.new(x0, y0, z0),
                        Geom::Point3d.new(x0 + w, y0, z0),
                        Geom::Point3d.new(x0 + w - lb, y0, z0 + h),
                        Geom::Point3d.new(x0 + la, y0, z0 + h)
                      ]
                    end
      end

      if pts_front
        face = grp.entities.add_face(pts_front)
        if face
          face.reverse! if face.normal.y < 0
          face.pushpull(d)
        end
      else
        # Prisma retangular padrão
        pts = [
          Geom::Point3d.new(x0,     y0,     z0),
          Geom::Point3d.new(x0 + w, y0,     z0),
          Geom::Point3d.new(x0 + w, y0 + d, z0),
          Geom::Point3d.new(x0,     y0 + d, z0)
        ]
        face = grp.entities.add_face(pts)
        if face
          face.reverse! if face.normal.z < 0
          face.pushpull(h)
        end
      end

      hex = resolve_tube_color(tube, color_mode)
      grp.material = ensure_material(model, "CS_ACM360_#{hex}", hex)
      grp.set_attribute(Catalog::ATTR_DICT, 'piece_id', tube[:id])
      grp.set_attribute(Catalog::ATTR_DICT, 'slot', tube[:slot])
      grp.set_attribute(Catalog::ATTR_DICT, 'length_mm', tube[:length_mm])
      grp.set_attribute(Catalog::ATTR_DICT, 'profile_name', tube[:profile_name])
      grp
    end

    def self.resolve_tube_color(tube, color_mode)
      case color_mode
      when 'unica'
        '#475569'
      when 'comprimento'
        palette = ['#2563EB', '#059669', '#D97706', '#DC2626', '#7C3AED', '#0891B2', '#DB2777']
        palette[(tube[:length_mm].round(0) / 50) % palette.length]
      else
        tube[:color] || '#2563EB'
      end
    end

    def self.draw_clearance_guide(model, entities, cfg)
      g = entities.add_group
      g.name = 'Guia de Folga Externa'
      w = mm(cfg['width_mm'])
      h = mm(cfg['height_mm'])
      pts = [
        Geom::Point3d.new(0, 0, 0),
        Geom::Point3d.new(w, 0, 0),
        Geom::Point3d.new(w, 0, h),
        Geom::Point3d.new(0, 0, h),
        Geom::Point3d.new(0, 0, 0)
      ]
      g.entities.add_edges(pts)
    end

    def self.save_frame_attributes(group, cfg, recipe)
      group.set_attribute(Catalog::ATTR_DICT, 'kind', 'parametric_frame')
      group.set_attribute(Catalog::ATTR_DICT, 'version', CS_ACM360_BETA::PLUGIN_VERSION)
      group.set_attribute(Catalog::ATTR_DICT, 'params_json', JSON.generate(cfg))
      group.set_attribute(Catalog::ATTR_DICT, 'tubes_json', JSON.generate(recipe[:tubes]))
      group.set_attribute(Catalog::ATTR_DICT, 'seams_json', JSON.generate(recipe[:seams]))
      group.set_attribute(Catalog::ATTR_DICT, 'summary_json', JSON.generate(recipe[:summary]))
    end

    def self.read_selected_frame
      model = Sketchup.active_model
      return nil unless model
      sel = model.selection.first
      return nil unless sel && sel.is_a?(Sketchup::Group)
      return nil unless sel.get_attribute(Catalog::ATTR_DICT, 'kind') == 'parametric_frame'
      sel
    end

    # Aplica modo de cor em todas as estruturas do modelo
    def self.apply_color_mode_to_model(mode)
      model = Sketchup.active_model
      return unless model
      model.start_operation("Modo de Cor: #{mode}", true)
      model.active_entities.grep(Sketchup::Group).each do |grp|
        next unless grp.get_attribute(Catalog::ATTR_DICT, 'kind') == 'parametric_frame'
        raw = grp.get_attribute(Catalog::ATTR_DICT, 'params_json')
        next unless raw
        cfg = JSON.parse(raw)
        cfg['color_mode'] = mode
        create_or_update_frame(cfg, grp)
      end
      model.commit_operation
    end

    def self.ensure_material(model, name, hex_str)
      mat = model.materials[name]
      return mat if mat
      mat = model.materials.add(name)
      clean = hex_str.to_s.sub('#', '')
      r = clean[0..1].to_i(16)
      g = clean[2..3].to_i(16)
      b = clean[4..5].to_i(16)
      mat.color = Sketchup::Color.new(r, g, b)
      mat
    end

    def self.ensure_layer(model, layer_name, entity)
      layer = model.layers[layer_name] || model.layers.add(layer_name)
      entity.layer = layer if entity && entity.respond_to?(:layer=)
    end
  end
end
