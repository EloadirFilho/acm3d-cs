# encoding: UTF-8
# ==============================================================================
# CS_ACM360_BETA::SidePanel  (M1 — painel lateral)
# Janela estreita que fica ao lado da área de trabalho: botões das ferramentas,
# parâmetros da próxima peça (lembrados pelo LiveTool) e a peça selecionada,
# com medidas editáveis e as ações que valem para ela.
# ==============================================================================

require 'json'

module CS_ACM360_BETA
  module SidePanel
    extend self

    KINDS = %w[parametric_frame acm_tray single_tube].freeze

    def visible?
      !@dialog.nil? && @dialog.visible?
    end

    def toggle
      visible? ? close : show
    end

    # O SketchUp fecha a janela depois; o painel já conta como fechado
    def close
      dlg = @dialog
      @dialog = nil
      detach
      dlg.close if dlg
    end

    def show
      return @dialog.bring_to_front if visible?
      @dialog = UI::HtmlDialog.new(
        dialog_title: 'CS ACM360 BETA',
        preferences_key: 'CS_ACM360_BETA_SidePanel',
        scrollable: true,
        resizable: true,
        width: 290,
        height: 720,
        min_width: 250,
        min_height: 380,
        style: UI::HtmlDialog::STYLE_UTILITY
      )
      @dialog.set_file(File.join(CS_ACM360_BETA::PLUGIN_DIR, 'ui', 'side_panel.html'))
      dlg = @dialog
      register_callbacks(dlg)
      dlg.set_on_closed do
        if @dialog.equal?(dlg)
          @dialog = nil
          detach
        end
      end
      @dialog.show
      attach(Sketchup.active_model)
    end

    def register_callbacks(dlg)
      # Na primeira vez, encosta na direita da tela; depois o SketchUp lembra a posição
      dlg.add_action_callback('ready') do |_ctx, screen_w|
        if Sketchup.read_default('CS_ACM360_BETA', 'side_panel_placed').nil? && screen_w.to_i > 600
          dlg.set_position(screen_w.to_i - 310, 110)
          Sketchup.write_default('CS_ACM360_BETA', 'side_panel_placed', true)
        end
        refresh
      end

      dlg.add_action_callback('start_tool') do |_ctx, json_str|
        data = JSON.parse(json_str.to_s) rescue {}
        LiveTool.start(data['tool'], data['params'].is_a?(Hash) ? data['params'] : {})
      end

      dlg.add_action_callback('set_params') do |_ctx, json_str|
        data = JSON.parse(json_str.to_s) rescue {}
        LiveTool.remember(data['mode'], data['params']) if data['params'].is_a?(Hash)
      end

      dlg.add_action_callback('apply_selected') do |_ctx, json_str|
        data = JSON.parse(json_str.to_s) rescue {}
        guarded { status(apply_selected(data)) }
      end

      dlg.add_action_callback('action') do |_ctx, name|
        guarded { run_action(name.to_s) }
      end

      dlg.add_action_callback('refresh') { |_ctx| refresh }
    end

    def guarded
      yield
    rescue StandardError => e
      status("Erro: #{e.class}: #{e.message}")
    ensure
      refresh
    end

    ACTIONS = {
      'cut_interferences' => -> { InterferenceKernel.cut_selection },
      'cutouts_auto'      => -> { TrayCutouts.auto_selection },
      'cutouts_contour'   => -> { TrayCutouts.contour_selection },
      'cutouts_clear'     => -> { TrayCutouts.clear_selection },
      'mark_holes'        => -> { TrayCutouts.mark_holes },
      'fix_cantoneira'    => -> { HardwareFasteners.distribute_from_selection('cantoneira') },
      'fix_ancoragem'     => -> { HardwareFasteners.distribute_from_selection('ancoragem') },
      'fix_espera'        => -> { HardwareFasteners.distribute_from_selection('espera') },
      'fix_remove'        => -> { HardwareFasteners.remove_from_selection },
      'ler_acm'           => -> { AcmTrayKernel.create_frame_from_trays; nil },
      'unfold'            => -> { UnfoldDxfEngine.place_unfolded_tray_in_model; nil },
      'dxf'               => -> { UnfoldDxfEngine.export_model_trays_to_dxf; nil },
      'report'            => -> { StudioDialog.show('report'); nil },
      'studio'            => -> { StudioDialog.show('frame'); nil },
      'radial'            => -> { RadialMenu.open; nil }
    }.freeze

    def run_action(name)
      action = ACTIONS[name]
      return status("Ação desconhecida: #{name}") unless action
      msg = action.call
      status(msg) if msg.is_a?(String)
    end

    def selected_group
      model = Sketchup.active_model
      return nil unless model
      model.selection.find { |e| e.is_a?(Sketchup::Group) && KINDS.include?(e.get_attribute(Catalog::ATTR_DICT, 'kind')) }
    end

    # Medidas e travessas da peça selecionada; largura cresce para a direita, altura para cima
    def apply_selected(data)
      grp = selected_group
      return 'Selecione uma estrutura ou bandeja do plugin.' unless grp
      kind = grp.get_attribute(Catalog::ATTR_DICT, 'kind')
      return 'Tubo avulso: use o painel completo para editar.' if kind == 'single_tube'
      box = LiveTool.stretch_box(grp)
      msgs = []
      w, h = data['width_mm'].to_f, data['height_mm'].to_f
      msgs << LiveTool.resize(grp, 'dir', w) if w > 0 && (w - box[:w]).abs > 0.05
      msgs << LiveTool.resize(grp, 'sup', h) if h > 0 && (h - box[:h]).abs > 0.05
      if kind == 'parametric_frame'
        params = JSON.parse(grp.get_attribute(Catalog::ATTR_DICT, 'params_json').to_s)
        changes = {}
        changes['name'] = data['name'].to_s if data['name'] && data['name'].to_s != params['name'].to_s
        %w[trav_v_count trav_h_count].each do |k|
          changes[k] = data[k].to_i if data.key?(k) && data[k].to_i != params[k].to_i
        end
        unless changes.empty?
          params.delete('custom_v_xs_mm') if changes.key?('trav_v_count')
          params.delete('custom_h_zs_mm') if changes.key?('trav_h_count')
          FrameKernel.create_or_update_frame(params.merge(changes), grp)
          msgs << "Travessas: #{params.merge(changes).values_at('trav_v_count', 'trav_h_count').join(' vert. × ')} horiz." if (changes.keys & %w[trav_v_count trav_h_count]).any?
          msgs << 'Nome atualizado' if changes.key?('name')
        end
      elsif kind == 'acm_tray'
        cfg = HardwareFasteners.tray_cfg(grp)
        changes = { 'name' => data['name'], 'code' => data['code'] }.compact.reject { |k, v| cfg[k].to_s == v.to_s }
        unless changes.empty?
          AcmTrayKernel.create_or_update_tray(cfg.merge(changes), grp)
          msgs << 'Nome/código atualizado'
        end
      end
      msgs.empty? ? 'Nada mudou.' : msgs.join(' · ')
    end

    def describe(grp)
      return nil unless grp && grp.valid?
      kind = grp.get_attribute(Catalog::ATTR_DICT, 'kind')
      base = { 'kind' => kind, 'fasteners' => HardwareFasteners.applied_types(grp) }
      case kind
      when 'parametric_frame'
        p = JSON.parse(grp.get_attribute(Catalog::ATTR_DICT, 'params_json').to_s) rescue {}
        tubes = JSON.parse(grp.get_attribute(Catalog::ATTR_DICT, 'tubes_json').to_s) rescue []
        base.merge(p.slice('name', 'width_mm', 'height_mm', 'trav_v_count', 'trav_h_count', 'profile_corda', 'profile_travessa'))
            .merge('tubes' => Array(tubes).size, 'meters' => (Array(tubes).sum { |t| t['length_mm'].to_f } / 1000.0).round(2))
      when 'acm_tray'
        c = HardwareFasteners.tray_cfg(grp)
        base.merge(c.slice('code', 'name', 'width_mm', 'height_mm', 'acm_preset'))
            .merge('cutouts' => Array(c['cutouts']).size, 'quantity' => (c['quantity'] || 1).to_i)
      when 'single_tube'
        t = (JSON.parse(grp.get_attribute(Catalog::ATTR_DICT, 'tubes_json').to_s) rescue []).first || {}
        base.merge(t.slice('name', 'profile_name', 'length_mm', 'cut_a_deg', 'cut_b_deg'))
      end
    end

    def state
      st = Settings.all
      {
        'version'   => CS_ACM360_BETA::PLUGIN_VERSION,
        'profiles'  => Settings.profiles.map { |p| { 'id' => p[:id], 'name' => p[:name] } },
        'presets'   => st['acm_presets'].map { |p| p.slice('id', 'name') },
        'defaults'  => { 'acm_preset' => st['acm_preset'], 'return_mm' => st['default_return_mm'],
                         'aba_mm' => st['default_aba_mm'], 'joint_mm' => st['default_joint_mm'] },
        'params'    => LiveTool.all_params,
        'selection' => describe(selected_group),
        'selected_count' => Sketchup.active_model ? Sketchup.active_model.selection.size : 0
      }
    end

    def refresh
      return unless visible?
      @dialog.execute_script("window.CSSide && CSSide.load(#{JSON.generate(state)});")
    end

    def status(msg)
      return unless visible?
      @dialog.execute_script("window.CSSide && CSSide.status(#{JSON.generate(msg.to_s)});")
    end

    # Atualiza ao mudar a seleção (agrupando vários avisos seguidos)
    def schedule_refresh
      return if @pending || !visible?
      @pending = true
      UI.start_timer(0.15, false) do
        @pending = false
        refresh
      end
    end

    def attach(model)
      detach
      return unless model
      @observed = model.selection
      @observed.add_observer(SelectionWatcher.instance)
    end

    def detach
      @observed.remove_observer(SelectionWatcher.instance) if @observed
    rescue StandardError
      nil
    ensure
      @observed = nil
    end

    def model_changed(model)
      return unless visible?
      attach(model)
      refresh
    end

    class SelectionWatcher < Sketchup::SelectionObserver
      def self.instance
        @instance ||= new
      end

      def onSelectionBulkChange(_sel); SidePanel.schedule_refresh; end
      def onSelectionCleared(_sel); SidePanel.schedule_refresh; end
      def onSelectionAdded(_sel, _e); SidePanel.schedule_refresh; end
      def onSelectionRemoved(_sel, _e); SidePanel.schedule_refresh; end
    end

    class ModelWatcher < Sketchup::AppObserver
      def onNewModel(model); SidePanel.model_changed(model); end
      def onOpenModel(model); SidePanel.model_changed(model); end
      def onActivateModel(model); SidePanel.model_changed(model); end
    end
  end
end
