# encoding: UTF-8
# ==============================================================================
# CS_ACM360_BETA::TrayCutouts  (Módulo M6 — Recortes nas bandejas ACM)
#   Automático: tubos, fixadores de estruturas e objetos marcados como "furo" que
#               atravessam a face da bandeja viram recorte retangular com folga.
#   Contorno:   faces ou linhas fechadas desenhadas/importadas sobre a face (ex.:
#               letra caixa) viram recorte com o mesmo contorno.
# Os recortes ficam no tray_json (vista de frente, mm a partir do canto inferior
# esquerdo da face) e entram no 3D, na planificação e no DXF.
# ==============================================================================

require 'json'

module CS_ACM360_BETA
  module TrayCutouts
    extend self

    HOLE_KIND = 'furo'.freeze
    CONTOUR_REACH_MM = 200.0 # distância máxima do contorno até a face da bandeja

    # --------------------------------------------------------------------------
    # Ações de menu/painel (devolvem a mensagem para o usuário)
    # --------------------------------------------------------------------------
    def auto_selection(model = Sketchup.active_model)
      trays = trays_of(model, selected_only: true)
      if trays.empty?
        all = trays_of(model)
        return 'Nenhuma Bandeja ACM no modelo.' if all.empty?
        return 'Recortes cancelados.' unless UI.messagebox("Nenhuma bandeja selecionada. Procurar recortes em todas as #{all.size} bandeja(s) do modelo?", MB_YESNO) == IDYES
        trays = all
      end
      solids = InterferenceKernel.collect_solids(model) + hole_solids(model) + fastener_solids(model)
      clearance = Settings.get('cutout_clearance_mm').to_f
      count = 0
      changed = 0
      warnings = []
      apply(model, 'CS ACM360: Recortes Automáticos') do
        trays.each do |g, tr|
          cfg = HardwareFasteners.tray_cfg(g)
          rects = merge_rects(solids.filter_map { |s| section_rect(cfg, tr.inverse, s, clearance) })
          old = Array(cfg['cutouts'])
          kept = old.reject { |c| c['source'] == 'auto' }
          next if rects.empty? && kept.size == old.size
          count += rects.size
          changed += 1
          warnings += rebuild(model, g, cfg.merge('cutouts' => kept + rects.map { |r| { 'source' => 'auto', 'pts' => rect_pts(r) } }))
        end
      end
      msg = "#{count} recorte(s) automático(s) em #{changed} de #{trays.size} bandeja(s) (folga #{fmt(clearance)} mm por lado)."
      msg += "\nNada atravessa a face das bandejas." if count.zero?
      with_warnings(msg, warnings)
    end

    def contour_selection(model = Sketchup.active_model)
      loops = collect_loops(model.selection.to_a, Geom::Transformation.new)
      return 'Selecione o contorno do recorte: faces ou linhas fechadas desenhadas sobre a face da bandeja.' if loops.empty?
      trays = trays_of(model, selected_only: true)
      trays = trays_of(model) if trays.empty?
      return 'Nenhuma Bandeja ACM no modelo.' if trays.empty?

      added = Hash.new { |h, k| h[k] = [] }
      outside = 0
      loops.each do |lp|
        hit = trays.find do |g, tr|
          pts = loop_on_face(HardwareFasteners.tray_cfg(g), tr.inverse, lp)
          added[g] << pts if pts
          pts
        end
        outside += 1 unless hit
      end
      warnings = []
      unless added.empty?
        apply(model, 'CS ACM360: Recorte pelo Contorno') do
          added.each do |g, list|
            cfg = HardwareFasteners.tray_cfg(g)
            new_cuts = list.map { |pts| { 'source' => 'contorno', 'pts' => pts } }
            warnings += rebuild(model, g, cfg.merge('cutouts' => Array(cfg['cutouts']) + new_cuts))
          end
        end
      end
      n = added.values.sum(&:size)
      msg = "#{n} contorno(s) recortado(s) em #{added.size} bandeja(s)."
      msg += "\n#{outside} contorno(s) fora da face de qualquer bandeja (precisa caber inteiro na face, a até #{CONTOUR_REACH_MM.round} mm dela)." if outside > 0
      with_warnings(msg, warnings)
    end

    def clear_selection(model = Sketchup.active_model)
      trays = trays_of(model, selected_only: true).select { |g, _| Array(HardwareFasteners.tray_cfg(g)['cutouts']).any? }
      return 'Selecione bandejas com recortes para limpar.' if trays.empty?
      apply(model, 'CS ACM360: Limpar Recortes') do
        trays.each { |g, _| rebuild(model, g, HardwareFasteners.tray_cfg(g).merge('cutouts' => [])) }
      end
      "Recortes removidos de #{trays.size} bandeja(s)."
    end

    # Marca grupos/componentes comuns como "furo": viram recorte automático onde atravessarem a bandeja
    def mark_holes(model = Sketchup.active_model)
      list = model.selection.to_a.select do |e|
        (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e.get_attribute(Catalog::ATTR_DICT, 'kind').nil?
      end
      return 'Selecione grupos ou componentes (não peças do plugin) para marcar como furo.' if list.empty?
      model.start_operation('CS ACM360: Marcar como Furo', true)
      list.each { |e| e.set_attribute(Catalog::ATTR_DICT, 'kind', HOLE_KIND) }
      model.commit_operation
      "#{list.size} objeto(s) marcado(s) como furo. Use Recortes Automáticos para abrir os recortes."
    end

    # --------------------------------------------------------------------------
    # Bandejas e sólidos do modelo
    # --------------------------------------------------------------------------
    def trays_of(model, selected_only: false)
      out = []
      InterferenceKernel.each_tube_group(model.entities, selection: model.selection.to_a, kinds: ['acm_tray']) do |g, tr, _k, sel|
        out << [g, tr] if sel || !selected_only
      end
      out
    end

    def hole_solids(model)
      out = []
      walk_all(model.entities, Geom::Transformation.new) do |e, tr|
        out << bounds_solid(e.definition.bounds, tr) if e.get_attribute(Catalog::ATTR_DICT, 'kind') == HOLE_KIND
      end
      out
    end

    # Fixadores das estruturas (os da própria bandeja ficam atrás da face)
    def fastener_solids(model)
      out = []
      InterferenceKernel.each_tube_group(model.entities) do |g, tr, _k, _s|
        g.entities.grep(Sketchup::Group).each do |arr|
          next unless arr.get_attribute(Catalog::ATTR_DICT, 'kind') == HardwareFasteners::ARRAY_KIND
          arr.entities.grep(Sketchup::ComponentInstance).each do |inst|
            out << bounds_solid(inst.definition.bounds, tr * arr.transformation * inst.transformation)
          end
        end
      end
      out
    end

    def walk_all(entities, tr, &blk)
      entities.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        t = tr * e.transformation
        blk.call(e, t)
        walk_all(e.definition.entities, t, &blk) if e.get_attribute(Catalog::ATTR_DICT, 'kind').nil?
      end
    end

    # Caixa local -> sólido de 8 cantos (mesma ordem de InterferenceKernel.tube_corners)
    def bounds_solid(bb, tr)
      mn, mx = bb.min, bb.max
      yz = [[mn.y, mn.z], [mx.y, mn.z], [mx.y, mx.z], [mn.y, mx.z]]
      solid = {
        a: yz.map { |y, z| [mn.x.to_mm, y.to_mm, z.to_mm] },
        b: yz.map { |y, z| [mx.x.to_mm, y.to_mm, z.to_mm] }
      }
      InterferenceKernel.transform_solid(solid, tr)
    end

    # --------------------------------------------------------------------------
    # Geometria na face da bandeja
    # --------------------------------------------------------------------------
    # Retângulo [u0, v0, u1, v1] (mm na face) onde o sólido atravessa a chapa, com folga
    def section_rect(cfg, inv, solid, clearance)
      ox, oy, oz = cfg['origin_x_mm'].to_f, cfg['origin_y_mm'].to_f, cfg['origin_z_mm'].to_f
      w, h, th = cfg['width_mm'].to_f, cfg['height_mm'].to_f, cfg['thickness_mm'].to_f
      y_lo, y_hi = oy + 0.01, oy + th - 0.01
      local = InterferenceKernel.transform_solid(solid, inv)
      pts = local[:a] + local[:b]
      cand = pts.select { |p| p[1] > y_lo && p[1] < y_hi }
      a, b = local[:a], local[:b]
      edges = (0..3).flat_map { |i| [[a[i], a[(i + 1) % 4]], [b[i], b[(i + 1) % 4]], [a[i], b[i]]] }
      edges.each do |p, q|
        [y_lo, y_hi].each do |yy|
          next unless (p[1] - yy) * (q[1] - yy) < 0
          t = (yy - p[1]) / (q[1] - p[1])
          cand << [p[0] + t * (q[0] - p[0]), yy, p[2] + t * (q[2] - p[2])]
        end
      end
      return nil if cand.empty?
      us = cand.map { |p| p[0] - ox }
      vs = cand.map { |p| p[2] - oz }
      u0, u1 = [us.min - clearance, 1.0].max, [us.max + clearance, w - 1.0].min
      v0, v1 = [vs.min - clearance, 1.0].max, [vs.max + clearance, h - 1.0].min
      return nil if u1 - u0 < 1.0 || v1 - v0 < 1.0
      [u0, v0, u1, v1].map { |v| v.round(2) }
    end

    # Recortes que se sobrepõem viram um só
    def merge_rects(rects)
      list = rects.dup
      loop do
        merged = false
        list.each_with_index do |r, i|
          j = list.each_index.find { |k| k > i && overlap?(r, list[k]) }
          next unless j
          s = list.delete_at(j)
          list[i] = [[r[0], s[0]].min, [r[1], s[1]].min, [r[2], s[2]].max, [r[3], s[3]].max]
          merged = true
          break
        end
        break unless merged
      end
      list
    end

    def overlap?(r, s)
      r[0] < s[2] && s[0] < r[2] && r[1] < s[3] && s[1] < r[3]
    end

    def rect_pts(r)
      [[r[0], r[1]], [r[2], r[1]], [r[2], r[3]], [r[0], r[3]]]
    end

    # Contorno (mm do modelo) -> pontos na face, ou nil se não couber inteiro nela
    def loop_on_face(cfg, inv, loop_mm)
      ox, oy, oz = cfg['origin_x_mm'].to_f, cfg['origin_y_mm'].to_f, cfg['origin_z_mm'].to_f
      w, h, th = cfg['width_mm'].to_f, cfg['height_mm'].to_f, cfg['thickness_mm'].to_f
      pts = []
      loop_mm.each do |p|
        x, y, z = InterferenceKernel.world(inv, p)
        return nil if y < oy - CONTOUR_REACH_MM || y > oy + th + CONTOUR_REACH_MM
        u, v = (x - ox).round(2), (z - oz).round(2)
        return nil unless u > 0 && u < w && v > 0 && v < h
        pts << [u, v] if pts.empty? || Math.hypot(u - pts.last[0], v - pts.last[1]) > 0.05
      end
      pts.pop if pts.size > 1 && Math.hypot(pts[0][0] - pts[-1][0], pts[0][1] - pts[-1][1]) <= 0.05
      pts.size >= 3 ? pts : nil
    end

    # Laços fechados da seleção (mm do modelo): contornos das faces e linhas soltas
    # encadeadas; entra em grupos/componentes comuns (ex.: DWG importado).
    def collect_loops(list, tr)
      loops = []
      faces = list.grep(Sketchup::Face)
      faces.each do |f|
        f.loops.each { |lp| loops << lp.vertices.map { |v| to_mm(v.position.transform(tr)) } }
      end
      used = faces.flat_map(&:edges)
      loose = list.grep(Sketchup::Edge) - used
      loops.concat(chain_edges(loose).map { |vs| vs.map { |v| to_mm(v.position.transform(tr)) } })
      list.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        next unless e.get_attribute(Catalog::ATTR_DICT, 'kind').nil?
        loops.concat(collect_loops(e.definition.entities.to_a, tr * e.transformation))
      end
      loops
    end

    # Encadeia arestas soltas em laços fechados; trechos abertos ou com ramificação ficam de fora
    def chain_edges(edges)
      adj = Hash.new { |hh, k| hh[k] = [] }
      edges.each { |e| adj[e.start] << e; adj[e.end] << e }
      seen = {}
      loops = []
      edges.each do |e0|
        next if seen[e0]
        seen[e0] = true
        chain = [e0.start]
        prev = e0
        v = e0.end
        ok = true
        until v == e0.start
          chain << v
          nxt = adj[v].reject { |x| x == prev }
          if nxt.size != 1 || seen[nxt[0]]
            ok = false
            break
          end
          prev = nxt[0]
          seen[prev] = true
          v = prev.other_vertex(v)
        end
        loops << chain if ok && chain.size >= 3
      end
      loops
    end

    # --------------------------------------------------------------------------
    def apply(model, name)
      model.start_operation(name, true)
      begin
        yield
        model.commit_operation
      rescue StandardError
        model.abort_operation
        raise
      end
    end

    # Regera a bandeja com os recortes novos; devolve os avisos da planificação
    def rebuild(model, grp, cfg)
      norm = AcmTrayKernel.normalize_tray_params(cfg)
      flat = AcmTrayKernel.build_tray(model, grp, norm)
      Array(flat['warnings']).map { |w| "#{norm['code']}: #{w}" }
    end

    def with_warnings(msg, warnings)
      warnings.empty? ? msg : "#{msg}\n\n⚠ Perto da dobra (mínimo #{fmt(Settings.get('cutout_fold_warn_mm'))} mm):\n#{warnings.uniq.join("\n")}"
    end

    def to_mm(pt)
      [pt.x.to_mm, pt.y.to_mm, pt.z.to_mm]
    end

    def fmt(v)
      format('%g', v.to_f.round(1))
    end
  end
end
