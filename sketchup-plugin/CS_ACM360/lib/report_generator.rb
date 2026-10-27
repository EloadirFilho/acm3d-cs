# encoding: UTF-8
# ==============================================================================
# CS_ACM360 - Gerador de Relatórios e Exportador CSV/Excel (report_generator.rb)
# Implementa o Módulo M8 (Relatório Estrutural, Lista de Corte e Lista de Materiais)
# ==============================================================================

require 'csv'

module CS_ACM360
  module ReportGenerator
    extend self

    # --------------------------------------------------------------------------
    # Gera a árvore completa de dados do projeto para exibição ou exportação
    # --------------------------------------------------------------------------
    def collect_project_data(model = nil)
      model ||= Sketchup.active_model
      tubes = []
      trays = []
      fastener_count = Hash.new(0)

      model.entities.each do |e|
        next unless e.is_a?(Sketchup::Group)
        kind = e.get_attribute(Catalog::ATTR_DICT, 'kind')

        case kind
        when 'parametric_frame'
          # Coleta os tubos filhos
          e.entities.each do |sub|
            next unless sub.is_a?(Sketchup::Group)
            sub_kind = sub.get_attribute(Catalog::ATTR_DICT, 'kind')
            if sub_kind == 'tube'
              tubes << extract_tube_data(sub)
            end
          end
        when 'tube'
          tubes << extract_tube_data(e)
        when 'acm_tray'
          trays << extract_tray_data(e)
        end

        # Busca fixadores no grupo
        count_fasteners_in_group(e, fastener_count)
      end

      # Cálculo de Colagem VHB
      vhb_data = HardwareFasteners.calculate_vhb_tape_requirements(trays.empty? ? nil : nil)

      # 1D Bar Nesting dos tubos coletados
      bar_packing = calculate_bar_nesting(tubes)

      {
        project_name: File.basename(model.path.to_s.empty? ? 'Projeto_Fachada_ACM' : model.path, '.*'),
        date: Time.now.strftime('%d/%m/%Y %H:%M'),
        tubes: tubes,
        trays: trays,
        bar_packing: bar_packing,
        fasteners: fastener_count,
        vhb_data: vhb_data,
        summary: build_materials_summary(tubes, trays, bar_packing, fastener_count, vhb_data)
      }
    end

    # --------------------------------------------------------------------------
    # Exporta o relatório completo para arquivo CSV com UTF-8 BOM (compatível com Excel)
    # --------------------------------------------------------------------------
    def export_csv_dialog
      model = Sketchup.active_model
      default_name = "#{File.basename(model.path.to_s.empty? ? 'relatorio_acm360' : model.path, '.*')}_corte.csv"
      path = UI.savepanel('Salvar Relatório de Produção (CSV)', '', default_name)
      return unless path

      data = collect_project_data(model)
      export_to_csv(path, data)
      UI.messagebox("Relatório exportado com sucesso em:\n#{path}")
    end

    def export_to_csv(filepath, data)
      # Adiciona UTF-8 BOM (\xEF\xBB\xBF) para que o Microsoft Excel abra sem corromper acentos
      File.open(filepath, 'w:UTF-8') do |f|
        f.write("\xEF\xBB\xBF")

        f.puts "# CS ACM360 - RELATÓRIO DE PRODUÇÃO E LISTA DE CORTE"
        f.puts "# Projeto: #{data[:project_name]}"
        f.puts "# Data de Emissão: #{data[:date]}"
        f.puts ""

        # SEÇÃO 1: RESUMO DE MATERIAIS
        f.puts "--- RESUMO GERAL DE COMPRA E PRODUÇÃO ---"
        f.puts "Item;Especificação;Quantidade;Unidade"
        f.puts "Barras de 6000mm;Metalon / Alumínio;#{data[:bar_packing][:total_bars]};un (6m)"
        f.puts "Total Metros Lineares;Tubos Estruturais;#{data[:bar_packing][:total_length_m]};m"
        f.puts "Aproveitamento de Barras;Eficiência Linear;#{data[:bar_packing][:efficiency_pct]}%;%"
        f.puts "Área Total de ACM;Chapas Planificadas;#{data[:summary][:total_acm_area_m2]};m²"
        f.puts "Fita 3M VHB;Dupla-face Estrutural (33m);#{data[:vhb_data][:rolls_needed]};rolos (#{data[:vhb_data][:total_tape_meters]} m)"
        f.puts "Primer 3M AP111 / 94;Promotor de Adesão (250ml);#{data[:vhb_data][:primer_cans]};frascos"
        f.puts "Cantoneiras de Fixação;Cantoneira Fixador (F003);#{data[:summary][:cantoneiras_count]};un"
        f.puts "Parafusos Autobrocantes;4.2 x 19mm c/ Vedação;#{data[:summary][:screws_count]};un"
        f.puts ""

        # SEÇÃO 2: LISTA DETALHADA DE CORTE DE TUBOS (SERRA)
        f.puts "--- LISTA DE CORTE DE TUBOS (SERRA) ---"
        f.puts "Barra 6m;Seq;Perfil;Função;Comprimento (mm);Corte Esq;Corte Dir;Peso Estimado (kg)"
        bar_idx = 1
        data[:bar_packing][:bars].each do |bar|
          bar[:cuts].each_with_index do |cut, c_idx|
            f.puts "#{bar_idx};#{c_idx + 1};#{cut[:profile]};#{cut[:role]};#{cut[:length_mm]};#{cut[:angle_start] || '0°'};#{cut[:angle_end] || '0°'};#{cut[:weight_kg]}"
          end
          bar_idx += 1
        end
        f.puts ""

        # SEÇÃO 3: LISTA DE BANDEJAS DE ACM (CNC ROUTER)
        f.puts "--- LISTA DE BANDEJAS DE ACM (CNC ROUTER) ---"
        f.puts "Tag;Cor/Padrão;Largura Fechada (mm);Altura Fechada (mm);Largura Aberta (mm);Altura Aberta (mm);Prof. Dobra (mm);Área Aberta (m²);Perímetro Vinco (m);Perímetro Corte (m)"
        data[:trays].each do |tray|
          f.puts "#{tray[:tag]};#{tray[:color]};#{tray[:folded_w]};#{tray[:folded_h]};#{tray[:flat_w]};#{tray[:flat_h]};#{tray[:fold_depth]};#{tray[:flat_area_m2]};#{tray[:crease_perimeter_m]};#{tray[:cut_perimeter_m]}"
        end
      end
    end

    # --------------------------------------------------------------------------
    # Métodos Auxiliares de Extração
    # --------------------------------------------------------------------------
    def extract_tube_data(g)
      prof = g.get_attribute(Catalog::ATTR_DICT, 'profile', 'Metalon 30x20 #18')
      role = g.get_attribute(Catalog::ATTR_DICT, 'role', 'Tubo')
      len  = g.get_attribute(Catalog::ATTR_DICT, 'length_mm', 1000.0).to_f.round(1)
      ang_start = g.get_attribute(Catalog::ATTR_DICT, 'angle_start', '0°')
      ang_end   = g.get_attribute(Catalog::ATTR_DICT, 'angle_end', '0°')

      # Peso teórico estimado (~0.85 kg/m para perfis comuns 30x20)
      weight = (len / 1000.0 * 0.85).round(2)

      {
        id: g.entityID,
        profile: prof,
        role: role,
        length_mm: len,
        angle_start: ang_start,
        angle_end: ang_end,
        weight_kg: weight
      }
    end

    def extract_tray_data(g)
      tag = g.name.to_s.empty? ? "Bandeja_#{g.entityID}" : g.name
      w = g.get_attribute(Catalog::ATTR_DICT, 'width', 1000.0).to_f.round(1)
      h = g.get_attribute(Catalog::ATTR_DICT, 'height', 600.0).to_f.round(1)
      fold = g.get_attribute(Catalog::ATTR_DICT, 'fold_depth', 25.0).to_f.round(1)
      color = g.get_attribute(Catalog::ATTR_DICT, 'color', 'Prata Brilhante')

      flat_w = (w + 2.0 * fold).round(1)
      flat_h = (h + 2.0 * fold).round(1)
      area_m2 = ((flat_w * flat_h) / 1_000_000.0).round(3)
      crease_m = (2.0 * (w + h) / 1000.0).round(2)
      cut_m = (2.0 * (flat_w + flat_h) / 1000.0).round(2)

      {
        tag: tag,
        color: color,
        folded_w: w,
        folded_h: h,
        fold_depth: fold,
        flat_w: flat_w,
        flat_h: flat_h,
        flat_area_m2: area_m2,
        crease_perimeter_m: crease_m,
        cut_perimeter_m: cut_m
      }
    end

    def count_fasteners_in_group(group, counter)
      group.entities.each do |e|
        if e.is_a?(Sketchup::Group)
          count_fasteners_in_group(e, counter)
        elsif e.is_a?(Sketchup::ComponentInstance)
          cname = e.definition.name
          if cname.include?('Cantoneira') || cname.include?('F003')
            counter['Cantoneira F003'] += 1
          elsif cname.include?('Ancoragem') || cname.include?('F001')
            counter['Ancoragem F001'] += 1
          elsif cname.include?('Espera') || cname.include?('F002')
            counter['Espera F002'] += 1
          end
        end
      end
    end

    # Empacotamento 1D (First-Fit Decreasing)
    def calculate_bar_nesting(tubes, bar_len = 6000.0, kerf = 4.0)
      return { total_bars: 0, total_length_m: 0, efficiency_pct: 100, bars: [] } if tubes.empty?

      sorted = tubes.sort_by { |t| -t[:length_mm] }
      bars = []

      sorted.each do |tube|
        placed = false
        req = tube[:length_mm] + kerf

        bars.each do |b|
          if b[:remaining_mm] >= req
            b[:cuts] << tube
            b[:remaining_mm] -= req
            placed = true
            break
          end
        end

        unless placed
          bars << {
            remaining_mm: bar_len - req,
            cuts: [tube]
          }
        end
      end

      total_used_len = tubes.sum { |t| t[:length_mm] }
      total_bar_len = bars.size * bar_len
      eff = total_bar_len > 0 ? ((total_used_len / total_bar_len) * 100.0).round(1) : 0.0

      {
        total_bars: bars.size,
        total_length_m: (total_used_len / 1000.0).round(2),
        efficiency_pct: eff,
        bars: bars
      }
    end

    def build_materials_summary(tubes, trays, bar_packing, fastener_count, vhb_data)
      total_acm_m2 = trays.sum { |t| t[:flat_area_m2] }.round(2)
      cantoneiras = fastener_count['Cantoneira F003'] || (trays.size * 8)
      # Média de 2 parafusos por cantoneira + 4 por emenda
      screws = (cantoneiras * 2) + (bar_packing[:total_bars] * 4)

      {
        total_acm_area_m2: total_acm_m2,
        cantoneiras_count: cantoneiras,
        screws_count: screws
      }
    end

  end
end
