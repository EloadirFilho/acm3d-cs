# encoding: UTF-8
# ==============================================================================
# CS_ACM360_BETA::StudioDialog
# Gerencia a janela interativa UI::HtmlDialog dentro do SketchUp, conectando
# os controles visuais (Construtor de Estruturas, Bandejas ACM, Emendas,
# Planificação e Exportação DXF/ERP) aos Kernels Ruby.
# ==============================================================================

require 'json'

module CS_ACM360_BETA
  module StudioDialog
    @dialog = nil

    def self.show(initial_tab = 'frame')
      if @dialog && @dialog.visible?
        @dialog.bring_to_front
        @dialog.execute_script("window.CSStudio && window.CSStudio.switchTab('#{initial_tab}');")
        push_state_to_ui
        return
      end

      @dialog = UI::HtmlDialog.new(
        dialog_title: "CS ACM360 BETA v#{CS_ACM360_BETA::PLUGIN_VERSION} · Construtor ao Vivo & Planificador",
        preferences_key: 'CS_ACM360_BETA_StudioDialog',
        scrollable: true,
        resizable: true,
        width: 980,
        height: 700,
        min_width: 760,
        min_height: 540,
        style: UI::HtmlDialog::STYLE_DIALOG
      )

      html_path = File.join(CS_ACM360_BETA::PLUGIN_DIR, 'ui', 'studio.html')
      @dialog.set_file(html_path)

      register_callbacks(@dialog, initial_tab)
      @dialog.show
    end

    def self.register_callbacks(dlg, initial_tab)
      dlg.add_action_callback('ready') do |_ctx|
        push_state_to_ui(initial_tab)
      end

      dlg.add_action_callback('create_or_update_frame') do |_ctx, json_str|
        params = JSON.parse(json_str.to_s) rescue {}
        existing = params['update_selected'] ? FrameKernel.read_selected_frame : nil
        FrameKernel.create_or_update_frame(params, existing)
        push_state_to_ui
      end

      dlg.add_action_callback('create_single_tube') do |_ctx, json_str|
        params = JSON.parse(json_str.to_s) rescue {}
        FrameKernel.create_single_tube(params)
        push_state_to_ui
      end

      dlg.add_action_callback('create_or_update_tray') do |_ctx, json_str|
        params = JSON.parse(json_str.to_s) rescue {}
        AcmTrayKernel.create_or_update_tray(params)
        push_state_to_ui
      end

      dlg.add_action_callback('create_facade_grid') do |_ctx, json_str|
        params = JSON.parse(json_str.to_s) rescue {}
        AcmTrayKernel.create_facade_grid(params)
        push_state_to_ui
      end

      dlg.add_action_callback('read_trays_create_frame') do |_ctx, json_str|
        opts = JSON.parse(json_str.to_s) rescue {}
        AcmTrayKernel.create_frame_from_trays(nil, opts, true)
        push_state_to_ui
      end

      dlg.add_action_callback('unfold_selected_3d') do |_ctx|
        UnfoldDxfEngine.place_unfolded_tray_in_model
        push_state_to_ui
      end

      dlg.add_action_callback('export_dxf') do |_ctx|
        UnfoldDxfEngine.export_model_trays_to_dxf
      end

      dlg.add_action_callback('export_erp_json') do |_ctx|
        UnfoldDxfEngine.export_erp_json_dialog
      end

      dlg.add_action_callback('side_panel') { |_ctx| SidePanel.toggle }

      # --- M1: ferramentas na tela, com os campos do painel ---
      dlg.add_action_callback('start_tool') do |_ctx, json_str|
        data = JSON.parse(json_str.to_s) rescue {}
        LiveTool.start(data['tool'], data['params'].is_a?(Hash) ? data['params'] : {})
      end

      # --- M5/M6: corte nas interferências e recortes nas bandejas ---
      {
        'cut_interferences'   => -> { InterferenceKernel.cut_selection },
        'tray_cutouts_auto'   => -> { TrayCutouts.auto_selection },
        'tray_cutouts_contour'=> -> { TrayCutouts.contour_selection },
        'mark_as_hole'        => -> { TrayCutouts.mark_holes },
        'clear_tray_cutouts'  => -> { TrayCutouts.clear_selection }
      }.each do |name, action|
        dlg.add_action_callback(name) do |_ctx|
          begin
            msg = action.call
            push_state_to_ui
            dlg.execute_script("window.CSStudio && window.CSStudio.setStatus(#{JSON.generate(msg.lines.first.to_s.strip)});")
            UI.messagebox(msg)
          rescue StandardError => e
            UI.messagebox("Erro: #{e.class}: #{e.message}")
          end
        end
      end

      # --- M4: Fixadores ---
      dlg.add_action_callback('distribute_fasteners') do |_ctx, type|
        begin
          msg = HardwareFasteners.distribute_from_selection(type.to_s)
          push_state_to_ui
          dlg.execute_script("window.CSStudio && window.CSStudio.setStatus(#{JSON.generate(msg)});")
        rescue StandardError => e
          UI.messagebox("Erro ao distribuir fixadores: #{e.class}: #{e.message}")
        end
      end

      dlg.add_action_callback('remove_fasteners') do |_ctx|
        msg = HardwareFasteners.remove_from_selection
        push_state_to_ui
        dlg.execute_script("window.CSStudio && window.CSStudio.setStatus(#{JSON.generate(msg)});")
      end

      dlg.add_action_callback('set_color_mode') do |_ctx, mode|
        FrameKernel.apply_color_mode_to_model(mode.to_s)
        push_state_to_ui
      end

      dlg.add_action_callback('refresh_state') do |_ctx|
        push_state_to_ui
      end

      # --- M8: Relatório (arquivos gerados em ui/acm360-report.js) ---
      dlg.add_action_callback('save_report_file') do |_ctx, json_str|
        begin
          payload = JSON.parse(json_str.to_s)
          path = ReportGenerator.save_file(payload)
          msg = path ? "Relatório salvo em #{path}" : 'Exportação cancelada'
          dlg.execute_script("window.CSStudio && window.CSStudio.setStatus(#{JSON.generate(msg)});")
          UI.messagebox("Relatório salvo em:\n#{path}") if path
        rescue StandardError => e
          UI.messagebox("Erro ao exportar o relatório: #{e.class}: #{e.message}")
        end
      end

      dlg.add_action_callback('print_report') do |_ctx, html|
        begin
          ReportGenerator.open_print_view(html)
        rescue StandardError => e
          UI.messagebox("Erro ao abrir o relatório para impressão: #{e.class}: #{e.message}")
        end
      end

      # --- M12: Configurações ---
      dlg.add_action_callback('save_settings') do |_ctx, json_str|
        raw = JSON.parse(json_str.to_s) rescue nil
        if raw.is_a?(Hash)
          fix_keys = %w[fastener_spacing_mm fastener_offset_mm anchor_spacing_mm anchor_margin_mm standoff_mm fastener_specs]
          old_cfg = Settings.all
          before, fix_before = old_cfg.values_at('bar_mm', 'kerf_mm'), old_cfg.values_at(*fix_keys)
          new_cfg = Settings.save(raw)
          n = before != new_cfg.values_at('bar_mm', 'kerf_mm') ? FrameKernel.regenerate_all_frames : 0
          f = fix_before != new_cfg.values_at(*fix_keys) ? HardwareFasteners.redraw_all : 0
          msg = 'Configurações salvas'
          msg += " · #{n} estrutura(s) regerada(s) com a nova barra" if n > 0
          msg += " · #{f} fixador(es) redesenhado(s)" if f > 0
          push_state_to_ui
          dlg.execute_script("window.CSStudio && window.CSStudio.setStatus(#{JSON.generate(msg)});")
        end
      end

      dlg.add_action_callback('reset_settings') do |_ctx|
        if UI.messagebox('Voltar todas as configurações ao padrão de fábrica (nesta máquina e neste modelo)?', MB_YESNO) == IDYES
          Settings.reset!
          FrameKernel.regenerate_all_frames
          push_state_to_ui
        end
      end

      dlg.add_action_callback('export_settings') do |_ctx|
        path = UI.savepanel('Exportar Configurações CS ACM360', nil, 'CS_ACM360_config.json')
        if path
          path += '.json' unless path.downcase.end_with?('.json')
          File.write(path, JSON.pretty_generate(Settings.export_payload), mode: 'w:UTF-8')
        end
      end

      dlg.add_action_callback('import_settings') do |_ctx|
        path = UI.openpanel('Importar Configurações CS ACM360', nil, 'Configuração|*.json||')
        if path
          begin
            Settings.import_payload(File.read(path, mode: 'r:UTF-8'))
            FrameKernel.regenerate_all_frames
            push_state_to_ui
          rescue StandardError => e
            UI.messagebox("Não foi possível importar: #{e.message}")
          end
        end
      end
    end

    def self.push_state_to_ui(tab = nil)
      SidePanel.refresh if defined?(SidePanel)
      return unless @dialog && @dialog.visible?
      payload = UnfoldDxfEngine.build_erp_payload
      payload['profiles'] = Settings.profiles
      payload['plugin_version'] = CS_ACM360_BETA::PLUGIN_VERSION
      payload['settings'] = Settings.all
      payload['fasteners'] = ReportGenerator.count_fasteners
      payload['initial_tab'] = tab if tab
      json_str = JSON.generate(payload)
      @dialog.execute_script("window.CSStudio && window.CSStudio.loadModelState(#{json_str});")
    end
  end
end
