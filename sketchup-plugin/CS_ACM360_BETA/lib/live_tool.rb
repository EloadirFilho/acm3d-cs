# encoding: UTF-8
# ==============================================================================
# CS_ACM360_BETA::LiveTool  (Módulo M1 — Construtor ao Vivo)
# Ferramentas na tela do SketchUp:
#   RectTool      — gradil, bandeja ou fachada por 2 cantos (ou medida digitada);
#                   clicando numa face, a peça é desenhada encostada nela.
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

    def start(tool, params = {})
      model = Sketchup.active_model
      t = case tool.to_s
          when 'frame', 'tray', 'facade' then RectTool.new(tool.to_s, params)
          when 'tube'     then TubeTool.new(params)
          when 'stretch'  then StretchTool.new
          when 'fastener' then FastenerTool.new(params['type'] || 'cantoneira')
          end
      model.select_tool(t) if t
      t
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
        ret = (p['return_mm'] || Settings.get('default_return_mm')).to_f
        p['cols'] ||= [(w_mm / 1500.0).ceil, 1].max
        p['rows'] ||= [(h_mm / [Settings.get('acm_sheet_h_mm') - 2 * ret - 20, 300].max).ceil, 1].max
        AcmTrayKernel.create_facade_grid(p.merge('total_w_mm' => w_mm, 'total_h_mm' => h_mm))
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

    # Novo tamanho na direção da alça; esq/inf mantêm a borda oposta parada
    def resize(grp, side, new_mm)
      new_mm = new_mm.to_f
      return 'Medida mínima: 100 mm.' if new_mm < MIN_MM
      model = Sketchup.active_model
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
        FrameKernel.create_or_update_frame(params, grp)
        if %w[esq inf].include?(side) && delta.abs > 1e-6
          axis = (horiz ? grp.transformation.xaxis : grp.transformation.zaxis).normalize
          model.start_operation('CS ACM360: Esticar', true, false, true)
          grp.transform!(Geom::Transformation.translation(LiveTool.scale(axis, -delta.mm)))
          model.commit_operation
        end
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
        AcmTrayKernel.create_or_update_tray(cfg, grp)
      else
        return 'Selecione uma estrutura ou bandeja do plugin.'
      end
      "#{horiz ? 'Largura' : 'Altura'}: #{new_mm.round(1)} mm"
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

      def activate
        @ip = Sketchup::InputPoint.new
        reset
      end

      def reset
        @state = 0
        @p1 = @p2 = @axes = nil
        @on_face = false
        Sketchup.vcb_label = @mode == 'facade' ? 'Larg;Alt;Col;Lin (mm)' : 'Largura;Altura (mm)'
        Sketchup.status_text = "#{NAMES[@mode]}: clique no primeiro canto (numa face, desenha encostado nela)."
        Sketchup.active_model.active_view.invalidate
      end

      def deactivate(view)
        view.invalidate
      end

      def onCancel(_reason, _view)
        reset
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
          Sketchup.status_text = "#{NAMES[@mode]}: clique no canto oposto ou digite a medida."
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
        StudioDialog.push_state_to_ui if defined?(StudioDialog)
        reset
      end

      def plane_point(view, x, y)
        ray = view.pickray(x, y)
        Geom.intersect_line_plane(ray, [@p1, @axes[1]])
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

      def draw(view)
        @ip.draw(view) if @state.zero? && @ip.display?
        pts = corners
        return unless pts
        view.drawing_color = PREVIEW
        view.line_width = 2
        view.draw(GL_LINE_LOOP, pts)
        _o, w, h = LiveTool.rect_from(@p1, @p2, @axes)
        mid = Geom.linear_combination(0.5, pts[0], 0.5, pts[2])
        view.draw_text(view.screen_coords(mid), "#{LiveTool.fmt(w)} × #{LiveTool.fmt(h)} mm", size: 14, color: PREVIEW)
      end

      def getExtents
        bb = Geom::BoundingBox.new
        (corners || []).each { |p| bb.add(p) }
        bb
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
        Sketchup.vcb_label = 'Nova medida (mm)'
        Sketchup.status_text = @target ? 'Esticar: clique numa alça vermelha, mova e clique de novo (ou digite a medida).' :
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
          @new_mm = drag_size(view, x, y)
          Sketchup.vcb_value = LiveTool.fmt(@new_mm) if @new_mm
        else
          @ip.pick(view, x, y)
          if (g = LiveTool.picked_group(@ip, KINDS))
            @target = g
          end
          @hover = handles.find { |_, p| view.screen_coords(p).distance([x, y, 0]) < 12 }&.first
          Sketchup.status_text = 'Esticar: clique numa alça vermelha, mova e clique de novo (ou digite a medida).' if @target
        end
        view.invalidate
      end

      def onLButtonDown(_flags, x, y, view)
        if @drag
          apply(@new_mm) if @new_mm
        elsif @hover
          box = LiveTool.stretch_box(@target[0])
          @drag = { side: @hover, base: %w[esq dir].include?(@hover) ? box[:w] : box[:h], start: handles[@hover] }
          Sketchup.status_text = 'Esticar: mova e clique, ou digite a nova medida.'
        end
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
        ray = view.pickray(x, y)
        pt = Geom.intersect_line_plane(ray, [@drag[:start], tr.yaxis])
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
      end

      def draw(view)
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
        bb
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
