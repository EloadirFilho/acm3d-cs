# encoding: UTF-8
# ==============================================================================
# CS_ACM360_BETA::RadialMenu  (M1 — menu radial)
# Abre no cursor pelo atalho de teclado que o usuário atribuir em
# Janela > Preferências > Atalhos ("Menu Radial"). Anel de dentro: desenhar;
# anel de fora: ações sobre a seleção. Clique escolhe; Esc ou clique fora fecha.
# ==============================================================================

module CS_ACM360_BETA
  module RadialMenu
    extend self

    R_HOLE  = 38
    R_INNER = 140
    R_OUTER = 215
    SECTORS = 8
    WAIT_S  = 0.25 # sem mexer o mouse, abre no centro da tela

    # [rótulo, dica na barra de status, ação]
    INNER = [
      ['Gradil',     'Gradil por 2 cantos (setas: travessas)',      -> { LiveTool.start('frame') }],
      ['Bandeja',    'Bandeja ACM por 2 cantos',                    -> { LiveTool.start('tray') }],
      ['Fachada',    'Bandejas + estrutura por 2 cantos',           -> { LiveTool.start('facade') }],
      ['Tubo',       'Tubo avulso por 2 pontos, em sequência',      -> { LiveTool.start('tube') }],
      ['Esticar',    'Alças nas bordas da estrutura ou bandeja',    -> { LiveTool.start('stretch') }],
      ['Cantoneira', 'Cantoneira no clique (retorno da bandeja)',   -> { LiveTool.start('fastener', 'type' => 'cantoneira') }],
      ['Ancoragem',  'Ancoragem no clique (tubo da estrutura)',     -> { LiveTool.start('fastener', 'type' => 'ancoragem') }],
      ['Espera',     'Espera / afastador no clique',                -> { LiveTool.start('fastener', 'type' => 'espera') }]
    ].freeze

    OUTER = [
      ['Painel',     'Painel lateral (parâmetros e seleção)',       -> { SidePanel.toggle }],
      ['Ler ACM',    'Estrutura atrás das bandejas selecionadas',   -> { AcmTrayKernel.create_frame_from_trays }],
      ['Cortar',     'Cortar tubos avulsos nas interferências',     -> { RadialMenu.report(InterferenceKernel.cut_selection) }],
      ['Recortes',   'Recortes automáticos nas bandejas',           -> { RadialMenu.report(TrayCutouts.auto_selection) }],
      ['Planificar', 'Planificar a bandeja selecionada no 3D',      -> { UnfoldDxfEngine.place_unfolded_tray_in_model }],
      ['DXF CNC',    'Plano de corte e exportar DXF',               -> { UnfoldDxfEngine.export_model_trays_to_dxf }],
      ['Relatório',  'Relatório de produção e Excel',               -> { StudioDialog.show('report') }],
      ['Completo',   'Painel completo do Construtor',               -> { StudioDialog.show('frame') }]
    ].freeze

    def open
      Sketchup.active_model.select_tool(Tool.new)
    end

    # Mensagem curta na barra de status e no painel lateral; longa (avisos) também em caixa
    def report(msg)
      msg = msg.to_s
      Sketchup.status_text = msg.lines.first.to_s.strip
      SidePanel.status(msg) if SidePanel.visible?
      UI.messagebox(msg) if msg.lines.size > 1 && !SidePanel.visible?
    end

    # Setor sob o ponto: [:inner|:outer, índice], :center ou nil (fora)
    def hit(cx, cy, x, y)
      dx, dy = x - cx, y - cy
      d = Math.hypot(dx, dy)
      return :center if d < R_HOLE
      return nil if d > R_OUTER
      ang = (Math.atan2(dx, -dy) * 180.0 / Math::PI) % 360.0
      idx = ((ang + 180.0 / SECTORS) / (360.0 / SECTORS)).floor % SECTORS
      [d < R_INNER ? :inner : :outer, idx]
    end

    def item(h)
      return nil unless h.is_a?(Array)
      (h[0] == :inner ? INNER : OUTER)[h[1]]
    end

    # Ponto na tela: ângulo em graus a partir do topo, sentido horário
    def polar(cx, cy, r, deg)
      a = deg * Math::PI / 180.0
      Geom::Point3d.new(cx + r * Math.sin(a), cy - r * Math.cos(a), 0)
    end

    class Tool
      FILL   = Sketchup::Color.new(30, 41, 59, 235)
      FILL2  = Sketchup::Color.new(51, 65, 85, 235)
      HOVER  = Sketchup::Color.new(37, 99, 235, 245)
      LINE   = Sketchup::Color.new(148, 163, 184)
      TEXT   = Sketchup::Color.new(248, 250, 252)

      def activate
        @c = nil
        @hover = nil
        Sketchup.status_text = 'Menu CS ACM360: clique numa opção (Esc fecha).'
        @timer = UI.start_timer(RadialMenu::WAIT_S, false) do
          view = Sketchup.active_model.active_view
          @c ||= [view.vpwidth / 2.0, view.vpheight / 2.0]
          view.invalidate
        end
      end

      def deactivate(view)
        UI.stop_timer(@timer) if @timer
        view.invalidate
      end

      def onCancel(_reason, _view)
        close
      end

      def onMouseMove(_flags, x, y, view)
        @c ||= [x.to_f, y.to_f]
        h = RadialMenu.hit(@c[0], @c[1], x, y)
        if h != @hover
          @hover = h
          it = RadialMenu.item(h)
          Sketchup.status_text = it ? it[1] : 'Menu CS ACM360: clique numa opção (Esc fecha).'
          view.invalidate
        end
      end

      def onLButtonDown(_flags, x, y, _view)
        return unless @c
        it = RadialMenu.item(RadialMenu.hit(@c[0], @c[1], x, y))
        close
        it[2].call if it
      rescue StandardError => e
        UI.messagebox("Erro: #{e.class}: #{e.message}")
      end

      def close
        Sketchup.active_model.select_tool(nil)
      end

      def draw(view)
        return unless @c
        cx, cy = @c
        step = 360.0 / RadialMenu::SECTORS
        [[:inner, RadialMenu::R_HOLE, RadialMenu::R_INNER, RadialMenu::INNER, FILL],
         [:outer, RadialMenu::R_INNER + 3, RadialMenu::R_OUTER, RadialMenu::OUTER, FILL2]].each do |ring, r0, r1, items, fill|
          items.each_with_index do |it, i|
            a0 = i * step - step / 2.0 + 1.2
            a1 = i * step + step / 2.0 - 1.2
            outer = (0..10).map { |k| RadialMenu.polar(cx, cy, r1, a0 + (a1 - a0) * k / 10.0) }
            inner = (0..10).map { |k| RadialMenu.polar(cx, cy, r0, a0 + (a1 - a0) * k / 10.0) }
            view.drawing_color = @hover == [ring, i] ? HOVER : fill
            view.draw2d(GL_QUAD_STRIP, outer.zip(inner).flatten)
            view.drawing_color = LINE
            view.line_width = 1
            view.draw2d(GL_LINE_LOOP, outer + inner.reverse)
            view.draw_text(RadialMenu.polar(cx, cy, (r0 + r1) / 2.0, i * step), it[0],
                           size: 11, bold: true, color: TEXT,
                           align: TextAlignCenter, vertical_align: TextVerticalAlignCenter)
          end
        end
        hole = (0..32).map { |k| RadialMenu.polar(cx, cy, RadialMenu::R_HOLE - 4, k * 360.0 / 32) }
        view.drawing_color = @hover == :center ? HOVER : FILL
        view.draw2d(GL_POLYGON, hole)
        view.draw_text(Geom::Point3d.new(cx, cy, 0), 'Esc', size: 10, color: TEXT,
                       align: TextAlignCenter, vertical_align: TextVerticalAlignCenter)
      end
    end
  end
end
