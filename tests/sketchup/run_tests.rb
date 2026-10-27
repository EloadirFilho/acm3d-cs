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
