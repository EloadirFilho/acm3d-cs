# encoding: UTF-8
# ==============================================================================
# CS_ACM360 - Arquivo Principal da Extensão SketchUp (main.rb)
# Registra Kernels, Menus, Barra de Ferramentas e Menu de Contexto (Botão Direito)
# ==============================================================================

require 'sketchup.rb'

require File.join(CS_ACM360_BETA::PLUGIN_DIR, 'lib', 'catalog')
require File.join(CS_ACM360_BETA::PLUGIN_DIR, 'lib', 'settings')
require File.join(CS_ACM360_BETA::PLUGIN_DIR, 'lib', 'frame_kernel')
require File.join(CS_ACM360_BETA::PLUGIN_DIR, 'lib', 'acm_tray_kernel')
require File.join(CS_ACM360_BETA::PLUGIN_DIR, 'lib', 'hardware_fasteners')
require File.join(CS_ACM360_BETA::PLUGIN_DIR, 'lib', 'report_generator')
require File.join(CS_ACM360_BETA::PLUGIN_DIR, 'lib', 'unfold_dxf_engine')
require File.join(CS_ACM360_BETA::PLUGIN_DIR, 'lib', 'studio_dialog')

module CS_ACM360_BETA
  unless file_loaded?(__FILE__)
    # 1. Menu Principal em Extensões > CS ACM360 (Estruturas & ACM)
    ext_menu = UI.menu('Plugins').add_submenu('CS ACM360 BETA · Estruturas & ACM')

    ext_menu.add_item('Abrir Construtor ao Vivo (Painel Completo)…') do
      StudioDialog.show('frame')
    end
    ext_menu.add_separator

    # Submenu Estruturas
    sub_str = ext_menu.add_submenu('Estruturas Metálicas')
    sub_str.add_item('Novo Gradil com Travessas…') { StudioDialog.show('frame') }
    sub_str.add_item('Novo Tubo Avulso…') { StudioDialog.show('tube') }
    sub_str.add_item('Criar Estrutura das Bandejas ACM (Ler ACM)') do
      AcmTrayKernel.create_frame_from_trays
    end
    sub_str.add_separator
    sub_str.add_item('Cor por Tipo de Tubo') { FrameKernel.apply_color_mode_to_model('tipo') }
    sub_str.add_item('Cor por Comprimento')  { FrameKernel.apply_color_mode_to_model('comprimento') }
    sub_str.add_item('Cor Única (Acabamento)') { FrameKernel.apply_color_mode_to_model('unica') }

    # Submenu Bandejas ACM & Planificação
    sub_acm = ext_menu.add_submenu('Bandejas ACM & Planificação')
    sub_acm.add_item('Nova Bandeja ACM Paramétrica…') { StudioDialog.show('tray') }
    sub_acm.add_item('Criar Fachada em Malha (Bandejas + Estrutura)…') { StudioDialog.show('facade') }
    sub_acm.add_separator
    sub_acm.add_item('Planificar Bandeja Selecionada no 3D') do
      UnfoldDxfEngine.place_unfolded_tray_in_model
    end
    sub_acm.add_item('Plano de Corte de Chapas & Exportar DXF CNC…') do
      UnfoldDxfEngine.export_model_trays_to_dxf
    end

    # Submenu Fixadores 3D & Colagem
    sub_fix = ext_menu.add_submenu('Fixadores 3D & Colagem VHB')
    sub_fix.add_item('Distribuir Cantoneiras (F003) na Seleção…') do
      sel = Sketchup.active_model.selection.grep(Sketchup::Group).select { |g| g.get_attribute(Catalog::ATTR_DICT, 'kind') == 'acm_tray' }
      if sel.empty?
        UI.messagebox('Selecione pelo menos uma Bandeja ACM para distribuir cantoneiras.')
      else
        sel.each { |t| HardwareFasteners.distribute_fasteners_on_tray(t) }
        UI.messagebox("Cantoneiras distribuídas com sucesso em #{sel.size} bandeja(s)!")
      end
    end
    sub_fix.add_item('Calcular Fita 3M VHB & Promotor de Adesão…') do
      vhb = HardwareFasteners.calculate_vhb_tape_requirements
      UI.messagebox(
        "--- CÁLCULO DE COLAGEM · #{vhb[:tape_name]} ---\n\n" \
        "Bandejas Analisadas: #{vhb[:tray_count]}\n" \
        "Perímetro de Dobras: #{vhb[:perimeter_meters]} m\n" \
        "Reforços Intermediários: #{vhb[:stiffener_meters]} m\n" \
        "Total Fita VHB: #{vhb[:total_tape_meters]} m\n" \
        "Rolos de #{vhb[:roll_m]}m recomendados: #{vhb[:rolls_needed]} rolo(s)\n" \
        "Promotor Primer 3M AP111 / 94: #{vhb[:primer_cans]} frasco(s) (250ml)"
      )
    end
    sub_fix.add_separator
    sub_fix.add_item('Inserir Ancoragem (F001)')          { AcmTrayKernel.insert_fastener_block('F001') }
    sub_fix.add_item('Inserir Espera (F002)')             { AcmTrayKernel.insert_fastener_block('F002') }
    sub_fix.add_item('Inserir Cantoneira Fixador (F003)') { AcmTrayKernel.insert_fastener_block('F003') }

    ext_menu.add_separator
    ext_menu.add_item('Relatório Estrutural & Plano de Barras 1D…') { StudioDialog.show('report') }
    ext_menu.add_item('Exportar Lista de Corte (Excel XLSX / CSV)…') { StudioDialog.show('report') }
    ext_menu.add_item('Publicar Projeto para CS Fachadas ERP (.json)…') do
      UnfoldDxfEngine.export_erp_json_dialog
    end
    ext_menu.add_separator
    ext_menu.add_item('Configurações (Barras, ACM, Bitolas, Fitas, Impressão)…') { StudioDialog.show('settings') }

    # 2. Barra de Ferramentas (Toolbar)
    toolbar = UI::Toolbar.new('CS ACM360 BETA')

    cmd_studio = UI::Command.new('Construtor ao Vivo') { StudioDialog.show('frame') }
    cmd_studio.tooltip = 'CS ACM360 — Construtor ao Vivo (Gradil, Tubos e Emendas)'
    cmd_studio.status_bar_text = 'Abre o Construtor ao Vivo CS ACM360'
    toolbar.add_item(cmd_studio)

    cmd_tray = UI::Command.new('Bandeja ACM') { StudioDialog.show('tray') }
    cmd_tray.tooltip = 'Bandeja ACM (Desenhar, Dobras, Abas e Malha)'
    cmd_tray.status_bar_text = 'Criar ou editar Bandejas de ACM'
    toolbar.add_item(cmd_tray)

    cmd_ler_acm = UI::Command.new('Ler ACM → Estrutura') { AcmTrayKernel.create_frame_from_trays }
    cmd_ler_acm.tooltip = 'Criar estrutura metálica automática a partir das Bandejas ACM'
    cmd_ler_acm.status_bar_text = 'Lê as juntas das bandejas ACM e gera o gradil metálico atrás'
    toolbar.add_item(cmd_ler_acm)

    cmd_unfold = UI::Command.new('Planificar 3D') { UnfoldDxfEngine.place_unfolded_tray_in_model }
    cmd_unfold.tooltip = 'Planificar Bandeja ACM no 3D (Corte + Vinco)'
    cmd_unfold.status_bar_text = 'Desenha a chapa aberta com linhas de corte e fresa ao lado da peça'
    toolbar.add_item(cmd_unfold)

    cmd_dxf = UI::Command.new('Exportar DXF') { UnfoldDxfEngine.export_model_trays_to_dxf }
    cmd_dxf.tooltip = 'Exportar Plano de Corte DXF CNC (AC1009)'
    cmd_dxf.status_bar_text = 'Gera arquivo DXF com camadas ACM_CHAPA, ACM_CORTE, ACM_VINCO, ACM_DIRECAO e ACM_ETIQUETAS'
    toolbar.add_item(cmd_dxf)

    cmd_report = UI::Command.new('Relatório & Excel') { StudioDialog.show('report') }
    cmd_report.tooltip = 'Relatório de produção: lista de corte, plano de barras e materiais (XLSX, CSV e impressão)'
    cmd_report.status_bar_text = 'Gera relatório com resumo de materiais, lista de corte de tubos e bandejas de ACM'
    toolbar.add_item(cmd_report)

    cmd_erp = UI::Command.new('Publicar ERP') { UnfoldDxfEngine.export_erp_json_dialog }
    cmd_erp.tooltip = 'Publicar para CS Fachadas ERP (.json)'
    cmd_erp.status_bar_text = 'Exporta estruturas, plano de barras e chapas ACM para o CS Fachadas ERP'
    toolbar.add_item(cmd_erp)

    toolbar.restore

    # 3. Menu de Contexto (Botão Direito na Viewport)
    UI.add_context_menu_handler do |context_menu|
      model = Sketchup.active_model
      next unless model && !model.selection.empty?
      first = model.selection.first
      next unless first.is_a?(Sketchup::Group)
      kind = first.get_attribute(Catalog::ATTR_DICT, 'kind')
      next unless kind

      sub = context_menu.add_submenu('CS ACM360 BETA')
      if kind == 'parametric_frame'
        sub.add_item('Editar Estrutura no Painel…') { StudioDialog.show('frame') }
        sub.add_item('Ver Relatório e Emendas de Barra…') { StudioDialog.show('report') }
      elsif kind == 'acm_tray'
        sub.add_item('Planificar Bandeja no 3D') { UnfoldDxfEngine.place_unfolded_tray_in_model(first) }
        sub.add_item('Distribuir Cantoneiras (F003)') { HardwareFasteners.distribute_fasteners_on_tray(first) }
        sub.add_item('Criar Estrutura Metálica desta(s) Bandeja(s)') { AcmTrayKernel.create_frame_from_trays }
        sub.add_item('Exportar DXF CNC…') { UnfoldDxfEngine.export_model_trays_to_dxf }
      end
      sub.add_separator
      sub.add_item('Relatório de Produção (Excel / Impressão)…') { StudioDialog.show('report') }
      sub.add_item('Publicar para CS Fachadas ERP…') { UnfoldDxfEngine.export_erp_json_dialog }
    end

    file_loaded(__FILE__)
  end
end
