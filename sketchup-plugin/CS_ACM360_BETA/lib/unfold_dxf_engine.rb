# encoding: UTF-8
# ==============================================================================
# CS_ACM360_BETA::UnfoldDxfEngine
# Motor de Planificação 2D/3D de Bandejas ACM (desconto de fator de dobra,
# retornos, abas, refile e cantos 45°), Geração de Geometria Planificada no
# SketchUp, Nesting 2D de Chapas ACM, Exportação DXF AC1009 (AutoCAD R12) com
# camadas oficiais (ACM_CHAPA, ACM_CORTE, ACM_VINCO, ACM_DIRECAO, ACM_ETIQUETAS)
# e Exportação de Pacote JSON para o Painel Web CS Fachadas ERP.
# ==============================================================================

require 'json'

module CS_ACM360_BETA
  module UnfoldDxfEngine
    MM_TO_INCH = 1.0 / 25.4

    # Camadas oficiais do DXF CNC extraídas do ACM360 (nesting_bundle.js)
    DXF_LAYERS = {
      'ACM_CHAPA'     => 7,   # Branco
      'ACM_CORTE'     => 1,   # Vermelho (Corte passante CNC)
      'ACM_VINCO'     => 174, # Magenta/Azul (Fresa em V de dobra)
      'ACM_DIRECAO'   => 8,   # Cinza (Seta de sentido do ACM)
      'ACM_ETIQUETAS' => 7    # Branco (Texto / Código da peça)
    }.freeze

    def self.mm(val)
      val.to_f * MM_TO_INCH
    end

    # Calcula a planificação exata (linhas de corte e linhas de vinco/dobra em mm)
    # para uma Bandeja ACM Paramétrica
    def self.compute_tray_unfold(cfg)
      w = cfg['width_mm'].to_f
      h = cfg['height_mm'].to_f
      k = (cfg['bend_factor_mm'] || Settings.bend_factor_mm).to_f
      refile_default = (cfg['refile_tab_mm'] || Settings.get('refile_tab_mm')).to_f
      edges = cfg['edges'] || {}

      ext_side = lambda do |side_key|
        e = edges[side_key] || {}
        type = (e['type'] || 'dobra').to_s
        ret  = e['return_mm'].to_f
        aba  = e['aba_mm'].to_f
        case type
        when 'corte'
          { total: 0.0, folds: [] }
        when 'refile'
          r_mm = [ret > 0 ? ret : refile_default, 5.0].max
          { total: r_mm, folds: [] }
        when 'dobra'
          eff_r = [ret - k, 0.0].max
          { total: eff_r, folds: [eff_r] }
        when 'dobra_aba'
          eff_r = [ret - k, 0.0].max
          eff_a = [aba - k, 0.0].max
          { total: eff_r + eff_a, folds: [eff_a, eff_a + eff_r] }
        else
          eff_r = [ret - k, 0.0].max
          { total: eff_r, folds: [eff_r] }
        end
      end

      s_esq = ext_side.call('esq')
      s_dir = ext_side.call('dir')
      s_inf = ext_side.call('inf')
      s_sup = ext_side.call('sup')

      flat_w = (s_esq[:total] + w + s_dir[:total]).round(2)
      flat_h = (s_inf[:total] + h + s_sup[:total]).round(2)

      # Coordenadas da face frontal dentro da chapa planificada
      fx0 = s_esq[:total]
      fx1 = s_esq[:total] + w
      fy0 = s_inf[:total]
      fy1 = s_inf[:total] + h

      cut_lines  = []
      fold_lines = []

      add_line = lambda do |arr, x1, y1, x2, y2|
        next if Math.hypot(x2 - x1, y2 - y1) < 0.05
        arr << { 'x1' => x1.round(2), 'y1' => y1.round(2), 'x2' => x2.round(2), 'y2' => y2.round(2) }
      end

      # Linhas de vinco/fresa da face central e abas
      if s_esq[:total] > 0
        add_line.call(fold_lines, fx0, fy0, fx0, fy1)
        if s_esq[:folds].length == 2
          add_line.call(fold_lines, s_esq[:folds][0], fy0, s_esq[:folds][0], fy1)
        end
      end
      if s_dir[:total] > 0
        add_line.call(fold_lines, fx1, fy0, fx1, fy1)
        if s_dir[:folds].length == 2
          fold_x = fx1 + (s_dir[:total] - s_dir[:folds][0])
          add_line.call(fold_lines, fold_x, fy0, fold_x, fy1)
        end
      end
      if s_inf[:total] > 0
        add_line.call(fold_lines, fx0, fy0, fx1, fy0)
        if s_inf[:folds].length == 2
          add_line.call(fold_lines, fx0, s_inf[:folds][0], fx1, s_inf[:folds][0])
        end
      end
      if s_sup[:total] > 0
        add_line.call(fold_lines, fx0, fy1, fx1, fy1)
        if s_sup[:folds].length == 2
          fold_y = fy1 + (s_sup[:total] - s_sup[:folds][0])
          add_line.call(fold_lines, fx0, fold_y, fx1, fold_y)
        end
      end

      # Contorno de corte com entalhes nos 4 cantos (para alívio dos retornos/abas)
      # Canto Inferior-Esquerdo: entalhe de (0..fx0, 0..fy0)
      # Canto Inferior-Direito:  entalhe de (fx1..flat_w, 0..fy0)
      # Canto Superior-Direito:  entalhe de (fx1..flat_w, fy1..flat_h)
      # Canto Superior-Esquerdo: entalhe de (0..fx0, fy1..flat_h)
      pts = []
      # Base inferior (da esquerda para a direita)
      pts << [fx0, 0.0]
      pts << [fx1, 0.0]
      if s_inf[:total] > 0 && s_dir[:total] > 0
        pts << [fx1, fy0]
        pts << [flat_w, fy0]
      elsif s_inf[:total] == 0 && s_dir[:total] > 0
        pts << [flat_w, 0.0]
      end
      # Lado direito (de baixo para cima)
      pts << [flat_w, fy1]
      if s_sup[:total] > 0 && s_dir[:total] > 0
        pts << [fx1, fy1]
        pts << [fx1, flat_h]
      elsif s_sup[:total] == 0 && s_dir[:total] > 0
        pts << [flat_w, flat_h]
      end
      # Topo superior (da direita para a esquerda)
      pts << [fx0, flat_h]
      if s_sup[:total] > 0 && s_esq[:total] > 0
        pts << [fx0, fy1]
        pts << [0.0, fy1]
      elsif s_sup[:total] == 0 && s_esq[:total] > 0
        pts << [0.0, flat_h]
      end
      # Lado esquerdo (de cima para baixo)
      pts << [0.0, fy0]
      if s_inf[:total] > 0 && s_esq[:total] > 0
        pts << [fx0, fy0]
      end

      # Remove pontos consecutivos idênticos e fecha o polígono de corte
      clean_pts = []
      pts.each do |pt|
        if clean_pts.empty? || Math.hypot(pt[0] - clean_pts.last[0], pt[1] - clean_pts.last[1]) > 0.05
          clean_pts << pt
        end
      end

      clean_pts.each_with_index do |pt, i|
        nxt = clean_pts[(i + 1) % clean_pts.length]
        add_line.call(cut_lines, pt[0], pt[1], nxt[0], nxt[1])
      end

      area_m2 = ((flat_w * flat_h) / 1_000_000.0).round(3)

      {
        'id'         => cfg['id'],
        'code'       => cfg['code'] || 'P01',
        'name'       => cfg['name'],
        'quantity'   => (cfg['quantity'] || 1).to_i,
        'width'      => flat_w,
        'height'     => flat_h,
        'front_w_mm' => w,
        'front_h_mm' => h,
        'area_m2'    => area_m2,
        'cut_lines'  => cut_lines,
        'fold_lines' => fold_lines
      }
    end

    # Gera a geometria 2D planificada diretamente no modelo 3D do SketchUp (ao lado da peça)
    def self.place_unfolded_tray_in_model(tray_group = nil)
      model = Sketchup.active_model
      return nil unless model

      grp = tray_group || model.selection.first
      unless grp && grp.is_a?(Sketchup::Group) && grp.get_attribute(Catalog::ATTR_DICT, 'kind') == 'acm_tray'
        UI.messagebox('Selecione uma Bandeja ACM gerada pelo plugin para planificar no 3D.')
        return nil
      end

      raw_unfold = grp.get_attribute(Catalog::ATTR_DICT, 'unfold_json')
      return nil unless raw_unfold
      unfold = JSON.parse(raw_unfold)

      model.start_operation('Planificar Bandeja ACM no 3D (CS ACM360)', true)
      begin
        flat_grp = model.active_entities.add_group
        flat_grp.name = "Planificada - #{unfold['code']} #{unfold['name']} (#{unfold['width'].round(0)}x#{unfold['height'].round(0)}mm)"
        FrameKernel.ensure_layer(model, 'CS_ACM360_Planificadas', flat_grp)

        bb = grp.bounds
        offset_x = bb.max.x + mm(300.0)
        offset_y = bb.min.y

        # Desenha linhas de corte e vinco no plano X-Y (Z = 0)
        cut_grp = flat_grp.entities.add_group
        cut_grp.name = 'ACM_CORTE'
        mat_cut = FrameKernel.ensure_material(model, 'CS_ACM_Corte_Red', '#DC2626')
        (unfold['cut_lines'] || []).each do |ln|
          p1 = Geom::Point3d.new(offset_x + mm(ln['x1']), offset_y + mm(ln['y1']), 0)
          p2 = Geom::Point3d.new(offset_x + mm(ln['x2']), offset_y + mm(ln['y2']), 0)
          cut_grp.entities.add_line(p1, p2)
        end
        cut_grp.material = mat_cut

        fold_grp = flat_grp.entities.add_group
        fold_grp.name = 'ACM_VINCO'
        mat_fold = FrameKernel.ensure_material(model, 'CS_ACM_Vinco_Magenta', '#C026D3')
        (unfold['fold_lines'] || []).each do |ln|
          p1 = Geom::Point3d.new(offset_x + mm(ln['x1']), offset_y + mm(ln['y1']), mm(0.5))
          p2 = Geom::Point3d.new(offset_x + mm(ln['x2']), offset_y + mm(ln['y2']), mm(0.5))
          fold_grp.entities.add_line(p1, p2)
        end
        fold_grp.material = mat_fold

        model.commit_operation
        model.selection.clear
        model.selection.add(flat_grp)
        flat_grp
      rescue StandardError => e
        model.abort_operation
        UI.messagebox("Erro ao planificar no 3D: #{e.message}")
        nil
      end
    end

    # Nesting 2D rápido de peças planificadas em chapas de ACM (ex: 5000 x 1220 mm)
    def self.nest_unfolded_parts(parts, sheet_w_mm = 5000.0, sheet_h_mm = 1220.0, gap_mm = 8.0, margin_mm = 10.0)
      expanded = []
      parts.each_with_index do |p, idx|
        qty = [(p['quantity'] || 1).to_i, 1].max
        qty.times do |inst_i|
          expanded << p.merge(
            'instance_index' => inst_i,
            'part_code'      => qty > 1 ? "#{p['code'] || "P#{idx + 1}"}-#{inst_i + 1}" : (p['code'] || "P#{idx + 1}")
          )
        end
      end

      # Ordena da maior área para a menor
      expanded.sort_by! { |item| -(item['width'].to_f * item['height'].to_f) }

      sheets = []
      unplaced = []

      expanded.each do |item|
        pw = item['width'].to_f
        ph = item['height'].to_f
        rotated = false

        if pw > (sheet_w_mm - 2 * margin_mm) || ph > (sheet_h_mm - 2 * margin_mm)
          if ph <= (sheet_w_mm - 2 * margin_mm) && pw <= (sheet_h_mm - 2 * margin_mm)
            pw, ph = ph, pw
            rotated = true
          else
            unplaced << item
            next
          end
        end

        placed = false
        sheets.each do |sh|
          if sh[:cursor_x] + pw <= sheet_w_mm - margin_mm && sh[:cursor_y] + ph <= sheet_h_mm - margin_mm
            sh[:placements] << build_placement(item, sh[:cursor_x], sh[:cursor_y], pw, ph, rotated)
            sh[:cursor_x] += pw + gap_mm
            sh[:row_h] = [sh[:row_h], ph].max
            placed = true
            break
          elsif margin_mm + pw <= sheet_w_mm - margin_mm && (sh[:cursor_y] + sh[:row_h] + gap_mm + ph) <= sheet_h_mm - margin_mm
            sh[:cursor_y] += sh[:row_h] + gap_mm
            sh[:cursor_x] = margin_mm + pw + gap_mm
            sh[:row_h] = ph
            sh[:placements] << build_placement(item, margin_mm, sh[:cursor_y], pw, ph, rotated)
            placed = true
            break
          end
        end

        unless placed
          new_sh = {
            sheet_index: sheets.length,
            sheet_w_mm: sheet_w_mm,
            sheet_h_mm: sheet_h_mm,
            cursor_x: margin_mm + pw + gap_mm,
            cursor_y: margin_mm,
            row_h: ph,
            placements: [build_placement(item, margin_mm, margin_mm, pw, ph, rotated)]
          }
          sheets << new_sh
        end
      end

      sheet_area = [sheet_w_mm * sheet_h_mm, 1.0].max
      sheets.each do |sh|
        used = sh[:placements].sum { |pl| pl['width'] * pl['height'] }
        sh[:used_area_m2]    = (used / 1_000_000.0).round(3)
        sh[:free_area_m2]    = (((sheet_area - used) / 1_000_000.0)).round(3)
        sh[:utilization_pct] = ((used / sheet_area) * 100.0).round(1)
      end

      {
        'sheet_w_mm'   => sheet_w_mm,
        'sheet_h_mm'   => sheet_h_mm,
        'total_sheets' => sheets.length,
        'sheets'       => sheets,
        'unplaced'     => unplaced
      }
    end

    def self.build_placement(item, x, y, w, h, rotated)
      cuts  = (item['cut_lines'] || []).map  { |ln| transform_line(ln, x, y, rotated, item['height'].to_f) }
      folds = (item['fold_lines'] || []).map { |ln| transform_line(ln, x, y, rotated, item['height'].to_f) }
      {
        'part_id'    => item['id'],
        'part_code'  => item['part_code'],
        'part_name'  => item['name'],
        'x'          => x.round(2),
        'y'          => y.round(2),
        'width'      => w.round(2),
        'height'     => h.round(2),
        'rotated'    => rotated,
        'cut_lines'  => cuts,
        'fold_lines' => folds
      }
    end

    def self.transform_line(ln, ox, oy, rotated, orig_h)
      x1 = ln['x1'].to_f
      y1 = ln['y1'].to_f
      x2 = ln['x2'].to_f
      y2 = ln['y2'].to_f
      if rotated
        {
          'x1' => (ox + (orig_h - y1)).round(2),
          'y1' => (oy + x1).round(2),
          'x2' => (ox + (orig_h - y2)).round(2),
          'y2' => (oy + x2).round(2)
        }
      else
        {
          'x1' => (ox + x1).round(2),
          'y1' => (oy + y1).round(2),
          'x2' => (ox + x2).round(2),
          'y2' => (oy + y2).round(2)
        }
      end
    end

    # Gera conteúdo DXF AC1009 (AutoCAD R12) idêntico ao formato oficial do ACM360
    def self.generate_dxf_ac1009(sheet_w_mm, sheet_h_mm, placements)
      out = +"999\nDXF generated by CS_ACM360 - Cutting Plan Export\n"
      out << "0\nSECTION\n2\nHEADER\n9\n$ACADVER\n1\nAC1009\n9\n$INSUNITS\n70\n4\n0\nENDSEC\n"

      # Tabelas LTYPE e LAYER
      out << "0\nSECTION\n2\nTABLES\n0\nTABLE\n2\nLTYPE\n70\n1\n0\nLTYPE\n2\nCONTINUOUS\n70\n0\n3\nSolid line\n72\n65\n73\n0\n40\n0.0\n0\nENDTAB\n"
      out << "0\nTABLE\n2\nLAYER\n70\n6\n0\nLAYER\n2\n0\n70\n0\n62\n7\n6\nCONTINUOUS\n"
      DXF_LAYERS.each do |lname, color_aci|
        out << "0\nLAYER\n2\n#{lname}\n70\n0\n62\n#{color_aci}\n6\nCONTINUOUS\n"
      end
      out << "0\nENDTAB\n0\nENDSEC\n"

      # Entidades (Contorno da Chapa + Cortes + Vincos + Setas de Direção + Etiquetas)
      out << "0\nSECTION\n2\nENTITIES\n"

      # 1. Contorno da Chapa (ACM_CHAPA)
      sheet_lines = [
        [0, 0, sheet_w_mm, 0],
        [sheet_w_mm, 0, sheet_w_mm, sheet_h_mm],
        [sheet_w_mm, sheet_h_mm, 0, sheet_h_mm],
        [0, sheet_h_mm, 0, 0]
      ]
      sheet_lines.each do |x1, y1, x2, y2|
        out << dxf_line('ACM_CHAPA', x1, y1, x2, y2)
      end

      # 2. Seta de Direção do ACM (ACM_DIRECAO)
      arrow_y = sheet_h_mm + 40.0
      out << dxf_line('ACM_DIRECAO', 100.0, arrow_y, 220.0, arrow_y)
      out << dxf_line('ACM_DIRECAO', 195.0, arrow_y + 15.0, 220.0, arrow_y)
      out << dxf_line('ACM_DIRECAO', 195.0, arrow_y - 15.0, 220.0, arrow_y)

      # 3. Peças (ACM_CORTE, ACM_VINCO, ACM_ETIQUETAS)
      placements.each do |pl|
        (pl['cut_lines'] || []).each do |ln|
          out << dxf_line('ACM_CORTE', ln['x1'], ln['y1'], ln['x2'], ln['y2'])
        end
        (pl['fold_lines'] || []).each do |ln|
          out << dxf_line('ACM_VINCO', ln['x1'], ln['y1'], ln['x2'], ln['y2'])
        end
        cx = pl['x'].to_f + pl['width'].to_f / 2.0
        cy = pl['y'].to_f + pl['height'].to_f / 2.0
        label = "#{pl['part_code']} #{pl['part_name']}".strip
        out << dxf_text('ACM_ETIQUETAS', cx, cy, 22.0, label)
      end

      out << "0\nENDSEC\n0\nEOF\n"
      out
    end

    def self.dxf_line(layer, x1, y1, x2, y2)
      format(
        "0\nLINE\n8\n%s\n10\n%.4f\n20\n%.4f\n30\n0.0000\n11\n%.4f\n21\n%.4f\n31\n0.0000\n",
        layer, x1.to_f, y1.to_f, x2.to_f, y2.to_f
      )
    end

    def self.dxf_text(layer, x, y, height, text)
      clean = text.to_s.gsub(/[\r\n]+/, ' ')[0, 120]
      format(
        "0\nTEXT\n8\n%s\n10\n%.4f\n20\n%.4f\n30\n0.0000\n40\n%.4f\n1\n%s\n50\n0.0000\n",
        layer, x.to_f, y.to_f, height.to_f, clean
      )
    end

    # Exporta arquivo DXF das bandejas do modelo ativo com diálogo de salvamento
    def self.export_model_trays_to_dxf
      model = Sketchup.active_model
      return unless model

      trays = collect_model_unfolded_trays(model)
      if trays.empty?
        UI.messagebox('Nenhuma Bandeja ACM encontrada no modelo. Crie uma bandeja primeiro.')
        return
      end

      nesting = nest_with_settings(trays)
      sheets = nesting['sheets']
      if sheets.empty?
        UI.messagebox('Não foi possível posicionar as peças na chapa padrão.')
        return
      end

      path = UI.savepanel('Exportar Plano de Corte DXF CNC (CS ACM360)', nil, 'Plano_Corte_ACM360.dxf')
      return unless path
      path += '.dxf' unless path.downcase.end_with?('.dxf')

      # Um arquivo por chapa (um trabalho no Aspire); com uma chapa só, o arquivo é o escolhido
      paths = sheets.each_with_index.map do |sh, i|
        p = sheets.size == 1 ? path : path.sub(/\.dxf\z/i, "_chapa#{i + 1}.dxf")
        File.write(p, generate_dxf_ac1009(nesting['sheet_w_mm'], nesting['sheet_h_mm'], sh[:placements]), mode: 'w:UTF-8')
        p
      end
      pieces = sheets.sum { |sh| sh[:placements].size }
      UI.messagebox("Arquivo DXF exportado com sucesso!\n\n#{pieces} peça(s) em #{sheets.size} chapa(s) de " \
                    "#{nesting['sheet_w_mm'].round}×#{nesting['sheet_h_mm'].round} mm\n" \
                    "Camadas geradas: ACM_CHAPA, ACM_CORTE, ACM_VINCO, ACM_DIRECAO, ACM_ETIQUETAS\n\n#{paths.join("\n")}")
    end

    # Nesting com chapa, espaçamento e margem das Configurações (M12)
    def self.nest_with_settings(parts)
      st = Settings.all
      nest_unfolded_parts(parts, st['acm_sheet_w_mm'], st['acm_sheet_h_mm'], st['nest_gap_mm'], st['nest_margin_mm'])
    end

    def self.collect_model_unfolded_trays(model)
      trays = []
      each_cs_group(model.entities) do |grp, kind|
        next unless kind == 'acm_tray'
        raw = grp.get_attribute(Catalog::ATTR_DICT, 'unfold_json')
        next unless raw
        parsed = JSON.parse(raw) rescue nil
        trays << parsed if parsed
      end
      trays
    end

    # Coleta o estado completo do modelo SketchUp (Estruturas + Bandejas ACM + Nesting + Plano 1D)
    # para sincronizar/publicar no Painel Web CS Fachadas ERP!
    def self.build_erp_payload(model = Sketchup.active_model)
      return {} unless model

      frames = []
      all_tubes = []
      trays  = []

      each_cs_group(model.entities) do |grp, kind|
        if kind == 'parametric_frame' || kind == 'single_tube'
          p_raw = grp.get_attribute(Catalog::ATTR_DICT, 'params_json')
          t_raw = grp.get_attribute(Catalog::ATTR_DICT, 'tubes_json')
          s_raw = grp.get_attribute(Catalog::ATTR_DICT, 'seams_json')
          tubes = t_raw ? (JSON.parse(t_raw) rescue []) : []
          frames << {
            'name'   => grp.name,
            'kind'   => kind,
            'params' => p_raw ? (JSON.parse(p_raw) rescue {}) : {},
            'tubes'  => tubes,
            'seams'  => s_raw ? (JSON.parse(s_raw) rescue []) : []
          }
          tubes.each do |tb|
            all_tubes << tb.transform_keys(&:to_sym)
          end
        elsif kind == 'acm_tray'
          t_cfg = grp.get_attribute(Catalog::ATTR_DICT, 'tray_json')
          u_cfg = grp.get_attribute(Catalog::ATTR_DICT, 'unfold_json')
          trays << {
            'tray'   => t_cfg ? (JSON.parse(t_cfg) rescue {}) : {},
            'unfold' => u_cfg ? (JSON.parse(u_cfg) rescue {}) : {}
          }
        end
      end

      unfold_list = trays.map { |t| t['unfold'] }.compact
      nesting = unfold_list.empty? ? nil : nest_with_settings(unfold_list)
      bar_plan = FrameKernel.summarize_tubes(all_tubes, Settings.get('bar_mm'), Settings.get('kerf_mm'))

      {
        'schema'       => 'CS_ACM360_ERP_V1',
        'exported_at'  => Time.now.strftime('%Y-%m-%dT%H:%M:%S'),
        'project_name' => model.title.empty? ? 'Projeto Fachada SketchUp' : model.title,
        'frames'       => frames,
        'trays'        => trays,
        'bar_plan'     => bar_plan,
        'nesting'      => nesting
      }
    end

    # Percorre o modelo inteiro (grupos e componentes do usuário, em qualquer nível)
    # entregando as estruturas, tubos avulsos e bandejas do plugin
    CS_KINDS = %w[parametric_frame single_tube acm_tray].freeze

    def self.each_cs_group(entities, &blk)
      entities.each do |e|
        if e.is_a?(Sketchup::Group)
          kind = e.get_attribute(Catalog::ATTR_DICT, 'kind')
          if CS_KINDS.include?(kind)
            blk.call(e, kind)
          else
            each_cs_group(e.entities, &blk)
          end
        elsif e.is_a?(Sketchup::ComponentInstance)
          each_cs_group(e.definition.entities, &blk)
        end
      end
    end

    def self.export_erp_json_dialog
      payload = build_erp_payload
      path = UI.savepanel('Publicar Projeto para CS Fachadas ERP (.json)', nil, 'Projeto_ACM360_ERP.json')
      return unless path
      path += '.json' unless path.downcase.end_with?('.json')
      File.write(path, JSON.pretty_generate(payload), mode: 'w:UTF-8')
      UI.messagebox("Pacote JSON publicado com sucesso para o CS Fachadas ERP!\n\nArquivo: #{path}\nImporte este arquivo na aba 'ACM360 Studio' do sistema web CS Fachadas.")
    end
  end
end
