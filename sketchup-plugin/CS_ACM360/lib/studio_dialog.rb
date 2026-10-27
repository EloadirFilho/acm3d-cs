# encoding: UTF-8
# ==============================================================================
# CS_ACM360::StudioDialog
# Gerencia a janela interativa UI::HtmlDialog dentro do SketchUp, conectando
# os controles visuais (Construtor de Estruturas, Bandejas ACM, Emendas,
# Planificação e Exportação DXF/ERP) aos Kernels Ruby.
# ==============================================================================

require 'json'

module CS_ACM360
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
        dialog_title: "CS ACM360 v#{CS_ACM360::PLUGIN_VERSION} · Construtor ao Vivo & Planificador",
        preferences_key: 'CS_ACM360_StudioDialog',
        scrollable: true,
        resizable: true,
        width: 980,
        height: 700,
        min_width: 760,
        min_height: 540,
        style: UI::HtmlDialog::STYLE_DIALOG
      )

      html_path = File.join(CS_ACM360::PLUGIN_DIR, 'ui', 'studio.html')
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

      dlg.add_action_callback('insert_fastener') do |_ctx, code|
        AcmTrayKernel.insert_fastener_block(code.to_s)
      end

      dlg.add_action_callback('set_color_mode') do |_ctx, mode|
        FrameKernel.apply_color_mode_to_model(mode.to_s)
        push_state_to_ui
      end

      dlg.add_action_callback('refresh_state') do |_ctx|
        push_state_to_ui
      end
    end

    def self.push_state_to_ui(tab = nil)
      return unless @dialog && @dialog.visible?
      payload = UnfoldDxfEngine.build_erp_payload
      payload['profiles'] = Catalog::TUBE_PROFILES
      payload['initial_tab'] = tab if tab
      json_str = JSON.generate(payload)
      @dialog.execute_script("window.CSStudio && window.CSStudio.loadModelState(#{json_str});")
    end
  end
end
