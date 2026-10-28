# encoding: UTF-8
# ==============================================================================
# CS_ACM360_BETA::LiveTool  (Módulo M1 — Construtor ao Vivo)
# Ferramentas na tela do SketchUp:
#   RectTool      — gradil, bandeja ou fachada por 2 cantos (ou medida digitada);
#                   clicando numa face, a peça é desenhada encostada nela.
#                   No gradil, as setas mudam a quantidade de travessas.
#   TubeTool      — tubo avulso por 2 pontos, em sequência; corta nas interferências (M5).
#   StretchTool   — alças nas bordas de estrutura/bandeja para esticar.
#   FastenerTool  — cantoneira/ancoragem/espera no ponto clicado (Tab troca o tipo).
# A geometria fica nas funções do módulo (pontos 3D -> peças), usadas pelas
# ferramentas e pelos testes; as classes só tratam mouse, teclado e desenho.
# ==============================================================================

require 'json'

module CS_ACM360_BETA
  module LiveTool
    extend self

    MIN_MM = 100.0
    PREVIEW = Sketchup::Color.new(37, 99, 235)
    HANDLE  = Sketchup::Color.new(220, 38, 38)

    REMEMBERED = %w[frame tray facade tube].freeze
    # Só o que define a peça; medidas e posições vêm do desenho
    TRANSIENT = %w[update_selected width_mm height_mm length_mm total_w_mm total_h_mm
                   origin_x_mm origin_y_mm origin_z_mm custom_v_xs_mm custom_h_zs_mm seam_overrides cutouts].freeze

    # Sem params, usa os últimos do mesmo tipo (painel lateral, painel completo ou desenho anterior)
    def start(tool, params = {})
      model = Sketchup.active_model
      tool = tool.to_s
      params = params.is_a?(Hash) ? params : {}
      if REMEMBERED.include?(tool)
        remember(tool, params) unless params.empty?
        params = params_for(tool)
      end
      t = case tool
          when 'frame', 'tray', 'facade' then RectTool.new(tool, params)
          when 'tube'     then TubeTool.new(params)
          when 'stretch'  then StretchTool.new
          when 'fastener' then FastenerTool.new(params['type'] || 'cantoneira')
          end
      model.select_tool(t) if t
      t
    end

    def all_params
      @last ||= begin
        JSON.parse(Sketchup.read_default('CS_ACM360_BETA', 'live_params', '{}').to_s)
      rescue StandardError
        {}
      end
      @last = {} unless @last.is_a?(Hash)
      @last
    end

    def params_for(mode)
      (all_params[mode.to_s] || {}).dup
    end

    def remember(mode, params)
      return unless REMEMBERED.include?(mode.to_s) && params.is_a?(Hash)
      old = params_for(mode)
      # chapa trocada sem espessura/fator: valem os da chapa nova
      old = old.reject { |k, _| %w[thickness_mm bend_factor_mm].include?(k) } if params.key?('acm_preset') && !params.key?('thickness_mm')
      all_params[mode.to_s] = old.merge(params.reject { |k, _| TRANSIENT.include?(k) })
      Sketchup.write_default('CS_ACM360_BETA', 'live_params', JSON.generate(all_params))
    end

    # --------------------------------------------------------------------------
    # Plano de desenho: u = direita, w = profundidade (para dentro da parede), v = cima.
    # normal: normal da face clicada voltada para quem olha; nil = plano frontal (X-Z).
    # --------------------------------------------------------------------------
    def drawing_axes(normal = nil)
      return [X_AXIS.clone, Y_AXIS.clone, Z_AXIS.clone] unless normal
      n = normal.clone.normalize
      up = n.z.abs > 0.99 ? Y_AXIS.clone : Z_AXIS.clone # face no chão/teto: "cima" é +Y
      v = LiveTool.reject(up, n).normalize
      w = n.reverse
      u = w * v
      [u.normalize, w, v]
    end

    # Retângulo entre dois pontos no plano: [origem (canto esquerdo de baixo), largura mm, altura mm]
    def rect_from(p1, p2, axes)
      u, _w, v = axes
      d = p2 - p1
      dx, dz = d.dot(u), d.dot(v)
      origin = p1.offset(u, [dx, 0].min).offset(v, [dz, 0].min)
      [origin, dx.abs.to_mm.round(1), dz.abs.to_mm.round(1)]
    end

    # "3000;1500", "3000x1500" ou "3000 1500" (vírgula decimal aceita); fachada: "3600;1800;3;2"
    def parse_dims(text)
      text.to_s.strip.split(/\s*[;xX×]\s*|\s+/).map { |t| Float(t.tr(',', '.')) rescue nil }.compact
    end

    # Cria a peça com o tamanho do retângulo e a leva para o lugar. on_face: encosta o
    # fundo da peça na face (estrutura/bandeja na parede); senão a frente fica no plano.
    def create_rect(mode, params, origin, w_mm, h_mm, axes, on_face: false)
      model = Sketchup.active_model
      ents = model.active_entities
      before = ents.to_a
      p = params.is_a?(Hash) ? params.dup : {}
      p.delete('update_selected')
      case mode
      when 'frame'
        FrameKernel.create_or_update_frame(p.merge('width_mm' => w_mm, 'height_mm' => h_mm))
      when 'tray'
        AcmTrayKernel.create_or_update_tray(p.merge('width_mm' => w_mm, 'height_mm' => h_mm,
                                                    'origin_x_mm' => 0, 'origin_y_mm' => 0, 'origin_z_mm' => 0))
      when 'facade'
        AcmTrayKernel.create_facade_grid(facade_params(p, w_mm, h_mm))
      end
      created = ents.to_a - before
      return [] if created.empty?
      bb = Geom::BoundingBox.new
      created.each { |e| bb.add(e.bounds) }
      shift = Geom::Vector3d.new(-bb.min.x, on_face ? -bb.max.y : -bb.min.y, -bb.min.z)
      u, w, v = axes
      tr = Geom::Transformation.axes(origin, u, w, v) * Geom::Transformation.translation(shift)
      model.start_operation('CS ACM360: Posicionar', true, false, true)
      ents.transform_entities(tr, created)
      model.commit_operation
      model.selection.clear
      model.selection.add(created)
      created
    end

    # Colunas e linhas da fachada: as digitadas ou as que cabem na chapa
    def facade_params(p, w_mm, h_mm)
      p = p.dup
      ret = (p['return_mm'] || Settings.get('default_return_mm')).to_f
      p['cols'] = [(w_mm / 1500.0).ceil, 1].max if p['cols'].to_i < 1
      p['rows'] = [(h_mm / [Settings.get('acm_sheet_h_mm') - 2 * ret - 20, 300].max).ceil, 1].max if p['rows'].to_i < 1
      p.merge('total_w_mm' => w_mm, 'total_h_mm' => h_mm)
    end

    # --------------------------------------------------------------------------
    # Fantasma: a peça em caixas semitransparentes, calculada como na criação
    # (sem geometria). Caixa = [[x0, y0, z0, x1, y1, z1] mm na peça, cor hex].
    # --------------------------------------------------------------------------
    GHOST_ALPHA = 90
    BOX_FACES = [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [3, 2, 6, 7], [1, 2, 6, 5], [0, 3, 7, 4]].freeze
    BOX_EDGES = [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]].freeze

    def ghost_boxes(mode, params, w_mm, h_mm)
      p = (params || {}).merge('width_mm' => w_mm, 'height_mm' => h_mm)
      case mode
      when 'frame' then frame_boxes(p)
      when 'tray' then tray_boxes(AcmTrayKernel.normalize_tray_params(p.merge('origin_x_mm' => 0, 'origin_y_mm' => 0, 'origin_z_mm' => 0)))
      when 'facade' then facade_boxes(facade_params(p, w_mm, h_mm))
      else []
      end
    end

    def frame_boxes(params)
      cfg = FrameKernel.normalize_params(params)
      FrameKernel.compute_frame_tubes(cfg)[:tubes].map do |t|
        x, y, z = t[:x_mm].to_f, t[:y_mm].to_f, t[:z_mm].to_f
        [[x, y, z, x + t[:w_mm].to_f, y + t[:d_mm].to_f, z + t[:h_mm].to_f], FrameKernel.resolve_tube_color(t, cfg['color_mode'])]
      end
    end

    # Face e retornos com dobra (abas e recortes não entram no fantasma)
    def tray_boxes(cfg)
      ox, oy, oz = cfg.values_at('origin_x_mm', 'origin_y_mm', 'origin_z_mm').map(&:to_f)
      w, h, th = cfg.values_at('width_mm', 'height_mm', 'thickness_mm').map(&:to_f)
      color = cfg['color_hex']
      boxes = [[[ox, oy, oz, ox + w, oy + th, oz + h], color]]
      (cfg['edges'] || {}).each do |side, e|
        next unless %w[dobra dobra_aba].include?(e['type']) && e['return_mm'].to_f > 0
        y0, y1 = oy + th, oy + th + e['return_mm'].to_f
        box = case side
              when 'inf' then [ox, y0, oz, ox + w, y1, oz + th]
              when 'sup' then [ox, y0, oz + h - th, ox + w, y1, oz + h]
              when 'esq' then [ox, y0, oz, ox + th, y1, oz + h]
              when 'dir' then [ox + w - th, y0, oz, ox + w, y1, oz + h]
              end
        boxes << [box, color] if box
      end
      boxes
    end

    # Mesma malha de AcmTrayKernel.create_facade_grid, com a estrutura atrás
    def facade_boxes(gp)
      cols = gp['cols'].to_i.clamp(1, 20)
      rows = gp['rows'].to_i.clamp(1, 10)
      joint = (gp['joint_mm'] || Settings.get('default_joint_mm')).to_f.clamp(0.0, 50.0)
      ret = (gp['return_mm'] || Settings.get('default_return_mm')).to_f.clamp(15.0, 300.0)
      tw = (gp['total_w_mm'].to_f - (cols - 1) * joint) / cols
      th = (gp['total_h_mm'].to_f - (rows - 1) * joint) / rows
      edge = { 'type' => 'dobra', 'return_mm' => ret }
      trays = (0...rows).flat_map do |r|
        (0...cols).map do |c|
          tray_boxes(AcmTrayKernel.normalize_tray_params(
            'width_mm' => tw, 'height_mm' => th, 'origin_x_mm' => c * (tw + joint), 'origin_y_mm' => 0.0,
            'origin_z_mm' => r * (th + joint), 'color_hex' => gp['color_hex'] || '#27272A',
            'edges' => { 'sup' => edge, 'inf' => edge, 'esq' => edge, 'dir' => edge }
          ))
        end
      end
      boxes = trays.flatten(1)
      return boxes if gp['generate_frame'] == false
      env = trays.map do |tb|
        lo = (0..2).map { |i| tb.map { |b, _| b[i] }.min }
        hi = (3..5).map { |i| tb.map { |b, _| b[i] }.max }
        { min_x: lo[0], max_x: hi[0], min_y: lo[1], max_y: hi[1], min_z: lo[2], max_z: hi[2] }
      end
      fp, min_x, min_z = AcmTrayKernel.frame_params_from_boxes(env, gp)
      boxes + frame_boxes(fp).map { |b, c| [[b[0] + min_x, b[1], b[2] + min_z, b[3] + min_x, b[4], b[5] + min_z], c] }
    end

    # Mesmo posicionamento de create_rect, a partir das caixas
    def ghost_transform(boxes, origin, axes, on_face)
      return nil if boxes.empty?
      lo = (0..2).map { |i| boxes.map { |b, _| b[i] }.min }
      hi_y = boxes.map { |b, _| b[4] }.max
      shift = Geom::Vector3d.new(-lo[0].mm, (on_face ? -hi_y : -lo[1]).mm, -lo[2].mm)
      u, w, v = axes
      Geom::Transformation.axes(origin, u, w, v) * Geom::Transformation.translation(shift)
    end

    def ghost_extents(bb, ghost)
      return bb unless ghost && ghost[1]
      boxes, tr = ghost
      boxes.each do |b, _|
        bb.add(Geom::Point3d.new(b[0].mm, b[1].mm, b[2].mm).transform(tr))
        bb.add(Geom::Point3d.new(b[3].mm, b[4].mm, b[5].mm).transform(tr))
      end
      bb
    end

    def hex_color(hex, alpha)
      h = hex.to_s.delete('#')
      c = h =~ /\A\h{6}\z/ ? Sketchup::Color.new(h[0, 2].hex, h[2, 2].hex, h[4, 2].hex) : Sketchup::Color.new(PREVIEW.red, PREVIEW.green, PREVIEW.blue)
      c.alpha = alpha
      c
    end

    def draw_ghost(view, boxes, tr)
      return unless boxes && tr
      fills = Hash.new { |hh, k| hh[k] = [] }
      lines = []
      boxes.each do |b, color|
        x0, y0, z0, x1, y1, z1 = b
        c = [[x0, y0, z0], [x1, y0, z0], [x1, y1, z0], [x0, y1, z0], [x0, y0, z1], [x1, y0, z1], [x1, y1, z1], [x0, y1, z1]]
            .map { |q| Geom::Point3d.new(q[0].mm, q[1].mm, q[2].mm).transform(tr) }
        BOX_FACES.each { |f| fills[color].concat(f.map { |i| c[i] }) }
        BOX_EDGES.each { |a, z| lines << c[a] << c[z] }
      end
      fills.each do |color, pts|
        view.drawing_color = hex_color(color, GHOST_ALPHA)
        view.draw(GL_QUADS, pts)
      end
      view.line_width = 1
      view.line_stipple = ''
      view.drawing_color = Sketchup::Color.new(15, 23, 42, 150)
      view.draw(GL_LINES, lines)
    end

    # Tubo avulso com o eixo de p1 a p2 (centro da seção na linha). Corta nas interferências.
    def create_tube(params, p1, p2, cut: true)
      len = p1.distance(p2).to_mm
      return [nil, 'Tubo curto demais.'] if len < 10
      model = Sketchup.active_model
      grp = FrameKernel.create_single_tube((params || {}).merge('length_mm' => len.round(1)))
      return [nil, 'Não foi possível criar o tubo.'] unless grp
      t = InterferenceKernel.tubes(grp).first
      x = (p2 - p1).normalize
      if x.z.abs > 0.999 # vertical: profundidade continua para trás (+Y)
        y = Y_AXIS.clone
        z = (x * y).normalize
      else
        z = LiveTool.reject(Z_AXIS, x).normalize
        y = (z * x).normalize
      end
      origin = p1.offset(y, -(t['d_mm'].to_f / 2.0).mm).offset(z, -(t['h_mm'].to_f / 2.0).mm)
      model.start_operation('CS ACM360: Posicionar Tubo', true, false, true)
      grp.transformation = Geom::Transformation.axes(origin, x, y, z)
      model.commit_operation
      msg = cut ? InterferenceKernel.cut_selection(model, only: [grp]) : nil
      [grp, msg]
    end

    # --------------------------------------------------------------------------
    # Alças: borda da peça (esq, dir, inf, sup) em coordenadas locais (mm)
    # --------------------------------------------------------------------------
    def stretch_box(grp)
      case grp.get_attribute(Catalog::ATTR_DICT, 'kind')
      when 'parametric_frame'
        cfg = JSON.parse(grp.get_attribute(Catalog::ATTR_DICT, 'params_json').to_s) rescue {}
        { x: 0.0, z: 0.0, w: cfg['width_mm'].to_f, h: cfg['height_mm'].to_f, y: 0.0 }
      when 'acm_tray'
        c = HardwareFasteners.tray_cfg(grp)
        { x: c['origin_x_mm'].to_f, z: c['origin_z_mm'].to_f, w: c['width_mm'].to_f, h: c['height_mm'].to_f, y: c['origin_y_mm'].to_f }
      end
    end

    def handle_points(grp, tr = grp.transformation)
      b = stretch_box(grp)
      return {} unless b && b[:w] > 0
      mid_x, mid_z = b[:x] + b[:w] / 2.0, b[:z] + b[:h] / 2.0
      {
        'esq' => [b[:x], b[:y], mid_z], 'dir' => [b[:x] + b[:w], b[:y], mid_z],
        'inf' => [mid_x, b[:y], b[:z]], 'sup' => [mid_x, b[:y], b[:z] + b[:h]]
      }.transform_values { |p| Geom::Point3d.new(p.map(&:mm)).transform(tr) }
    end

    # Parâmetros da peça com o novo tamanho; esq/inf mantêm a borda oposta parada.
    # shift_mm: quanto a estrutura anda nos próprios eixos (a bandeja anda pela origem).
    def resize_plan(grp, side, new_mm)
      kind = grp.get_attribute(Catalog::ATTR_DICT, 'kind')
      horiz = %w[esq dir].include?(side)
      key = horiz ? 'width_mm' : 'height_mm'
      if kind == 'parametric_frame'
        params = JSON.parse(grp.get_attribute(Catalog::ATTR_DICT, 'params_json').to_s)
        delta = new_mm - params[key].to_f
        params[key] = new_mm
        if side == 'esq' && params['custom_v_xs_mm'].is_a?(Array)
          params['custom_v_xs_mm'] = params['custom_v_xs_mm'].map { |x| x.to_f + delta }
        elsif side == 'inf' && params['custom_h_zs_mm'].is_a?(Array)
          params['custom_h_zs_mm'] = params['custom_h_zs_mm'].map { |z| z.to_f + delta }
        end
        shift = %w[esq inf].include?(side) ? -delta : 0.0
        { kind: kind, params: params, shift_mm: horiz ? [shift, 0.0, 0.0] : [0.0, 0.0, shift] }
      elsif kind == 'acm_tray'
        cfg = HardwareFasteners.tray_cfg(grp)
        delta = new_mm - cfg[key].to_f
        cfg[key] = new_mm
        if side == 'esq'
          cfg['origin_x_mm'] = cfg['origin_x_mm'].to_f - delta
          cfg['cutouts'] = Array(cfg['cutouts']).map { |c| c.merge('pts' => c['pts'].map { |u, v| [u + delta, v] }) }
        elsif side == 'inf'
          cfg['origin_z_mm'] = cfg['origin_z_mm'].to_f - delta
          cfg['cutouts'] = Array(cfg['cutouts']).map { |c| c.merge('pts' => c['pts'].map { |u, v| [u, v + delta] }) }
        end
        { kind: kind, params: cfg, shift_mm: [0.0, 0.0, 0.0] }
      end
    end

    def resize(grp, side, new_mm)
      new_mm = new_mm.to_f
      return 'Medida mínima: 100 mm.' if new_mm < MIN_MM
      plan = resize_plan(grp, side, new_mm)
      return 'Selecione uma estrutura ou bandeja do plugin.' unless plan
      if plan[:kind] == 'parametric_frame'
        FrameKernel.create_or_update_frame(plan[:params], grp)
        unless plan[:shift_mm].all?(&:zero?)
          model = Sketchup.active_model
          model.start_operation('CS ACM360: Esticar', true, false, true)
          grp.transformation = grp.transformation * Geom::Transformation.translation(Geom::Vector3d.new(plan[:shift_mm].map(&:mm)))
          model.commit_operation
        end
      else
        AcmTrayKernel.create_or_update_tray(plan[:params], grp)
      end
      "#{%w[esq dir].include?(side) ? 'Largura' : 'Altura'}: #{new_mm.round(1)} mm"
    end

    # Fantasma da peça esticada: [caixas, transformação até o modelo]
    def resize_ghost(grp, side, new_mm, tr = grp.transformation)
      plan = resize_plan(grp, side, [new_mm.to_f, MIN_MM].max)
      return nil unless plan
      boxes = plan[:kind] == 'parametric_frame' ? frame_boxes(plan[:params]) : tray_boxes(plan[:params])
      [boxes, tr * Geom::Transformation.translation(Geom::Vector3d.new(plan[:shift_mm].map(&:mm)))]
    end

    # --------------------------------------------------------------------------
    # Fixador no clique: ponto local (mm) -> { ref, pos_mm, label } ou nil
    # --------------------------------------------------------------------------
    def fastener_target(grp, type, p)
      kind = grp.get_attribute(Catalog::ATTR_DICT, 'kind')
      spec = Settings.fastener_spec(type)
      x, _y, z = p
      if type == 'cantoneira'
        return nil unless kind == 'acm_tray'
        cfg = HardwareFasteners.tray_cfg(grp)
        ox, oz, w, h = cfg['origin_x_mm'].to_f, cfg['origin_z_mm'].to_f, cfg['width_mm'].to_f, cfg['height_mm'].to_f
        sides = { 'inf' => [z - oz, x - ox], 'sup' => [oz + h - z, x - ox], 'esq' => [x - ox, z - oz], 'dir' => [ox + w - x, z - oz] }
        side, (_, pos) = sides.select { |s, _| HardwareFasteners.tray_slot(cfg, spec, s) }.min_by { |_, (dist, _)| dist.abs }
        return nil unless side
        along = %w[inf sup].include?(side) ? w : h
        { ref: side, pos_mm: pos.clamp(0.0, along).round(1), label: "borda #{side}" }
      else
        return nil unless kind == 'parametric_frame'
        tubes = HardwareFasteners.frame_tubes(grp)
        t = tubes.min_by { |tb| box_distance(tb, p) }
        return nil unless t
        pos = t['axis'] == 'z' ? z - t['z_mm'].to_f : x - t['x_mm'].to_f
        { ref: t['id'].to_s, pos_mm: pos.clamp(0.0, t['length_mm'].to_f).round(1), label: "#{t['id']} #{t['name']}" }
      end
    end

    def box_distance(t, p)
      lo = [t['x_mm'].to_f, t['y_mm'].to_f, t['z_mm'].to_f]
      hi = [lo[0] + t['w_mm'].to_f, lo[1] + t['d_mm'].to_f, lo[2] + t['h_mm'].to_f]
      Math.sqrt((0..2).sum { |i| d = [lo[i] - p[i], 0, p[i] - hi[i]].max; d * d })
    end

    def add_fastener(grp, type, local_mm)
      tgt = fastener_target(grp, type, local_mm)
      return nil unless tgt
      model = Sketchup.active_model
      model.start_operation("CS ACM360: #{Settings.fastener_spec(type)['name']} no clique", true)
      HardwareFasteners.add_manual(grp, type, tgt[:ref], tgt[:pos_mm])
      model.commit_operation
      tgt
    end

    # Peça do plugin sob o cursor (do tipo pedido) e sua transformação até o modelo
    def picked_group(ip, kinds)
      path = ip.respond_to?(:instance_path) ? ip.instance_path.to_a : []
      tr = Geom::Transformation.new
      found = nil
      path.each do |e|
        break unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        tr *= e.transformation
        found = [e, tr.clone] if kinds.include?(e.get_attribute(Catalog::ATTR_DICT, 'kind'))
      end
      found
    end

    MAX_REACH_MM = 200_000.0

    # Ponto do mouse no plano; nil com o raio quase paralelo ao plano ou longe demais
    # (olhando a parede de lado o ponto iria ao infinito e travava a prévia)
    def ray_on_plane(ray, origin, normal)
      return nil if ray[1].clone.normalize.dot(normal.clone.normalize).abs < 0.02
      pt = Geom.intersect_line_plane(ray, [origin, normal])
      pt if pt && pt.distance(origin).to_mm < MAX_REACH_MM
    end

    # Parte de a perpendicular a n (n unitário)
    def reject(a, n)
      d = a.dot(n)
      Geom::Vector3d.new(a.x - n.x * d, a.y - n.y * d, a.z - n.z * d)
    end

    def scale(v, s)
      Geom::Vector3d.new(v.x * s, v.y * s, v.z * s)
    end

    def mm_point(pt)
      [pt.x.to_mm, pt.y.to_mm, pt.z.to_mm]
    end

    def fmt(v)
      v.to_f.round(1).to_s.sub(/\.0\z/, '').tr('.', ',')
    end

    # ==========================================================================
    # Ferramentas
    # ==========================================================================
    class RectTool
      NAMES = { 'frame' => 'Gradil', 'tray' => 'Bandeja ACM', 'facade' => 'Fachada (bandejas + estrutura)' }.freeze

      def initialize(mode, params)
        @mode = mode
        @params = params || {}
      end

      # Travessas do gradil: [verticais, horizontais] (padrões do FrameKernel)
      def trav
        [(@params['trav_v_count'] || 2).to_i, (@params['trav_h_count'] || 1).to_i]
      end

      def set_trav(v, h)
        @params = @params.merge('trav_v_count' => v.clamp(0, 40), 'trav_h_count' => h.clamp(0, 30))
        @params.delete('custom_v_xs_mm') # quantidade nova redistribui por igual
        @params.delete('custom_h_zs_mm')
      end

      def trav_text
        v, h = trav
        "#{v} vertical(is) × #{h} horizontal(is)"
      end

      def activate
        @ip = Sketchup::InputPoint.new
        reset
      end

      def reset
        @state = 0
        @p1 = @p2 = @axes = @ghost = @ghost_key = nil
        @on_face = false
        Sketchup.vcb_label = { 'facade' => 'Larg;Alt;Col;Lin (mm)', 'frame' => 'Larg;Alt;Vert;Horiz' }[@mode] || 'Largura;Altura (mm)'
        status("clique no primeiro canto (numa face, desenha encostado nela).")
        Sketchup.active_model.active_view.invalidate
      end

      def status(msg)
        msg += " Setas: travessas (#{trav_text})." if @mode == 'frame'
        Sketchup.status_text = "#{NAMES[@mode]}: #{msg}"
      end

      def deactivate(view)
        view.invalidate
      end

      def onCancel(_reason, _view)
        reset
      end

      # ↑/↓ travessas horizontais, →/← verticais
      def onKeyDown(key, _repeat, _flags, view)
        return false unless @mode == 'frame'
        v, h = trav
        case key
        when VK_UP    then h += 1
        when VK_DOWN  then h -= 1
        when VK_RIGHT then v += 1
        when VK_LEFT  then v -= 1
        else return false
        end
        set_trav(v, h)
        update_ghost
        status(@state.zero? ? 'clique no primeiro canto.' : 'clique no canto oposto ou digite a medida.')
        view.invalidate
        true
      end

      def enableVCB?
        true
      end

      def onMouseMove(_flags, x, y, view)
        if @state.zero?
          @ip.pick(view, x, y)
          view.tooltip = @ip.tooltip
        else
          @p2 = plane_point(view, x, y) || @p2
          if @p2
            _o, w, h = LiveTool.rect_from(@p1, @p2, @axes)
            Sketchup.vcb_value = "#{LiveTool.fmt(w)};#{LiveTool.fmt(h)}"
            update_ghost
          end
        end
        view.invalidate
      end

      def onLButtonDown(_flags, x, y, view)
        if @state.zero?
          @ip.pick(view, x, y)
          @p1 = @ip.position
          normal = nil
          if @ip.face
            normal = @ip.face.normal.transform(@ip.transformation).normalize
            normal.reverse! if normal.dot(view.camera.eye - @p1) < 0
          end
          @on_face = !normal.nil?
          @axes = LiveTool.drawing_axes(normal)
          @state = 1
          status('clique no canto oposto ou digite a medida.')
        else
          p2 = plane_point(view, x, y)
          finish(p2) if p2
        end
        view.invalidate
      end

      def onUserText(text, view)
        return unless @state == 1
        dims = LiveTool.parse_dims(text)
        return UI.beep if dims.size < 2
        u, _w, v = @axes
        su = @p2 ? ((@p2 - @p1).dot(u) < 0 ? -1 : 1) : 1
        sv = @p2 ? ((@p2 - @p1).dot(v) < 0 ? -1 : 1) : 1
        @params = @params.merge('cols' => dims[2].to_i, 'rows' => dims[3].to_i) if @mode == 'facade' && dims.size >= 4
        set_trav(dims[2].to_i, (dims[3] || trav[1]).to_i) if @mode == 'frame' && dims.size >= 3
        finish(@p1.offset(u, su * dims[0].mm).offset(v, sv * dims[1].mm))
        view.invalidate
      end

      def finish(p2)
        origin, w, h = LiveTool.rect_from(@p1, p2, @axes)
        if w < MIN_MM || h < MIN_MM
          UI.beep
          Sketchup.status_text = 'Medida mínima: 100 × 100 mm.'
          return
        end
        LiveTool.create_rect(@mode, @params, origin, w, h, @axes, on_face: @on_face)
        LiveTool.remember(@mode, @params) # travessas mudadas nas setas valem para o próximo
        StudioDialog.push_state_to_ui if defined?(StudioDialog)
        reset
      end

      def plane_point(view, x, y)
        LiveTool.ray_on_plane(view.pickray(x, y), @p1, @axes[1])
      end

      def corners
        return nil unless @state == 1 && @p2
        u, _w, v = @axes
        d = @p2 - @p1
        a = @p1
        b = @p1.offset(u, d.dot(u))
        c = b.offset(v, d.dot(v))
        e = @p1.offset(v, d.dot(v))
        [a, b, c, e]
      end

      # Peça semitransparente no lugar onde vai nascer (só recalcula se mudou)
      def update_ghost
        return @ghost = nil unless @p2
        origin, w, h = LiveTool.rect_from(@p1, @p2, @axes)
        return @ghost = nil if w < MIN_MM || h < MIN_MM
        key = [w, h, @params.hash, origin.to_a]
        return if @ghost_key == key
        @ghost_key = key
        boxes = LiveTool.ghost_boxes(@mode, @params, w, h)
        @ghost = [boxes, LiveTool.ghost_transform(boxes, origin, @axes, @on_face)]
      rescue StandardError
        @ghost = nil
      end

      def draw(view)
        @ip.draw(view) if @state.zero? && @ip.display?
        pts = corners
        return unless pts
        LiveTool.draw_ghost(view, *@ghost) if @ghost
        view.drawing_color = PREVIEW
        view.line_width = 2
        view.line_stipple = @ghost ? '-' : ''
        view.draw(GL_LINE_LOOP, pts)
        view.line_stipple = ''
        draw_trav(view, pts) if @mode == 'frame' && !@ghost
        _o, w, h = LiveTool.rect_from(@p1, @p2, @axes)
        mid = Geom.linear_combination(0.5, pts[0], 0.5, pts[2])
        label = "#{LiveTool.fmt(w)} × #{LiveTool.fmt(h)} mm"
        label += "\n#{trav_text}" if @mode == 'frame'
        view.draw_text(view.screen_coords(mid), label, size: 14, color: PREVIEW)
      end

      # Prévia das travessas distribuídas por igual
      def draw_trav(view, pts)
        a, b, c, e = pts
        nv, nh = trav
        lines = (1..nv).flat_map { |i| t = i / (nv + 1.0); [Geom.linear_combination(1 - t, a, t, b), Geom.linear_combination(1 - t, e, t, c)] }
        lines += (1..nh).flat_map { |j| t = j / (nh + 1.0); [Geom.linear_combination(1 - t, a, t, e), Geom.linear_combination(1 - t, b, t, c)] }
        return if lines.empty?
        view.line_width = 1
        view.line_stipple = '-'
        view.draw(GL_LINES, lines)
        view.line_stipple = ''
      end

      def getExtents
        bb = Geom::BoundingBox.new
        (corners || []).each { |p| bb.add(p) }
        LiveTool.ghost_extents(bb, @ghost)
      end
    end

    class TubeTool
      def initialize(params)
        @params = params || {}
      end

      def activate
        @ip = Sketchup::InputPoint.new
        @ip1 = Sketchup::InputPoint.new
        reset
      end

      def reset
        @state = 0
        @p2 = nil
        Sketchup.vcb_label = 'Comprimento (mm)'
        Sketchup.status_text = 'Tubo avulso: clique no início (Esc termina a sequência).'
      end

      def deactivate(view)
        view.invalidate
      end

      def onCancel(_reason, view)
        reset
        view.invalidate
      end

      def enableVCB?
        true
      end

      def onMouseMove(_flags, x, y, view)
        if @state.zero?
          @ip.pick(view, x, y)
        else
          @ip.pick(view, x, y, @ip1)
          @p2 = @ip.position
          Sketchup.vcb_value = LiveTool.fmt(@ip1.position.distance(@p2).to_mm)
        end
        view.tooltip = @ip.tooltip
        view.invalidate
      end

      def onLButtonDown(_flags, x, y, view)
        if @state.zero?
          @ip1.pick(view, x, y)
          @state = 1
          Sketchup.status_text = 'Tubo avulso: clique no fim ou digite o comprimento.'
        else
          @ip.pick(view, x, y, @ip1)
          finish(@ip.position)
        end
        view.invalidate
      end

      def onUserText(text, view)
        return unless @state == 1 && @p2
        len = LiveTool.parse_dims(text).first
        return UI.beep unless len && len > 0
        dir = @p2 - @ip1.position
        return UI.beep if dir.length < 1e-6
        finish(@ip1.position.offset(dir, len.mm))
        view.invalidate
      end

      def finish(p2)
        _grp, msg = LiveTool.create_tube(@params, @ip1.position, p2)
        Sketchup.status_text = msg.to_s.lines.first.to_s.strip
        StudioDialog.push_state_to_ui if defined?(StudioDialog)
        @ip1 = Sketchup::InputPoint.new(p2) # próximo tubo começa onde este terminou
      end

      def draw(view)
        @ip.draw(view) if @ip.display?
        return unless @state == 1 && @p2
        view.drawing_color = PREVIEW
        view.line_width = 3
        view.draw(GL_LINES, [@ip1.position, @p2])
        mid = Geom.linear_combination(0.5, @ip1.position, 0.5, @p2)
        view.draw_text(view.screen_coords(mid), "#{LiveTool.fmt(@ip1.position.distance(@p2).to_mm)} mm", size: 14, color: PREVIEW)
      end

      def getExtents
        bb = Geom::BoundingBox.new
        bb.add(@ip1.position) if @state == 1
        bb.add(@p2) if @p2
        bb
      end
    end

    class StretchTool
      KINDS = %w[parametric_frame acm_tray].freeze

      def activate
        @ip = Sketchup::InputPoint.new
        sel = Sketchup.active_model.selection.find { |e| e.is_a?(Sketchup::Group) && KINDS.include?(e.get_attribute(Catalog::ATTR_DICT, 'kind')) }
        @target = sel ? [sel, sel.transformation] : nil
        reset
      end

      def reset
        @drag = nil
        @hover = nil
        @new_mm = nil
        @ghost = nil
        Sketchup.vcb_label = 'Nova medida (mm)'
        Sketchup.status_text = @target ? 'Esticar: arraste uma alça vermelha (ou clique, mova e clique; ou digite a medida).' :
                                         'Esticar: passe o mouse sobre uma estrutura ou bandeja do plugin.'
      end

      def deactivate(view)
        view.invalidate
      end

      def onCancel(_reason, view)
        reset
        view.invalidate
      end

      def enableVCB?
        true
      end

      def handles
        @target ? LiveTool.handle_points(@target[0], @target[1]) : {}
      end

      def onMouseMove(_flags, x, y, view)
        if @drag
          mm = drag_size(view, x, y)
          if mm && mm != @new_mm
            @new_mm = mm
            Sketchup.vcb_value = LiveTool.fmt(mm)
            @ghost = (LiveTool.resize_ghost(@target[0], @drag[:side], mm, @target[1]) rescue nil)
          end
        else
          @ip.pick(view, x, y)
          if (g = LiveTool.picked_group(@ip, KINDS))
            @target = g
          end
          @hover = handles.find { |_, p| view.screen_coords(p).distance([x, y, 0]) < 12 }&.first
          Sketchup.status_text = 'Esticar: arraste uma alça vermelha (ou clique, mova e clique; ou digite a medida).' if @target
        end
        view.invalidate
      end

      def onLButtonDown(_flags, x, y, view)
        if @drag
          apply(@new_mm) if @new_mm
        elsif @hover
          box = LiveTool.stretch_box(@target[0])
          @drag = { side: @hover, base: %w[esq dir].include?(@hover) ? box[:w] : box[:h], start: handles[@hover], press: [x, y] }
          Sketchup.status_text = 'Esticar: solte, ou mova e clique, ou digite a nova medida.'
        end
        view.invalidate
      end

      # Arrastando com o botão apertado: soltar longe da alça confirma
      def onLButtonUp(_flags, x, y, view)
        return unless @drag && @drag[:press] && @new_mm
        apply(@new_mm) if Math.hypot(x - @drag[:press][0], y - @drag[:press][1]) > 6
        view.invalidate
      end

      def onUserText(text, view)
        side = @drag ? @drag[:side] : @hover
        return UI.beep unless side && @target
        val = LiveTool.parse_dims(text).first
        return UI.beep unless val
        @drag ||= { side: side }
        apply(val)
        view.invalidate
      end

      def drag_size(view, x, y)
        grp, tr = @target
        horiz = %w[esq dir].include?(@drag[:side])
        axis = (horiz ? tr.xaxis : tr.zaxis).normalize
        pt = LiveTool.ray_on_plane(view.pickray(x, y), @drag[:start], tr.yaxis)
        return nil unless pt && grp.valid?
        delta = (pt - @drag[:start]).dot(axis).to_mm
        delta = -delta if %w[esq inf].include?(@drag[:side])
        [@drag[:base] + delta, MIN_MM].max.round(1)
      end

      def apply(mm)
        msg = LiveTool.resize(@target[0], @drag[:side], mm)
        Sketchup.status_text = msg
        @target = [@target[0], @target[0].transformation] if @target[0].valid?
        StudioDialog.push_state_to_ui if defined?(StudioDialog)
        @drag = nil
        @new_mm = nil
        @ghost = nil
      end

      def draw(view)
        LiveTool.draw_ghost(view, *@ghost) if @ghost
        hs = handles
        return if hs.empty?
        hs.each do |side, p|
          color = side == @hover || (@drag && @drag[:side] == side) ? PREVIEW : HANDLE
          view.draw_points([p], 14, 2, color)
        end
        return unless @drag && @new_mm
        view.draw_text(view.screen_coords(hs[@drag[:side]]).offset([16, -16, 0]), "#{LiveTool.fmt(@new_mm)} mm", size: 14, color: PREVIEW)
      end

      def getExtents
        bb = Geom::BoundingBox.new
        handles.each_value { |p| bb.add(p) }
        LiveTool.ghost_extents(bb, @ghost)
      end
    end

    class FastenerTool
      def initialize(type)
        @type = HardwareFasteners::TYPES.include?(type.to_s) ? type.to_s : 'cantoneira'
      end

      def activate
        @ip = Sketchup::InputPoint.new
        @hit = nil
        status
      end

      def status
        what = @type == 'cantoneira' ? 'no retorno de uma bandeja' : 'num tubo de estrutura'
        Sketchup.status_text = "#{Settings.fastener_spec(@type)['name']}: clique #{what}. Tab troca o tipo."
      end

      def deactivate(view)
        view.invalidate
      end

      def kinds
        @type == 'cantoneira' ? ['acm_tray'] : ['parametric_frame']
      end

      def onKeyDown(key, _repeat, _flags, view)
        return false unless key == 9 # Tab
        types = HardwareFasteners::TYPES
        @type = types[(types.index(@type) + 1) % types.size]
        status
        view.invalidate
        true
      end

      def onMouseMove(_flags, x, y, view)
        @ip.pick(view, x, y)
        @hit = nil
        if (g = LiveTool.picked_group(@ip, kinds))
          grp, tr = g
          local = LiveTool.mm_point(@ip.position.transform(tr.inverse))
          tgt = LiveTool.fastener_target(grp, @type, local)
          @hit = [grp, tr, local, tgt] if tgt
        end
        view.tooltip = @hit ? "#{Settings.fastener_spec(@type)['name']} · #{@hit[3][:label]} a #{LiveTool.fmt(@hit[3][:pos_mm])} mm" : ''
        view.invalidate
      end

      def onLButtonDown(_flags, _x, _y, view)
        return UI.beep unless @hit
        grp, _tr, local, = @hit
        tgt = LiveTool.add_fastener(grp, @type, local)
        Sketchup.status_text = "#{Settings.fastener_spec(@type)['name']} colocada: #{tgt[:label]} a #{LiveTool.fmt(tgt[:pos_mm])} mm" if tgt
        StudioDialog.push_state_to_ui if defined?(StudioDialog)
        view.invalidate
      end

      def draw(view)
        @ip.draw(view) if @ip.display?
        return unless @hit
        view.draw_points([@ip.position], 12, 3, PREVIEW)
      end
    end
  end
end
