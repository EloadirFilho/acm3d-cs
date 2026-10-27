# encoding: UTF-8
# ==============================================================================
# CS_ACM360 - Módulo de Fixadores e Colagem (hardware_fasteners.rb)
# Implementa os Módulos M3 (Colagem / Fita VHB) e M4 (Fixadores Avançados)
# ==============================================================================

module CS_ACM360
  module HardwareFasteners
    extend self

    # Regras padrão de distribuição
    DEFAULT_FASTENER_SPACING_MM = 400.0 # Espaçamento padrão entre cantoneiras (mm)
    DEFAULT_CORNER_OFFSET_MM   = 70.0  # Distância do canto até o primeiro fixador (mm)
    VHB_ROLL_LENGTH_METERS     = 33.0  # Rolo padrão de fita 3M VHB (33 metros)

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

      trays.each do |t|
        w = t.get_attribute(Catalog::ATTR_DICT, 'width', 1000.0).to_f
        h = t.get_attribute(Catalog::ATTR_DICT, 'height', 600.0).to_f
        
        # Perímetro de colagem das abas/retornos (4 lados)
        perimeter = 2.0 * (w + h)
        total_perimeter_mm += perimeter

        # Reforços intermediários colados no verso do ACM (a cada ~400mm de vão)
        if h > 450.0
          vertical_stiffeners = [(w / 400.0).floor - 1, 0].max
          total_stiffener_mm += vertical_stiffeners * (h - 100.0)
        end
      end

      total_tape_m = (total_perimeter_mm + total_stiffener_mm) / 1000.0
      rolls_needed = (total_tape_m / VHB_ROLL_LENGTH_METERS).ceil
      
      # Primer 3M AP111 / 94 (aprox. 1 frasco de 250ml para cada 100 metros lineares)
      primer_cans = [(total_tape_m / 100.0).ceil, 1].max

      {
        tray_count: tray_count,
        perimeter_meters: (total_perimeter_mm / 1000.0).round(2),
        stiffener_meters: (total_stiffener_mm / 1000.0).round(2),
        total_tape_meters: total_tape_m.round(2),
        rolls_needed: rolls_needed,
        primer_cans: primer_cans
      }
    end

    # --------------------------------------------------------------------------
    # M4: Distribuição Automática de Cantoneiras / Fixadores em Bandejas ACM
    # --------------------------------------------------------------------------
    def distribute_fasteners_on_tray(tray_group, opts = {})
      return unless tray_group && tray_group.valid?

      spacing = (opts[:spacing] || DEFAULT_FASTENER_SPACING_MM).to_f.mm
      offset  = (opts[:offset]  || DEFAULT_CORNER_OFFSET_MM).to_f.mm
      fastener_type = opts[:fastener_type] || 'F003' # Cantoneira_Fixador_F003

      w = tray_group.get_attribute(Catalog::ATTR_DICT, 'width', 1000.0).to_f.mm
      h = tray_group.get_attribute(Catalog::ATTR_DICT, 'height', 600.0).to_f.mm
      fold = tray_group.get_attribute(Catalog::ATTR_DICT, 'fold_depth', 25.0).to_f.mm

      skp_path = File.join(CS_ACM360::PLUGIN_DIR, 'BLOCOS', "#{fastener_type_filename(fastener_type)}.skp")
      unless File.exist?(skp_path)
        UI.messagebox("Bloco de fixador não encontrado:\n#{skp_path}")
        return
      end

      model = Sketchup.active_model
      model.start_operation('CS ACM360: Distribuir Fixadores', true)

      cdef = model.definitions.load(skp_path)
      fastener_subgroup = tray_group.entities.add_group
      fastener_subgroup.name = "Fixadores_#{fastener_type}"
      fastener_subgroup.set_attribute(Catalog::ATTR_DICT, 'kind', 'fastener_array')

      # Distribui nos 4 lados das abas da bandeja
      # Lado Inferior (Y = 0)
      place_linear_fasteners(fastener_subgroup.entities, cdef, [offset, 0, 0], [w - offset, 0, 0], spacing, 0.0)
      # Lado Superior (Y = h)
      place_linear_fasteners(fastener_subgroup.entities, cdef, [offset, h, 0], [w - offset, h, 0], spacing, 180.0.degrees)
      # Lado Esquerdo (X = 0)
      place_linear_fasteners(fastener_subgroup.entities, cdef, [0, offset, 0], [0, h - offset, 0], spacing, 90.0.degrees)
      # Lado Direito (X = w)
      place_linear_fasteners(fastener_subgroup.entities, cdef, [w, offset, 0], [w, h - offset, 0], spacing, -90.0.degrees)

      model.commit_operation
    end

    # --------------------------------------------------------------------------
    # Insere fixadores ao longo de uma linha de pontos
    # --------------------------------------------------------------------------
    def place_linear_fasteners(entities, cdef, pt_start, pt_end, spacing, rot_angle)
      p1 = Geom::Point3d.new(pt_start)
      p2 = Geom::Point3d.new(pt_end)
      vec = p2 - p1
      len = vec.length
      return if len <= 0

      dir = vec.normalize
      count = [ (len / spacing).floor, 1 ].max
      step = len / count

      (0..count).each do |i|
        pos = p1.offset(dir, step * i)
        tr = Geom::Transformation.new(pos)
        if rot_angle != 0.0
          tr_rot = Geom::Transformation.rotation(pos, Geom::Vector3d.new(0, 0, 1), rot_angle)
          tr = tr_rot * tr
        end
        inst = entities.add_instance(cdef, tr)
        inst.set_attribute(Catalog::ATTR_DICT, 'kind', 'fastener_instance')
      end
    end

    def fastener_type_filename(code)
      case code.to_s.upcase
      when 'F001', 'ANCORAGEM'
        'Ancoragem_F001'
      when 'F002', 'ESPERA'
        'Espera_F002'
      else
        'Cantoneira_Fixador_F003'
      end
    end

    def find_all_acm_trays(model)
      trays = []
      model.entities.each do |e|
        next unless e.is_a?(Sketchup::Group)
        kind = e.get_attribute(Catalog::ATTR_DICT, 'kind')
        trays << e if kind == 'acm_tray'
      end
      trays
    end

  end
end
