# encoding: UTF-8
# ==============================================================================
# Teste de integração do CS ACM360 BETA dentro do SketchUp 2025.
# Rodar com: powershell -File tools/run_sketchup_tests.ps1
# (abre o SketchUp com -RubyStartup, grava results.json em CS_TEST_OUT e fecha)
#
# UI.messagebox / savepanel / openURL são substituídos para não travar a
# automação: mensagens viram log e os arquivos vão para a pasta de saída.
# ==============================================================================

require 'json'

module CSBetaTests
  OUT = (ENV['CS_TEST_OUT'] || File.join(Sketchup.temp_dir, 'cs_acm360_tests')).tr('\\', '/').freeze
  P = CS_ACM360_BETA

  @results = []
  @messages = []
  @save_queue = []
  @opened_urls = []
  @probe = nil

  class << self
    attr_reader :messages, :opened_urls
    attr_accessor :probe

    def check(name, ok, detail = nil)
      @results << { 'name' => name, 'ok' => !!ok, 'detail' => detail }
    end

    def guard(name)
      yield
    rescue Exception => e # rubocop:disable Lint/RescueException
      check(name, false, "#{e.class}: #{e.message}\n#{e.backtrace.first(6).join("\n")}")
    end

    def next_save(default_name)
      @save_queue.shift || File.join(OUT, default_name.to_s.empty? ? 'sem_nome' : default_name.to_s)
    end

    def queue_save(path)
      @save_queue << path
    end

    def stub_ui
      UI.define_singleton_method(:messagebox) { |*a| CSBetaTests.messages << a.first.to_s; 6 } # IDYES
      UI.define_singleton_method(:savepanel) { |_t, _d = nil, name = nil| CSBetaTests.next_save(name) }
      UI.define_singleton_method(:openURL) { |url| CSBetaTests.opened_urls << url; true }
    end

    def fastener_instances(group)
      group.entities.grep(Sketchup::Group)
           .select { |g| g.get_attribute('CS_ACM360_DATA', 'kind') == 'fastener_array' }
           .flat_map { |g| g.entities.grep(Sketchup::ComponentInstance) }
    end

    def tubes_of(payload, frame_name)
      f = payload['frames'].find { |x| x['name'] == frame_name }
      f ? f['tubes'] : []
    end

    def finish
      model = Sketchup.active_model
      File.write(File.join(OUT, 'results.json'), JSON.pretty_generate(
        'version' => P::PLUGIN_VERSION,
        'passed' => @results.count { |r| r['ok'] },
        'failed' => @results.count { |r| !r['ok'] },
        'results' => @results,
        'messages' => @messages,
        'opened_urls' => @opened_urls
      ))
      begin
        model.close(true) if model && model.respond_to?(:close)
      rescue StandardError
        nil
      end
      Sketchup.quit
    end

    # --------------------------------------------------------------------------
    # Fase 1: kernels Ruby (síncrono)
    # --------------------------------------------------------------------------
    def run_kernels
      model = Sketchup.active_model
      check('modelo ativo disponível', !model.nil?)
      return unless model

      guard('configurações de fábrica') do
        P::Settings.reset!
        check('barra padrão 6000', P::Settings.get('bar_mm').to_f == 6000.0, P::Settings.get('bar_mm'))
      end

      frame = nil
      guard('gerar estrutura no 3D') do
        frame = P::FrameKernel.create_or_update_frame('name' => 'Gradil Teste', 'width_mm' => 8000, 'height_mm' => 1500)
        check('gerar estrutura no 3D', frame && frame.valid?, @messages.last)
        payload = P::UnfoldDxfEngine.build_erp_payload
        tubes = tubes_of(payload, 'Gradil Teste')
        inf = tubes.select { |t| t['id'].to_s.start_with?('INF') }.map { |t| t['length_mm'].to_f }
        check('travessa de 7960 dividida em 6000 + 1960', inf.sort == [1960.0, 6000.0], inf)
      end

      guard('mudar barra para 6500 regera as emendas') do
        P::Settings.save(P::Settings.all.merge('bar_mm' => 6500))
        n = P::FrameKernel.regenerate_all_frames
        tubes = tubes_of(P::UnfoldDxfEngine.build_erp_payload, 'Gradil Teste')
        inf = tubes.select { |t| t['id'].to_s.start_with?('INF') }.map { |t| t['length_mm'].to_f }
        check('mudar barra para 6500 regera as emendas', n >= 1 && inf.sort == [1460.0, 6500.0], { 'regeradas' => n, 'inf' => inf })
        P::Settings.reset!
        P::FrameKernel.regenerate_all_frames
      end

      guard('tubo avulso 45°') do
        t = P::FrameKernel.create_single_tube('name' => 'Tubo 45', 'length_mm' => 2000, 'cut_a_deg' => 45, 'cut_b_deg' => 45)
        tb = tubes_of(P::UnfoldDxfEngine.build_erp_payload, 'Tubo 45').first || {}
        faces = t && t.valid? ? t.entities.grep(Sketchup::Group).sum { |g| g.entities.grep(Sketchup::Face).size } : 0
        check('tubo avulso 45°', t && faces >= 6 && tb['cut_a_deg'].to_f == 45.0 && tb['length_mm'].to_f == 2000.0,
              { 'faces' => faces, 'tubo' => tb, 'msg' => @messages.last })
      end

      guard('moldura meia-esquadria com emenda') do
        before = @messages.size
        f = P::FrameKernel.create_or_update_frame('name' => 'Gradil 45', 'width_mm' => 8000, 'height_mm' => 1200, 'corner_type' => 'esquadria')
        tubes = tubes_of(P::UnfoldDxfEngine.build_erp_payload, 'Gradil 45')
        sup = tubes.select { |x| x['id'].to_s.start_with?('SUP') }.map { |x| [x['length_mm'], x['cut_a_deg'], x['cut_b_deg']] }
        empty = f && f.valid? ? f.entities.grep(Sketchup::Group).sum { |g| g.entities.grep(Sketchup::Group).count { |s| s.entities.length.zero? } } : -1
        check('moldura meia-esquadria com emenda', f && f.valid? && @messages.size == before && empty.zero? && sup.size == 2,
              { 'sup' => sup, 'grupos_vazios' => empty, 'msgs' => @messages[before..] })
      end

      tray = nil
      guard('bandeja 1200×800 × 2') do
        tray = P::AcmTrayKernel.create_or_update_tray('name' => 'Bandeja Teste', 'code' => 'T01', 'quantity' => 2,
                                                      'width_mm' => 1200, 'height_mm' => 800)
        tr = P::UnfoldDxfEngine.build_erp_payload['trays'].first || {}
        check('bandeja 1200×800 × 2', tray && tr.dig('tray', 'width_mm').to_f == 1200.0 && tr.dig('unfold', 'front_w_mm').to_f == 1200.0, tr['unfold'] && tr['unfold'].reject { |k, _| k.end_with?('lines') })
      end

      guard('fita VHB usa as medidas reais') do
        v = P::HardwareFasteners.calculate_vhb_tape_requirements
        # 2 × 2(1200+800) = 8,0 m de perímetro; reforços: (floor(1200/400)-1) × 700 × 2 = 2,8 m
        check('fita VHB usa as medidas reais', v[:perimeter_meters] == 8.0 && v[:stiffener_meters] == 2.8, v)
      end

      guard('cantoneiras na bandeja (M4)') do
        hf = P::HardwareFasteners
        cfg = hf.tray_cfg(tray)
        spacing, margin = P::Settings.get('fastener_spacing_mm'), P::Settings.get('fastener_offset_mm')
        expected = %w[inf sup esq dir].sum do |s|
          e = cfg['edges'][s]
          next 0 unless %w[dobra dobra_aba].include?(e['type']) && e['return_mm'].to_f > 2
          hf.positions(%w[inf sup].include?(s) ? 1200.0 : 800.0, spacing, margin).size
        end
        n = hf.distribute([tray], 'cantoneira')
        box = tray.definition.bounds
        tol = 0.5.mm
        inside = fastener_instances(tray).all? do |i|
          b = i.bounds
          b.min.x >= box.min.x - tol && b.min.y >= box.min.y - tol && b.min.z >= box.min.z - tol &&
            b.max.x <= box.max.x + tol && b.max.y <= box.max.y + tol && b.max.z <= box.max.z + tol
        end
        check('cantoneiras na bandeja (M4)', n > 0 && n == expected && inside,
              { 'desenhadas' => n, 'esperado' => expected, 'dentro_da_bandeja' => inside })
      end

      guard('relatório conta fixadores × quantidade da bandeja') do
        c = P::ReportGenerator.count_fasteners
        n = fastener_instances(tray).size
        check('relatório conta fixadores × quantidade da bandeja',
              c['Cantoneira L25x25x2 c40'] == n * 2 && c['Rebite alumínio 4,8×12'] == n * 2 * 2, c)
      end

      guard('ancoragens na estrutura (M4)') do
        hf = P::HardwareFasteners
        tubes = JSON.parse(frame.get_attribute('CS_ACM360_DATA', 'tubes_json'))
        vertical = tubes.select { |t| t['axis'] == 'z' }
        expected = vertical.sum { |t| hf.positions(t['length_mm'].to_f, P::Settings.get('anchor_spacing_mm'), P::Settings.get('anchor_margin_mm')).size }
        n = hf.distribute([frame], 'ancoragem')
        back = vertical.map { |t| t['y_mm'].to_f + t['d_mm'].to_f }.max
        max_y = fastener_instances(frame).map { |i| i.bounds.max.y.to_mm }.max.to_f
        check('ancoragens na estrutura (M4)', n > 0 && n == expected && (max_y - back).abs < 0.5,
              { 'desenhadas' => n, 'esperado' => expected, 'fundo_tubo' => back, 'fundo_fixador' => max_y })
      end

      guard('espera substitui ancoragem e afasta da parede') do
        hf = P::HardwareFasteners
        before = fastener_instances(frame).size
        n = hf.distribute([frame], 'espera')
        tubes = JSON.parse(frame.get_attribute('CS_ACM360_DATA', 'tubes_json'))
        back = tubes.select { |t| t['axis'] == 'z' }.map { |t| t['y_mm'].to_f + t['d_mm'].to_f }.max
        max_y = fastener_instances(frame).map { |i| i.bounds.max.y.to_mm }.max.to_f
        types = fastener_instances(frame).map { |i| i.get_attribute('CS_ACM360_DATA', 'fastener_type') }.uniq
        check('espera substitui ancoragem e afasta da parede',
              n == before && types == ['espera'] && hf.applied_types(frame) == ['espera'] && (max_y - back - 100).abs < 0.5,
              { 'tipos' => types, 'aplicados' => hf.applied_types(frame), 'afastamento' => max_y - back })
      end

      guard('fixadores acompanham a estrutura regerada') do
        before = fastener_instances(frame).size
        P::FrameKernel.regenerate_all_frames
        frame = model.entities.grep(Sketchup::Group).find { |g| g.name == 'Gradil Teste' } || frame
        after = frame.valid? ? fastener_instances(frame).size : -1
        check('fixadores acompanham a estrutura regerada', before > 0 && after == before, { 'antes' => before, 'depois' => after })
      end

      guard('remover fixadores') do
        P::HardwareFasteners.remove([frame])
        check('remover fixadores', fastener_instances(frame).empty? && P::HardwareFasteners.applied_types(frame).empty?)
      end

      guard('fachada 3×2 com estrutura dentro de um grupo') do
        before = model.entities.to_a
        P::AcmTrayKernel.create_facade_grid('cols' => 3, 'rows' => 2, 'total_w_mm' => 3600, 'total_h_mm' => 1800, 'generate_frame' => true)
        created = model.entities.to_a - before
        wrapper = model.entities.add_group(created)
        wrapper.name = 'Fachada agrupada pelo usuário'
        payload = P::UnfoldDxfEngine.build_erp_payload
        check('fachada 3×2 com estrutura dentro de um grupo', payload['trays'].size == 7 && payload['frames'].size == 4,
              { 'bandejas' => payload['trays'].size, 'estruturas' => payload['frames'].map { |f| f['name'] }, 'criados' => created.size })
      end

      guard('exportar DXF com bandejas agrupadas') do
        path = File.join(OUT, 'teste.dxf')
        queue_save(path)
        P::UnfoldDxfEngine.export_model_trays_to_dxf
        files = Dir[File.join(OUT, 'teste*.dxf')].sort
        txt = files.map { |f| File.read(f) }.join
        # Etiqueta "CÓDIGO Nome" de cada peça: T01 tem quantidade 2 (T01-1, T01-2), P01..P06 uma vez
        labels = txt.scan(/^(T01-\d|P0[1-6]) Bandeja/).flatten
        check('exportar DXF: todas as bandejas, uma chapa por arquivo',
              files.size >= 2 && files.all? { |f| File.read(f).include?('AC1009') } && labels.uniq.size == 8,
              { 'arquivos' => files.map { |f| File.basename(f) }, 'etiquetas' => labels.tally, 'msg' => @messages.last })
      end

      guard('publicar JSON do ERP') do
        path = File.join(OUT, 'teste_erp.json')
        queue_save(path)
        P::UnfoldDxfEngine.export_erp_json_dialog
        data = File.exist?(path) ? JSON.parse(File.read(path, mode: 'r:UTF-8')) : {}
        check('publicar JSON do ERP', data['schema'] == 'CS_ACM360_ERP_V1' && data['trays'].to_a.size == 7, data.keys)
      end

      guard('salvar arquivos do relatório (Ruby)') do
        csv = File.join(OUT, 'ruby.csv')
        queue_save(csv)
        P::ReportGenerator.save_file('filename' => 'x.csv', 'text' => 'Perfil;Ação')
        xlsx = File.join(OUT, 'ruby.xlsx')
        queue_save(xlsx)
        P::ReportGenerator.save_file('filename' => 'x.xlsx', 'base64' => ['PK teste'].pack('m0'))
        ok = File.exist?(csv) && File.read(csv, mode: 'rb').start_with?("\xEF\xBB\xBF".b) && File.binread(xlsx) == 'PK teste'
        check('salvar arquivos do relatório (Ruby)', ok)
      end

      run_interference(model)
      run_cutouts(model)
      run_live(model)
    end

    # --------------------------------------------------------------------------
    # M1: Construtor ao Vivo (x >= 50 m)
    # --------------------------------------------------------------------------
    def pt(x, y, z)
      Geom::Point3d.new(x.mm, y.mm, z.mm)
    end

    def bounds_mm(ents)
      bb = Geom::BoundingBox.new
      Array(ents).each { |e| bb.add(e.bounds) }
      [bb.min.to_a.map(&:to_mm), bb.max.to_a.map(&:to_mm)]
    end

    def near(a, b, tol = 0.5)
      (a - b).abs <= tol
    end

    def run_live(model)
      lt = P::LiveTool
      frame = nil
      tray = nil
      guard('M1: eixos do plano de desenho') do
        u, w, v = lt.drawing_axes(Geom::Vector3d.new(1, 0, 0)) # parede voltada para +X
        du, dw, dv = lt.drawing_axes(nil)
        ok = u.samedirection?(Y_AXIS) && w.samedirection?(X_AXIS.reverse) && v.samedirection?(Z_AXIS) &&
             du.samedirection?(X_AXIS) && dw.samedirection?(Y_AXIS) && dv.samedirection?(Z_AXIS)
        check('M1: eixos do plano de desenho', ok, [u, w, v].map(&:to_a))
      end

      guard('M1: gradil por 2 cantos no plano frontal') do
        axes = lt.drawing_axes(nil)
        origin, w, h = lt.rect_from(pt(53_000, 0, 1500), pt(50_000, 0, 0), axes) # cantos em qualquer ordem
        created = lt.create_rect('frame', { 'name' => 'M1 Gradil' }, origin, w, h, axes)
        frame = created.first
        mn, mx = bounds_mm(created)
        check('M1: gradil por 2 cantos no plano frontal', created.size == 1 && near(mn[0], 50_000) && near(mx[0], 53_000) &&
              near(mn[2], 0) && near(mx[2], 1500) && near(mn[1], 0), { 'min' => mn, 'max' => mx })
      end

      guard('M1: na parede, o fundo encosta nela') do
        axes = lt.drawing_axes(Geom::Vector3d.new(0, -1, 0))
        origin, w, h = lt.rect_from(pt(50_000, 5000, 2000), pt(52_000, 5000, 3000), axes)
        c1 = lt.create_rect('frame', { 'name' => 'M1 Gradil Parede' }, origin, w, h, axes, on_face: true)
        _mn1, mx1 = bounds_mm(c1)
        axes2 = lt.drawing_axes(Geom::Vector3d.new(1, 0, 0))
        o2, w2, h2 = lt.rect_from(pt(70_000, 0, 0), pt(70_000, 2000, 1000), axes2)
        c2 = lt.create_rect('tray', { 'name' => 'M1 Bandeja Parede', 'code' => 'M1T' }, o2, w2, h2, axes2, on_face: true)
        tray = c2.first
        mn2, mx2 = bounds_mm(c2)
        check('M1: na parede, o fundo encosta nela', near(mx1[1], 5000) && near(mn2[0], 70_000) && mx2[0] > 70_040 &&
              near(mn2[1], 0) && near(mx2[1], 2000) && near(mx2[2], 1000),
              { 'gradil_fundo_y' => mx1[1], 'bandeja' => [mn2, mx2] })
      end

      guard('M1: fachada por 2 cantos') do
        axes = lt.drawing_axes(nil)
        origin, w, h = lt.rect_from(pt(80_000, 0, 0), pt(83_000, 0, 1200), axes)
        created = lt.create_rect('facade', { 'cols' => 2, 'rows' => 1 }, origin, w, h, axes)
        kinds = created.map { |e| e.get_attribute('CS_ACM360_DATA', 'kind') }.tally
        mn, mx = bounds_mm(created)
        check('M1: fachada por 2 cantos', kinds['acm_tray'] == 2 && kinds['parametric_frame'] == 1 && near(mn[0], 80_000) && mn[1] > -0.5,
              { 'tipos' => kinds, 'min' => mn, 'max' => mx })
      end

      guard('M1: tubo por 2 pontos, já cortado no vizinho') do
        v, _ = lt.create_tube({ 'name' => 'M1 Tubo V' }, pt(90_000, 0, 0), pt(90_000, 0, 2000), cut: false)
        h, msg = lt.create_tube({ 'name' => 'M1 Tubo H' }, pt(90_000, 0, 500), pt(90_600, 0, 500))
        vmn, vmx = bounds_mm(v)
        hd = tube_data(h)
        check('M1: tubo por 2 pontos, já cortado no vizinho',
              near(vmn[0], 89_990) && near(vmx[0], 90_010) && near(vmn[1], -20) && near(vmx[2], 2000) &&
              near(hd['length_mm'], 590, 0.2) && msg.to_s.include?('1 aparada'),
              { 'vertical' => [vmn, vmx], 'horizontal' => hd['length_mm'], 'msg' => msg })
      end

      guard('M1: esticar pelas alças') do
        r1 = lt.resize(frame, 'dir', 3500)
        mn, mx = bounds_mm(frame)
        r2 = lt.resize(frame, 'esq', 4000)
        mn2, mx2 = bounds_mm(frame)
        r3 = lt.resize(tray, 'sup', 1500)
        _tmn, tmx = bounds_mm(tray)
        small = lt.resize(frame, 'sup', 50)
        check('M1: esticar pelas alças', near(mx[0], 53_500) && near(mn[0], 50_000) && near(mn2[0], 49_500) && near(mx2[0], 53_500) &&
              near(tmx[2], 1500) && small.include?('mínima'),
              { 'dir' => [mn[0], mx[0], r1], 'esq' => [mn2[0], mx2[0], r2], 'bandeja_sup' => [tmx[2], r3], 'min' => small })
      end

      guard('M1: fixador no clique') do
        # ponto perto da lateral esquerda (C1) a 700 mm de altura, coordenadas da estrutura
        a = lt.add_fastener(frame, 'ancoragem', [5, 20, 700])
        c = lt.add_fastener(tray, 'cantoneira', [300, 30, 2])
        n_frame = fastener_instances(frame).size
        lt.resize(frame, 'sup', 1800) # regerar mantém o fixador do clique
        kept = fastener_instances(frame).size
        check('M1: fixador no clique', a && a[:ref].start_with?('C1') && near(a[:pos_mm], 700, 0.1) && c && c[:ref] == 'inf' &&
              near(c[:pos_mm], 300, 0.1) && n_frame == 1 && kept == 1 && fastener_instances(tray).size == 1,
              { 'ancoragem' => a, 'cantoneira' => c, 'antes' => n_frame, 'depois' => kept })
      end

      guard('M1: ferramenta com cliques na tela') do
        view = model.active_view
        view.camera = Sketchup::Camera.new(pt(101_500, -20_000, 8000), pt(101_500, 0, 700), Z_AXIS)
        tool = P::LiveTool::RectTool.new('frame', { 'name' => 'M1 Cliques' })
        model.select_tool(tool)
        sc = ->(p) { s = view.screen_coords(p); [s.x.round, s.y.round] }
        before = model.entities.to_a
        x1, y1 = sc.call(pt(100_000, 0, 0))
        tool.onMouseMove(0, x1, y1, view)
        tool.onLButtonDown(0, x1, y1, view)
        x2, y2 = sc.call(pt(103_000, 0, 1500))
        tool.onMouseMove(0, x2, y2, view)
        tool.onLButtonDown(0, x2, y2, view)
        by_click = model.entities.to_a - before
        cmn, cmx = bounds_mm(by_click)
        # mesma ferramenta, medida digitada depois do primeiro clique
        before = model.entities.to_a
        x3, y3 = sc.call(pt(100_000, 0, 2500))
        tool.onMouseMove(0, x3, y3, view)
        tool.onLButtonDown(0, x3, y3, view)
        x4, y4 = sc.call(pt(101_000, 0, 3000))
        tool.onMouseMove(0, x4, y4, view)
        tool.onUserText('2500;1200', view)
        typed = model.entities.to_a - before
        params = typed.first && JSON.parse(typed.first.get_attribute('CS_ACM360_DATA', 'params_json'))
        model.select_tool(nil)
        check('M1: ferramenta com cliques na tela',
              by_click.size == 1 && (cmx[0] - cmn[0] - 3000).abs < 60 && (cmx[2] - cmn[2] - 1500).abs < 60 &&
              params && near(params['width_mm'], 2500, 0.1) && near(params['height_mm'], 1200, 0.1),
              { 'clique' => [cmn, cmx], 'digitado' => params && params.values_at('width_mm', 'height_mm') })
      end
    end

    # --------------------------------------------------------------------------
    # M5: corte nas interferências (longe das outras peças, em x = 30 m)
    # --------------------------------------------------------------------------
    def place_tube(name, len, tr)
      g = P::FrameKernel.create_single_tube('name' => name, 'length_mm' => len, 'profile_id' => 5)
      g.transform!(tr)
      g
    end

    def tube_data(g)
      JSON.parse(g.get_attribute('CS_ACM360_DATA', 'tubes_json')).first
    end

    def at(x, y, z)
      Geom::Transformation.translation(Geom::Vector3d.new(x.mm, y.mm, z.mm))
    end

    def rot(axis, deg)
      Geom::Transformation.rotation(ORIGIN, axis, deg.degrees)
    end

    # Tubo vertical (eixo local X -> Z do modelo; ocupa x de tx-20 a tx)
    def vertical(name, len, tx, ty, tz)
      place_tube(name, len, at(tx, ty, tz) * rot(Y_AXIS, -90))
    end

    def run_interference(model)
      x0 = 30_000
      targets = {}
      guard('M5: montar casos') do
        # L a 90°: ponta B entra 10 mm no vizinho (x 1990..2010)
        targets[:l90] = place_tube('M5 L90', 2000, at(x0, 0, 0))
        vertical('M5 obst L90', 1000, x0 + 2010, 0, -500)
        # Tubo a 30° da horizontal (60° com o vertical) atravessando a face do vizinho
        targets[:a30] = place_tube('M5 A30', 2000, at(x0, 1000, 0) * rot(Y_AXIS, -30))
        vertical('M5 obst A30', 3000, x0 + 1730, 1000, -1000)
        # Vão de 30 mm: estende; vão de 100 mm: fica como está
        targets[:gap30] = place_tube('M5 vao30', 1000, at(x0, 2000, 0))
        vertical('M5 obst vao30', 1000, x0 + 1050, 2000, -500)
        targets[:gap100] = place_tube('M5 vao100', 1000, at(x0, 3000, 0))
        vertical('M5 obst vao100', 1000, x0 + 1120, 3000, -500)
        # Girado em planta e em elevação: pediria corte composto
        targets[:comp] = place_tube('M5 composto', 1420, at(x0, 4000, 0) * rot(Z_AXIS, 30) * rot(Y_AXIS, -20))
        vertical('M5 obst composto', 3000, x0 + 1150, 4655, -1000)
        model.selection.clear
        model.selection.add(targets.values)
      end

      guard('M5: cortar nas interferências') do
        msg = P::InterferenceKernel.cut_selection(model)
        l90, a30 = tube_data(targets[:l90]), tube_data(targets[:a30])
        g30, g100, comp = tube_data(targets[:gap30]), tube_data(targets[:gap100]), tube_data(targets[:comp])
        faces = targets[:l90].entities.grep(Sketchup::Group).sum { |g| g.entities.grep(Sketchup::Face).size }
        check('M5: L a 90° vira encaixe reto', (l90['length_mm'] - 1990).abs < 0.2 && l90['cut_b_deg'].to_f.zero? && faces == 6,
              { 'tubo' => l90.slice('length_mm', 'cut_a_deg', 'cut_b_deg', 'ends'), 'faces' => faces })
        # Face do vizinho em x = 1710; a ponta longa (canto de cima, 10 mm atrás) chega em 1720 / cos 30° = 1986,1
        check('M5: 60° entre tubos vira corte de 30°', (a30['cut_b_deg'].to_f - 30).abs < 0.2 && (a30['length_mm'] - 1986.1).abs < 0.3 &&
              a30.dig('ends', 'b', 'axis') == 'z',
              a30.slice('length_mm', 'cut_b_deg', 'ends'))
        check('M5: vão de 30 mm estende, de 100 mm não', (g30['length_mm'] - 1030).abs < 0.2 && (g100['length_mm'] - 1000).abs < 0.01,
              { 'vao30' => g30['length_mm'], 'vao100' => g100['length_mm'] })
        check('M5: corte composto fica como está, com aviso', (comp['length_mm'] - 1420).abs < 0.01 && msg.include?('corte composto'),
              { 'tubo' => comp['length_mm'], 'msg' => msg })
        check('M5: nenhuma ponta passa de 75°', targets.values.all? { |g| d = tube_data(g); d['cut_a_deg'].to_f <= 75 && d['cut_b_deg'].to_f <= 75 }, msg)
      end

      guard('M5: relatório usa o comprimento aparado') do
        tb = tubes_of(P::UnfoldDxfEngine.build_erp_payload, 'M5 L90').first || {}
        check('M5: relatório usa o comprimento aparado', (tb['length_mm'].to_f - 1990).abs < 0.2, tb.slice('length_mm', 'cut_b_deg'))
      end
    end

    # --------------------------------------------------------------------------
    # M6: recortes nas bandejas (em x = 40 m)
    # --------------------------------------------------------------------------
    def box_group(model, x, y, z, dx, dy, dz)
      g = model.entities.add_group
      f = g.entities.add_face([[x, y, z], [x + dx, y, z], [x + dx, y + dy, z], [x, y + dy, z]].map { |p| Geom::Point3d.new(p.map(&:mm)) })
      f.reverse! if f.normal.z < 0
      f.pushpull(dz.mm)
      g
    end

    def front_loops(tray)
      front = tray.entities.grep(Sketchup::Group).find { |g| g.name == 'Face Frontal ACM' }
      front ? front.entities.grep(Sketchup::Face).map { |f| f.loops.size }.max : 0
    end

    def run_cutouts(model)
      tc = P::TrayCutouts
      x0 = 40_000
      tray = nil
      base_lines = 0
      guard('M6: montar bandeja e interferências') do
        tray = P::AcmTrayKernel.create_or_update_tray('name' => 'Bandeja Recorte', 'code' => 'R01', 'width_mm' => 1000,
                                                      'height_mm' => 600, 'origin_x_mm' => x0)
        base_lines = JSON.parse(tray.get_attribute('CS_ACM360_DATA', 'unfold_json'))['cut_lines'].size
        # Tubo atravessando a face (eixo ao longo de Y): x 460..500, z 300..320
        place_tube('M6 tubo passante', 300, at(x0 + 500, -100, 300) * rot(Z_AXIS, 90))
        # Objeto marcado como furo perto da borda esquerda (com dobra): x 10..60, z 100..200
        furo = box_group(model, x0 + 10, -50, 100, 50, 100, 100)
        model.selection.clear
        model.selection.add(furo)
        tc.mark_holes(model)
      end

      guard('M6: recortes automáticos') do
        model.selection.clear
        model.selection.add(tray)
        msg = tc.auto_selection(model)
        cfg = P::HardwareFasteners.tray_cfg(tray)
        rects = cfg['cutouts'].map { |c| c['pts'] }
        tube_rect = [[455.0, 295.0], [505.0, 295.0], [505.0, 325.0], [455.0, 325.0]]
        furo_rect = [[5.0, 95.0], [65.0, 95.0], [65.0, 205.0], [5.0, 205.0]]
        check('M6: tubo e furo viram recorte com folga de 5 mm', rects.size == 2 && rects.include?(tube_rect) && rects.include?(furo_rect),
              { 'recortes' => rects, 'msg' => msg })
        check('M6: recorte perto da dobra gera aviso', msg.include?('Perto da dobra') && msg.include?('5,0 mm da dobra (esq)'), msg)
        unfold = JSON.parse(tray.get_attribute('CS_ACM360_DATA', 'unfold_json'))
        k = cfg['bend_factor_mm'].to_f
        fx0 = cfg.dig('edges', 'esq', 'return_mm').to_f - k
        fy0 = cfg.dig('edges', 'inf', 'return_mm').to_f - k
        corner = unfold['cut_lines'].any? { |l| (l['x1'] - (fx0 + 455)).abs < 0.01 && (l['y1'] - (fy0 + 295)).abs < 0.01 }
        check('M6: recorte na planificação na posição certa', unfold['cut_lines'].size == base_lines + 8 && corner,
              { 'linhas' => unfold['cut_lines'].size, 'base' => base_lines, 'fx0' => fx0, 'fy0' => fy0 })
        check('M6: furo aberto na face 3D', front_loops(tray) == 3, front_loops(tray))
      end

      guard('M6: recorte pelo contorno') do
        # Círculo de 100 mm desenhado 1 mm à frente da face, centro em x 800, z 400
        circle = model.entities.add_group
        edges = circle.entities.add_circle(Geom::Point3d.new((x0 + 800).mm, -1.mm, 400.mm), Y_AXIS, 50.mm, 24)
        circle.entities.add_face(edges)
        model.selection.clear
        model.selection.add([tray, circle])
        msg = tc.contour_selection(model)
        cfg = P::HardwareFasteners.tray_cfg(tray)
        c = cfg['cutouts'].find { |x| x['source'] == 'contorno' }
        inside = c && c['pts'].all? { |u, v| Math.hypot(u - 800, v - 400).between?(49.0, 50.01) }
        check('M6: contorno vira recorte com o mesmo desenho', c && c['pts'].size == 24 && inside && front_loops(tray) == 4,
              { 'msg' => msg, 'pontos' => c && c['pts'].size, 'laços' => front_loops(tray) })
      end

      guard('M6: vista do verso espelha a chapa') do
        u = JSON.parse(tray.get_attribute('CS_ACM360_DATA', 'unfold_json'))
        P::Settings.save(P::Settings.all.merge('flat_view' => 'verso'))
        v = P::UnfoldDxfEngine.view_unfold(u)
        P::Settings.reset!
        same = P::UnfoldDxfEngine.view_unfold(u)['cut_lines'] == u['cut_lines']
        ok = v['cut_lines'].zip(u['cut_lines']).all? { |a, b| (a['x1'] - (u['width'] - b['x1'])).abs < 0.01 }
        check('M6: vista do verso espelha a chapa', ok && same && v['cut_lines'] != u['cut_lines'])
      end

      guard('M6: editar a bandeja mantém os recortes') do
        cfg = P::HardwareFasteners.tray_cfg(tray)
        P::AcmTrayKernel.create_or_update_tray(cfg.reject { |k2, _| k2 == 'cutouts' }, tray)
        n = P::HardwareFasteners.tray_cfg(tray)['cutouts'].size
        model.selection.clear
        model.selection.add(tray)
        tc.clear_selection(model)
        lines = JSON.parse(tray.get_attribute('CS_ACM360_DATA', 'unfold_json'))['cut_lines'].size
        check('M6: editar mantém e limpar remove os recortes', n == 3 && lines == base_lines && front_loops(tray) == 1,
              { 'apos_editar' => n, 'linhas_apos_limpar' => lines })
      end
    end

    # --------------------------------------------------------------------------
    # Fase 2: painel HtmlDialog (assíncrono) — clica nos botões via JavaScript
    # --------------------------------------------------------------------------
    def run_dialog
      P::StudioDialog.show('report')
      dlg = P::StudioDialog.instance_variable_get(:@dialog)
      dlg.add_action_callback('test_probe') { |_c, json| CSBetaTests.probe = (JSON.parse(json) rescue { 'raw' => json }) }

      UI.start_timer(5, false) do
        guard('painel: exportar Excel/CSV/Imprimir') do
          queue_save(File.join(OUT, 'painel.xlsx'))
          queue_save(File.join(OUT, 'painel.csv'))
          dlg.execute_script("CSStudio.exportReport('xlsx'); CSStudio.exportReport('csv'); CSStudio.printReport();")
        end
        UI.start_timer(4, false) do
          dlg.execute_script(<<~JS)
            sketchup.test_probe(JSON.stringify({
              badge: document.getElementById('versionBadge').textContent,
              status: document.getElementById('statusText').textContent,
              summary: document.getElementById('reportSummaryText').textContent,
              hasReport: typeof AcmReport,
              cutRows: document.querySelectorAll('#reportCutBody tr').length
            }));
          JS
          UI.start_timer(3, false) { check_dialog }
        end
      end
    end

    def check_dialog
      pr = @probe || {}
      check('painel: selo mostra a versão', pr['badge'] == "v#{P::PLUGIN_VERSION}", pr)
      check('painel: relatório calculado', pr['hasReport'] == 'object' && pr['cutRows'].to_i > 1, pr['summary'])
      xlsx = File.join(OUT, 'painel.xlsx')
      csv = File.join(OUT, 'painel.csv')
      check('painel: Excel salvo', File.exist?(xlsx) && File.binread(xlsx, 2) == 'PK', File.exist?(xlsx) ? File.size(xlsx) : 'não criado')
      check('painel: CSV salvo', File.exist?(csv) && File.read(csv, mode: 'r:BOM|UTF-8').include?('LISTA DE CORTE'), File.exist?(csv) ? File.size(csv) : 'não criado')
      html = File.join(Sketchup.temp_dir, 'CS_ACM360_relatorio.html')
      check('painel: impressão abre no navegador', @opened_urls.any? { |u| u.include?('CS_ACM360_relatorio.html') } && File.exist?(html), @opened_urls)
    rescue Exception => e # rubocop:disable Lint/RescueException
      check('painel', false, "#{e.class}: #{e.message}")
    ensure
      finish
    end

    def start
      Dir.mkdir(OUT) unless Dir.exist?(OUT)
      stub_ui
      run_kernels
      run_dialog
    rescue Exception => e # rubocop:disable Lint/RescueException
      check('execução', false, "#{e.class}: #{e.message}\n#{e.backtrace.first(6).join("\n")}")
      finish
    end
  end
end

# Espera o SketchUp terminar de abrir antes de começar
UI.start_timer(3, false) { CSBetaTests.start }
