# encoding: UTF-8
# ==============================================================================
# CS_ACM360_BETA::InterferenceKernel  (Módulo M5 — Corte nas interferências)
# Apara (ou estende até encostar) as pontas dos tubos avulsos selecionados contra
# a face do tubo vizinho que elas atravessam. Só corte num plano: corte composto
# e ângulo acima de 75° ficam como estão, com aviso.
#
# Ponta de tubo (eixo X local): { 'axis' => 'z'|'y', 'tan' => t, 'long' => 'min'|'max' }
# 'axis' é a direção em que o corte inclina, 'long' o lado da ponta longa e 'tan'
# o quanto a ponta encurta por mm nessa direção.
# ==============================================================================

require 'json'

module CS_ACM360_BETA
  module InterferenceKernel
    extend self

    MAX_ANGLE = 75.0
    TUBE_KINDS = %w[single_tube parametric_frame].freeze

    # --------------------------------------------------------------------------
    # Ação de menu/painel
    # --------------------------------------------------------------------------
    # only: tubos a cortar (ex.: o tubo recém-desenhado no Construtor ao Vivo); sem ele, a seleção
    def cut_selection(model = Sketchup.active_model, only: nil)
      targets = []
      each_tube_group(model.entities, selection: only || model.selection.to_a) do |g, tr, kind, selected|
        targets << [g, tr] if selected && kind == 'single_tube'
      end
      return 'Selecione um ou mais tubos avulsos para cortar nas interferências.' if targets.empty?

      max_ext = Settings.get('interference_max_extend_mm').to_f
      stats = Hash.new(0)
      model.start_operation('CS ACM360: Cortar nas Interferências', true)
      begin
        targets.each do |g, tr|
          obstacles = collect_solids(model, exclude: g)
          trim_tube(model, g, tr, obstacles, max_ext, stats)
        end
        model.commit_operation
      rescue StandardError
        model.abort_operation
        raise
      end
      summary(targets.size, stats)
    end

    def summary(n_tubes, s)
      done = s[:trimmed] + s[:extended]
      msg = "#{done} ponta(s) ajustada(s) em #{n_tubes} tubo(s): #{s[:trimmed]} aparada(s), #{s[:extended]} estendida(s)."
      skipped = []
      skipped << "#{s[:compound]} pediria corte composto" if s[:compound] > 0
      skipped << "#{s[:steep]} com ângulo acima de #{MAX_ANGLE.round}°" if s[:steep] > 0
      skipped << "#{s[:short]} deixaria o tubo curto demais" if s[:short] > 0
      skipped << "#{s[:scaled]} tubo(s) escalado(s) à mão" if s[:scaled] > 0
      msg += "\nPuladas: #{skipped.join(', ')}." unless skipped.empty?
      msg += "\nNenhuma ponta encosta em outro tubo (até #{Settings.get('interference_max_extend_mm').round} mm)." if done.zero? && skipped.empty?
      msg
    end

    # --------------------------------------------------------------------------
    # Percorre o modelo acumulando a transformação; entra só em grupos comuns do usuário
    # --------------------------------------------------------------------------
    def each_tube_group(entities, tr = Geom::Transformation.new, selection: [], inside: false, kinds: TUBE_KINDS, &blk)
      entities.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        t = tr * e.transformation
        sel = inside || selection.include?(e)
        kind = e.get_attribute(Catalog::ATTR_DICT, 'kind')
        if kinds.include?(kind)
          blk.call(e, t, kind, sel)
        elsif kind.nil?
          each_tube_group(e.definition.entities, t, selection: selection, inside: sel, kinds: kinds, &blk)
        end
      end
    end

    # Todos os tubos do modelo como sólidos de 8 cantos em mm do modelo
    def collect_solids(model, exclude: nil)
      solids = []
      each_tube_group(model.entities) do |g, tr, _kind, _sel|
        next if g == exclude
        tubes(g).each { |t| solids << transform_solid(tube_corners(t), tr) }
      end
      solids
    end

    def tubes(group)
      list = JSON.parse(group.get_attribute(Catalog::ATTR_DICT, 'tubes_json').to_s) rescue []
      Array(list).select { |t| t.is_a?(Hash) }
    end

    # --------------------------------------------------------------------------
    # Geometria do tubo (mm, coordenadas do grupo)
    # --------------------------------------------------------------------------
    # Pontas no formato novo ou convertidas do corte antigo (trapézio no plano X-Z)
    def ends_of(t)
      return t['ends'] if t['ends'].is_a?(Hash)
      return {} unless t['axis'] == 'x'
      long = t['slot'].to_s == 'sup' ? 'max' : 'min'
      ends = {}
      { 'a' => 'cut_a_deg', 'b' => 'cut_b_deg' }.each do |k, key|
        deg = t[key].to_f.clamp(0.0, MAX_ANGLE)
        ends[k] = { 'axis' => 'z', 'tan' => Math.tan(deg * Math::PI / 180.0), 'long' => long } if deg > 0
      end
      ends
    end

    # Quanto a ponta encurta no canto (y, z) em relação à ponta longa
    def end_offset(e, y, z, t)
      return 0.0 unless e.is_a?(Hash) && e['tan'].to_f > 0
      if e['axis'] == 'y'
        c, span = y - t['y_mm'].to_f, t['d_mm'].to_f
      else
        c, span = z - t['z_mm'].to_f, t['h_mm'].to_f
      end
      (e['long'] == 'max' ? span - c : c) * e['tan'].to_f
    end

    # Cantos das duas pontas, na ordem (y0,z0) (y1,z0) (y1,z1) (y0,z1)
    def tube_corners(t)
      x0, y0, z0 = t['x_mm'].to_f, t['y_mm'].to_f, t['z_mm'].to_f
      w, d, h = t['w_mm'].to_f, t['d_mm'].to_f, t['h_mm'].to_f
      ends = t['axis'] == 'x' ? ends_of(t) : {}
      yz = [[y0, z0], [y0 + d, z0], [y0 + d, z0 + h], [y0, z0 + h]]
      {
        a: yz.map { |y, z| [x0 + end_offset(ends['a'], y, z, t), y, z] },
        b: yz.map { |y, z| [x0 + w - end_offset(ends['b'], y, z, t), y, z] }
      }
    end

    def transform_solid(solid, tr)
      solid.transform_values do |pts|
        pts.map do |p|
          q = Geom::Point3d.new(p.map { |v| v.to_f.mm }).transform(tr)
          [q.x.to_mm, q.y.to_mm, q.z.to_mm]
        end
      end
    end

    # Faces do sólido como planos [ponto, normal para fora]
    def solid_planes(s)
      a, b = s[:a], s[:b]
      quads = [a, b.reverse, [a[0], b[0], b[1], a[1]], [a[1], b[1], b[2], a[2]], [a[2], b[2], b[3], a[3]], [a[3], b[3], b[0], a[0]]]
      center = (a + b).transpose.map { |c| c.sum / 8.0 }
      quads.filter_map do |q|
        n = normal_of(q)
        next unless n
        n = n.map(&:-@) if dot(n, sub(center, q[0])) > 0
        [q[0], n]
      end
    end

    # Normal pela maior área (robusta para faces com um canto repetido)
    def normal_of(q)
      n = [0.0, 0.0, 0.0]
      q.each_with_index do |p, i|
        r = q[(i + 1) % q.size]
        n[0] += (p[1] - r[1]) * (p[2] + r[2])
        n[1] += (p[2] - r[2]) * (p[0] + r[0])
        n[2] += (p[0] - r[0]) * (p[1] + r[1])
      end
      len = Math.sqrt(dot(n, n))
      len < 1e-9 ? nil : n.map { |v| v / len }
    end

    # Entrada e saída da reta p + t·u no sólido convexo: [t_in, plano_in, t_out, plano_out]
    def line_hit(p, u, planes)
      t_in, t_out = -Float::INFINITY, Float::INFINITY
      pl_in = pl_out = nil
      planes.each do |q, n|
        den = dot(n, u)
        num = dot(n, sub(q, p))
        if den.abs < 1e-9
          return nil if num < -1e-6 # reta fora deste lado
          next
        end
        t = num / den
        if den < 0
          (t_in, pl_in = t, [q, n]) if t > t_in
        elsif t < t_out
          t_out, pl_out = t, [q, n]
        end
      end
      return nil if t_in >= t_out - 1e-6 || pl_in.nil? || pl_out.nil?
      [t_in, pl_in, t_out, pl_out]
    end

    # --------------------------------------------------------------------------
    # Corte de um tubo avulso
    # --------------------------------------------------------------------------
    def trim_tube(model, grp, tr, obstacles, max_ext, stats)
      t = tubes(grp).first
      return unless t && t['axis'] == 'x'
      w = t['w_mm'].to_f
      yc = t['y_mm'].to_f + t['d_mm'].to_f / 2.0
      zc = t['z_mm'].to_f + t['h_mm'].to_f / 2.0
      x0 = t['x_mm'].to_f
      p0 = world(tr, [x0, yc, zc])
      p1 = world(tr, [x0 + w, yc, zc])
      len_w = Math.sqrt(dot(sub(p1, p0), sub(p1, p0)))
      if (len_w - w).abs > 0.5
        stats[:scaled] += 1
        return
      end
      u = sub(p1, p0).map { |v| v / len_w }
      ends = ends_of(t)
      s_a = end_offset(ends['a'], yc, zc, t)
      s_b = w - end_offset(ends['b'], yc, zc, t)
      mid = (s_a + s_b) / 2.0

      hits = obstacles.filter_map { |s| line_hit(p0, u, solid_planes(s)) }
      # Ponta B: o vizinho contém a ponta ou começa logo depois dela
      cand_b = hits.select { |ti, _, to, _| ti > mid && ti <= s_b + max_ext && to > s_b + 0.05 }.min_by(&:first)
      # Ponta A: o mesmo para trás
      cand_a = hits.select { |ti, _, to, _| to < mid && to >= s_a - max_ext && ti < s_a - 0.05 }.max_by { |h| h[2] }

      inv = tr.inverse
      new_ends = ends.dup
      xa_corners = nil
      xb_corners = nil
      done = Hash.new(0) # só entra no resumo se o tubo for redesenhado

      if cand_b && (cand_b[0] - s_b).abs > 0.05
        res = end_from_plane(cand_b[1], u, inv, t, :b)
        if res.is_a?(Symbol)
          stats[res] += 1
        else
          new_ends['b'], xb_corners = res
          done[cand_b[0] < s_b ? :trimmed : :extended] += 1
        end
      end
      if cand_a && (cand_a[2] - s_a).abs > 0.05
        res = end_from_plane(cand_a[3], u, inv, t, :a)
        if res.is_a?(Symbol)
          stats[res] += 1
        else
          new_ends['a'], xa_corners = res
          done[cand_a[2] > s_a ? :trimmed : :extended] += 1
        end
      end
      return if done.empty?

      old = tube_corners(t)
      xa_corners ||= old[:a].map(&:first)
      xb_corners ||= old[:b].map(&:first)
      if xb_corners.zip(xa_corners).any? { |xb, xa| xb - xa < 1.0 }
        stats[:short] += 1
        return
      end
      done.each { |k, v| stats[k] += v }
      x_start = xa_corners.min
      x_end = xb_corners.max
      t2 = t.merge(
        'x_mm' => x_start.round(3), 'w_mm' => (x_end - x_start).round(3), 'length_mm' => (x_end - x_start).round(1),
        'ends' => new_ends.compact,
        'cut_a_deg' => end_angle(new_ends['a']), 'cut_b_deg' => end_angle(new_ends['b'])
      )
      rebuild_single_tube(model, grp, t2)
    end

    # Plano do vizinho (mm do modelo) -> ponta no formato do tubo e x de cada canto
    def end_from_plane(plane, u, inv, t, side)
      q, n = plane
      cos = dot(n, u).abs.clamp(0.0, 1.0)
      angle = Math.acos(cos) * 180.0 / Math::PI
      return :steep if angle > MAX_ANGLE + 1e-6
      ql = local(inv, q)
      nv = Geom::Vector3d.new(*n).transform(inv)
      nv.normalize!
      nx, ny, nz = nv.x, nv.y, nv.z
      if angle > 0.05
        return :compound if ny.abs > 1e-3 && nz.abs > 1e-3
      else
        ny = nz = 0.0
      end
      corners = tube_corners(t)[side]
      xs = corners.map { |_, y, z| ql[0] - (ny * (y - ql[1]) + nz * (z - ql[2])) / nx }
      tan = (angle > 0.05 ? (ny.abs > nz.abs ? ny : nz).abs / nx.abs : 0.0)
      return [nil, xs] if tan.zero?
      axis = ny.abs > nz.abs ? 'y' : 'z'
      # Ponta longa: canto mais para fora (máximo em B, mínimo em A)
      far = side == :b ? xs.each_with_index.max_by(&:first)[1] : xs.each_with_index.min_by(&:first)[1]
      lo = axis == 'y' ? [0, 3].include?(far) : [0, 1].include?(far)
      [{ 'axis' => axis, 'tan' => tan.round(6), 'long' => lo ? 'min' : 'max' }, xs]
    end

    def end_angle(e)
      return 0.0 unless e.is_a?(Hash) && e['tan'].to_f > 0
      (Math.atan(e['tan'].to_f) * 180.0 / Math::PI).round(1)
    end

    def rebuild_single_tube(model, grp, t)
      grp.entities.clear!
      sym = t.transform_keys(&:to_sym)
      FrameKernel.draw_tube_3d(model, grp.entities, sym, 'tipo')
      grp.set_attribute(Catalog::ATTR_DICT, 'tubes_json', JSON.generate([t]))
      params = JSON.parse(grp.get_attribute(Catalog::ATTR_DICT, 'params_json').to_s) rescue {}
      params = {} unless params.is_a?(Hash)
      params.merge!('length_mm' => t['length_mm'], 'cut_a_deg' => t['cut_a_deg'], 'cut_b_deg' => t['cut_b_deg'])
      grp.set_attribute(Catalog::ATTR_DICT, 'params_json', JSON.generate(params))
    end

    # --------------------------------------------------------------------------
    # Vetores em mm
    # --------------------------------------------------------------------------
    def world(tr, p)
      q = Geom::Point3d.new(p.map { |v| v.to_f.mm }).transform(tr)
      [q.x.to_mm, q.y.to_mm, q.z.to_mm]
    end

    def local(inv, p)
      world(inv, p)
    end

    def sub(a, b)
      [a[0] - b[0], a[1] - b[1], a[2] - b[2]]
    end

    def dot(a, b)
      a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
    end
  end
end
