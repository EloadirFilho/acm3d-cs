# encoding: UTF-8
# ==============================================================================
# Teste do plugin ORIGINAL corrigido (CS_ACM360_v1.0.x.rbz) dentro do SketchUp 2025.
# Rodar com: powershell -File tools/run_sketchup_tests.ps1 -Original CS_ACM360_v1.0.2.rbz
# ==============================================================================

require 'json'

module CSOriginalTests
  OUT = (ENV['CS_TEST_OUT'] || File.join(Sketchup.temp_dir, 'cs_acm360_tests')).tr('\\', '/').freeze
  P = CS_ACM360

  @results = []
  @messages = []
  @save_queue = []

  class << self
    attr_reader :messages

    def check(name, ok, detail = nil)
      @results << { 'name' => name, 'ok' => !!ok, 'detail' => detail }
    end

    def guard(name)
      yield
    rescue Exception => e # rubocop:disable Lint/RescueException
      check(name, false, "#{e.class}: #{e.message}\n#{e.backtrace.first(6).join("\n")}")
    end

    def next_save(name)
      @save_queue.shift || File.join(OUT, name.to_s)
    end

    def run
      UI.define_singleton_method(:messagebox) { |*a| CSOriginalTests.messages << a.first.to_s; 6 }
      UI.define_singleton_method(:savepanel) { |_t, _d = nil, name = nil| CSOriginalTests.next_save(name) }
      model = Sketchup.active_model

      guard('gerar estrutura no 3D') do
        f = P::FrameKernel.create_or_update_frame('name' => 'Gradil', 'width_mm' => 8000, 'height_mm' => 1500)
        check('gerar estrutura no 3D', f && f.valid?, @messages.last)
      end

      guard('tubo avulso 45°') do
        t = P::FrameKernel.create_single_tube('name' => 'Tubo 45', 'length_mm' => 2000, 'cut_a_deg' => 45, 'cut_b_deg' => 45)
        check('tubo avulso 45°', t && t.valid?, @messages.last)
      end

      guard('moldura meia-esquadria com emenda') do
        before = @messages.size
        f = P::FrameKernel.create_or_update_frame('name' => 'Gradil 45', 'width_mm' => 8000, 'height_mm' => 1200, 'corner_type' => 'esquadria')
        check('moldura meia-esquadria com emenda', f && f.valid? && @messages.size == before, @messages[before..])
      end

      guard('DXF: fachada agrupada em várias chapas') do
        before = model.entities.to_a
        P::AcmTrayKernel.create_facade_grid('cols' => 4, 'rows' => 2, 'total_w_mm' => 4800, 'total_h_mm' => 1800, 'generate_frame' => true)
        model.entities.add_group(model.entities.to_a - before)
        @save_queue << File.join(OUT, 'orig.dxf')
        P::UnfoldDxfEngine.export_model_trays_to_dxf
        files = Dir[File.join(OUT, 'orig*.dxf')].sort
        labels = files.map { |f| File.read(f) }.join.scan(/^(P0[1-8]) Bandeja/).flatten
        check('DXF: fachada agrupada em várias chapas', files.size >= 2 && labels.uniq.size == 8,
              { 'arquivos' => files.map { |f| File.basename(f) }, 'etiquetas' => labels, 'msg' => @messages.last })
      end

      guard('ERP: fachada agrupada') do
        payload = P::UnfoldDxfEngine.build_erp_payload
        check('ERP: fachada agrupada', payload['trays'].size == 8 && payload['frames'].size == 4,
              { 'bandejas' => payload['trays'].size, 'estruturas' => payload['frames'].map { |f| f['name'] } })
      end
    ensure
      File.write(File.join(OUT, 'results.json'), JSON.pretty_generate(
        'version' => P::PLUGIN_VERSION,
        'passed' => @results.count { |r| r['ok'] },
        'failed' => @results.count { |r| !r['ok'] },
        'results' => @results,
        'messages' => @messages
      ))
      model.close(true) rescue nil
      Sketchup.quit
    end
  end
end

UI.start_timer(3, false) { CSOriginalTests.run }
