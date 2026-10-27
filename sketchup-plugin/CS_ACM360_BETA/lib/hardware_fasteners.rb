# encoding: UTF-8
# ==============================================================================
# CS_ACM360 - Módulo de Fixadores e Colagem (hardware_fasteners.rb)
# Implementa os Módulos M3 (Colagem / Fita VHB) e M4 (Fixadores)
# ==============================================================================

module CS_ACM360_BETA
  module HardwareFasteners
    extend self

    # Espaçamento, recuo dos cantos e fita/rolo vêm das Configurações (M12)

    # --------------------------------------------------------------------------
    # M3: Cálculo de Colagem e Fita Dupla-Face 3M VHB
    # --------------------------------------------------------------------------
    # Calcula os metros lineares de fita VHB e reforços estruturais para as bandejas
    # selecionadas ou para todas as bandejas do modelo.
    # --------------------------------------------------------------------------
    def calculate_vhb_tape_requirements(tray_entities = nil)
      model = Sketchup.active_model
      trays = tray_entities || find_all_acm_trays(model)

      total_perimeter_mm = 0.0
      total_stiffener_mm = 0.0
      tray_count = trays.size

      # Mesma regra de ui/acm360-report.js (relatório M8)
      trays.each do |t|
        cfg = tray_cfg(t)
        w = cfg['width_mm'].to_f
        h = cfg['height_mm'].to_f
        qty = [cfg['quantity'].to_i, 1].max

        # Perímetro de colagem das abas/retornos (4 lados)
        total_perimeter_mm += 2.0 * (w + h) * qty

        # Reforços intermediários colados no verso do ACM (a cada ~400mm de vão)
        if h > 450.0
          vertical_stiffeners = [(w / 400.0).floor - 1, 0].max
          total_stiffener_mm += vertical_stiffeners * (h - 100.0) * qty
        end
      end

      total_tape_m = (total_perimeter_mm + total_stiffener_mm) / 1000.0
      tape = Settings.tape
      rolls_needed = (total_tape_m / tape['roll_m'].to_f).ceil

      # Primer 3M AP111 / 94 (aprox. 1 frasco de 250ml para cada 100 metros lineares)
      primer_cans = total_tape_m > 0 ? [(total_tape_m / 100.0).ceil, 1].max : 0

      {
        tray_count: tray_count,
        perimeter_meters: (total_perimeter_mm / 1000.0).round(2),
        stiffener_meters: (total_stiffener_mm / 1000.0).round(2),
        total_tape_meters: total_tape_m.round(2),
        rolls_needed: rolls_needed,
        tape_name: tape['name'],
        roll_m: tape['roll_m'],
        tape_cost: (rolls_needed * tape['price'].to_f).round(2),
        primer_cans: primer_cans
      }
    end

    # --------------------------------------------------------------------------
    # M4: Fixadores desenhados pelo plugin (cantoneira em L com medidas das
    # Configurações), distribuídos por distância:
    #   cantoneira -> bandeja ACM presa na estrutura (nos retornos da bandeja)
    #   ancoragem  -> estrutura presa na parede (atrás dos tubos verticais)
    #   espera     -> igual à ancoragem, com afastamento (standoff_mm) até a parede
    # Cada fixador grava seu consumo (parafusos, buchas, rebites) para o relatório.
    # --------------------------------------------------------------------------
    TYPES = %w[cantoneira ancoragem espera].freeze
    WALL_TYPES = %w[ancoragem espera].freeze
    ARRAY_KIND = 'fastener_array'.freeze

    # Posições ao longo de um comprimento: margem nas pontas e passo <= espaçamento.
    # Mesma regra de fastenerPositions() em ui/acm360-report.js.
    def positions(len, spacing, margin)
      return [] if len <= 0
      usable = len - 2.0 * margin
      return [len / 2.0] if usable <= 0
      n = [(usable / spacing).floor + 1, 2].max
      step = usable / (n - 1)
      (0...n).map { |i| margin + i * step }
    end

    # Distribui um tipo de fixador nos grupos escolhidos (bandejas para cantoneira,
    # estruturas para ancoragem/espera). Refazer substitui os fixadores anteriores.
    def distribute(groups, type)
      type = type.to_s
      raise ArgumentError, "tipo de fixador desconhecido: #{type}" unless TYPES.include?(type)
      model = Sketchup.active_model
      count = 0
      model.start_operation("CS ACM360: Distribuir #{Settings.fastener_spec(type)['name']}", true)
      begin
        groups.each do |g|
          types = applied_types(g)
          types -= WALL_TYPES if WALL_TYPES.include?(type) # ancoragem e espera não convivem no mesmo grupo
          types |= [type]
          g.set_attribute(Catalog::ATTR_DICT, 'fasteners', JSON.generate(types))
          count += draw_fasteners(g)
        end
        model.commit_operation
      rescue StandardError
        model.abort_operation
        raise
      end
      count
    end

    def remove(groups)
      model = Sketchup.active_model
      model.start_operation('CS ACM360: Remover Fixadores', true)
      groups.each do |g|
        clear_arrays(g)
        g.delete_attribute(Catalog::ATTR_DICT, 'fasteners')
      end
      model.commit_operation
    end

    # Redesenha os fixadores já aplicados (chamado ao regerar estrutura ou bandeja,
    # dentro da operação do kernel). Retorna quantos foram desenhados.
    def reapply(group)
      return 0 if applied_types(group).empty?
      draw_fasteners(group)
    end

    # Redesenha todos os fixadores do modelo (após mudar medidas ou espaçamentos nas Configurações)
    def redraw_all(model = Sketchup.active_model)
      groups = []
      UnfoldDxfEngine.each_cs_group(model.entities) { |g, _| groups << g unless applied_types(g).empty? }
      return 0 if groups.empty?
      model.start_operation('CS ACM360: Atualizar Fixadores', true)
      n = groups.sum { |g| draw_fasteners(g) }
      model.commit_operation
      n
    end

    # Grupos que recebem o tipo: seleção (inclusive dentro de grupos selecionados);
    # sem nada adequado selecionado, pergunta se aplica no modelo inteiro.
    def target_groups(type, ask: true)
      kind = type.to_s == 'cantoneira' ? 'acm_tray' : 'parametric_frame'
      model = Sketchup.active_model
      found = []
      UnfoldDxfEngine.each_cs_group(model.selection.to_a) { |g, k| found << g if k == kind }
      return found unless found.empty?
      UnfoldDxfEngine.each_cs_group(model.entities) { |g, k| found << g if k == kind }
      return [] if found.empty?
      what = kind == 'acm_tray' ? 'bandeja(s) ACM' : 'estrutura(s)'
      return found unless ask
      UI.messagebox("Nada adequado selecionado. Aplicar em todas as #{found.size} #{what} do modelo?", MB_YESNO) == IDYES ? found : []
    end

    # Ação de menu/painel: distribui e devolve a mensagem para o usuário
    def distribute_from_selection(type)
      groups = target_groups(type)
      if groups.empty?
        what = type.to_s == 'cantoneira' ? 'Bandeja ACM com dobra' : 'Estrutura'
        return "Nenhuma #{what} para receber fixadores."
      end
      n = distribute(groups, type)
      "#{n} × #{Settings.fastener_spec(type)['name']} em #{groups.size} grupo(s)"
    end

    def remove_from_selection
      model = Sketchup.active_model
      groups = []
      UnfoldDxfEngine.each_cs_group(model.selection.to_a) { |g, _| groups << g unless applied_types(g).empty? }
      return 'Selecione bandejas ou estruturas com fixadores para remover.' if groups.empty?
      remove(groups)
      "Fixadores removidos de #{groups.size} grupo(s)"
    end

    def applied_types(group)
      list = JSON.parse(group.get_attribute(Catalog::ATTR_DICT, 'fasteners').to_s) rescue []
      Array(list) & TYPES
    end

    def draw_fasteners(group)
      clear_arrays(group)
      kind = group.get_attribute(Catalog::ATTR_DICT, 'kind')
      applied_types(group).sum do |type|
        if type == 'cantoneira' && kind == 'acm_tray'
          place_on_tray(group)
        elsif WALL_TYPES.include?(type) && kind == 'parametric_frame'
          place_on_frame(group, type)
        else
          0
        end
      end
    end

    def clear_arrays(group)
      arrays = group.entities.grep(Sketchup::Group).select { |g| g.get_attribute(Catalog::ATTR_DICT, 'kind') == ARRAY_KIND }
      group.entities.erase_entities(arrays) unless arrays.empty?
    end

    def new_array(group, type)
      arr = group.entities.add_group
      arr.name = "Fixadores · #{Settings.fastener_spec(type)['name']}"
      arr.set_attribute(Catalog::ATTR_DICT, 'kind', ARRAY_KIND)
      arr.set_attribute(Catalog::ATTR_DICT, 'fastener_type', type)
      FrameKernel.ensure_layer(Sketchup.active_model, 'CS_ACM360_Fixadores', arr)
      arr
    end

    # Cantoneira no fundo de cada retorno: uma aba no retorno (rebite), a outra no
    # plano de trás da bandeja, voltada para dentro, onde fica o tubo (parafuso).
    def place_on_tray(tray)
      cfg = tray_cfg(tray)
      spec = Settings.fastener_spec('cantoneira')
      spacing = Settings.get('fastener_spacing_mm').to_f
      margin  = Settings.get('fastener_offset_mm').to_f
      ox, oy, oz = cfg['origin_x_mm'].to_f, cfg['origin_y_mm'].to_f, cfg['origin_z_mm'].to_f
      w, h, th = cfg['width_mm'].to_f, cfg['height_mm'].to_f, cfg['thickness_mm'].to_f
      edges = cfg['edges'] || {}
      arr = new_array(tray, 'cantoneira')
      back = Geom::Vector3d.new(0, -1, 0)
      n = 0
      %w[inf sup esq dir].each do |side|
        e = edges[side] || {}
        next unless %w[dobra dobra_aba].include?(e['type'].to_s) && e['return_mm'].to_f > spec['thickness_mm']
        y_back = oy + e['return_mm'].to_f
        # A aba no retorno não passa da face da bandeja (retorno curto)
        defn = angle_definition('cantoneira', [spec['leg_a_mm'], e['return_mm'].to_f - th].min)
        along, inward, corner = case side
                                when 'inf' then [w, [0, 0, 1],  ->(p) { [ox + p, y_back, oz + th] }]
                                when 'sup' then [w, [0, 0, -1], ->(p) { [ox + p, y_back, oz + h - th] }]
                                when 'esq' then [h, [1, 0, 0],  ->(p) { [ox + th, y_back, oz + p] }]
                                else            [h, [-1, 0, 0], ->(p) { [ox + w - th, y_back, oz + p] }]
                                end
        positions(along, spacing, margin).each do |p|
          place(arr, defn, spec, corner.call(p), back, Geom::Vector3d.new(inward))
          n += 1
        end
      end
      n
    end

    # Ancoragem/espera nos tubos verticais da estrutura (laterais e montantes): uma aba
    # na lateral do tubo (autobrocante), a outra na parede atrás (bucha + parafuso).
    def place_on_frame(frame, type)
      tubes = JSON.parse(frame.get_attribute(Catalog::ATTR_DICT, 'tubes_json').to_s) rescue []
      spec = Settings.fastener_spec(type)
      standoff = type == 'espera' ? Settings.get('standoff_mm').to_f : 0.0
      spacing = Settings.get('anchor_spacing_mm').to_f
      margin  = Settings.get('anchor_margin_mm').to_f
      arr = new_array(frame, type)
      back = Geom::Vector3d.new(0, -1, 0)
      vertical = tubes.select { |t| t['axis'] == 'z' }
      list = vertical.empty? ? tubes : vertical # estrutura sem verticais: usa os horizontais
      n = 0
      list.each do |t|
        x, y, z = t['x_mm'].to_f, t['y_mm'].to_f, t['z_mm'].to_f
        wall_y = y + t['d_mm'].to_f + standoff
        # A aba no tubo não passa da profundidade dele (senão bate na bandeja)
        defn = angle_definition(type, [spec['leg_a_mm'], t['d_mm'].to_f].min + standoff)
        if t['axis'] == 'z'
          left = t['slot'].to_s == 'c1' # lateral esquerda: aba para fora, do lado esquerdo
          x_face = left ? x : x + t['w_mm'].to_f
          out = Geom::Vector3d.new(left ? -1 : 1, 0, 0)
          positions(t['length_mm'].to_f, spacing, margin).each do |p|
            place(arr, defn, spec, [x_face, wall_y, z + p], back, out)
            n += 1
          end
        else
          bottom = t['slot'].to_s == 'inf'
          z_face = bottom ? z : z + t['h_mm'].to_f
          out = Geom::Vector3d.new(0, 0, bottom ? -1 : 1)
          positions(t['length_mm'].to_f, spacing, margin).each do |p|
            place(arr, defn, spec, [x + p, wall_y, z_face], back, out)
            n += 1
          end
        end
      end
      n
    end

    # Cantoneira em L: aba A ao longo de +Y local, aba B ao longo de +Z local, comprimento em X.
    # Uma definição por medida, reaproveitada no modelo.
    def angle_definition(type, leg_a_mm)
      spec = Settings.fastener_spec(type)
      a, b, t, l = leg_a_mm.to_f, spec['leg_b_mm'], spec['thickness_mm'], spec['length_mm']
      name = format('CS %s L%gx%gx%g c%g', spec['name'].split(' ').first, a.round(1), b.round(1), t, l)
      model = Sketchup.active_model
      defn = model.definitions[name]
      return defn if defn && defn.entities.grep(Sketchup::Face).any?
      defn = model.definitions.add(name)
      pts = [[0, 0, 0], [0, a, 0], [0, a, t], [0, t, t], [0, t, b], [0, 0, b]].map { |q| Geom::Point3d.new(q.map(&:mm)) }
      face = defn.entities.add_face(pts)
      face.reverse! if face.normal.x < 0
      face.pushpull(l.mm)
      defn.set_attribute(Catalog::ATTR_DICT, 'kind', 'fastener_def')
      defn
    end

    # corner: ponto da quina do L (mm, coordenadas do grupo); leg_a/leg_b: direções das abas
    def place(arr, defn, spec, corner_mm, leg_a, leg_b)
      xaxis = leg_a * leg_b
      origin = Geom::Point3d.new(corner_mm.map { |v| v.to_f.mm }).offset(xaxis, -spec['length_mm'].mm / 2.0)
      inst = arr.entities.add_instance(defn, Geom::Transformation.axes(origin, xaxis, leg_a, leg_b))
      inst.set_attribute(Catalog::ATTR_DICT, 'kind', 'fastener')
      inst.set_attribute(Catalog::ATTR_DICT, 'fastener_type', spec['id'])
      inst.set_attribute(Catalog::ATTR_DICT, 'fastener_label', defn.name.sub(/\ACS /, ''))
      inst.set_attribute(Catalog::ATTR_DICT, 'consumption_json', JSON.generate(spec['items']))
      inst
    end

    # Parâmetros gravados pela AcmTrayKernel no atributo tray_json
    def tray_cfg(tray_group)
      cfg = JSON.parse(tray_group.get_attribute(Catalog::ATTR_DICT, 'tray_json').to_s) rescue {}
      cfg.is_a?(Hash) ? cfg : {}
    end

    def find_all_acm_trays(model)
      trays = []
      UnfoldDxfEngine.each_cs_group(model.entities) { |g, kind| trays << g if kind == 'acm_tray' }
      trays
    end

  end
end
