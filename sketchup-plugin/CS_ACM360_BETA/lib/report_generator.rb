# encoding: UTF-8
# ==============================================================================
# CS_ACM360_BETA - Relatório de Produção (report_generator.rb) · Módulo M8
# Os cálculos (lista de corte, plano de barras, XLSX/CSV/impressão) ficam em
# ui/acm360-report.js, o mesmo arquivo usado pelo painel web. Aqui ficam só a
# contagem de fixadores do modelo e a gravação dos arquivos gerados pela tela.
# ==============================================================================

module CS_ACM360_BETA
  module ReportGenerator
    extend self

    FASTENER_NAMES = [
      ['Cantoneira F003', %w[Cantoneira F003]],
      ['Ancoragem F001',  %w[Ancoragem F001]],
      ['Espera F002',     %w[Espera F002]]
    ].freeze

    # Conta os blocos de fixadores em todo o modelo (inclusive dentro de grupos)
    def count_fasteners(model = Sketchup.active_model)
      counter = Hash.new(0)
      walk_fasteners(model.entities, counter) if model
      counter
    end

    # Salva um arquivo gerado pela tela (CSV em texto, XLSX em base64)
    def save_file(payload)
      name = payload['filename'].to_s
      ext  = File.extname(name)
      path = UI.savepanel('Salvar Relatório de Produção', nil, name)
      return nil unless path
      path += ext unless path.downcase.end_with?(ext.downcase)
      if payload['base64']
        File.binwrite(path, payload['base64'].to_s.unpack1('m'))
      else
        File.write(path, "﻿" + payload['text'].to_s, mode: 'w:UTF-8')
      end
      path
    rescue StandardError => e
      UI.messagebox("Não foi possível salvar o relatório: #{e.message}")
      nil
    end

    # Abre o relatório no navegador padrão, que já chama a impressão
    def open_print_view(html)
      path = File.join(Sketchup.temp_dir, 'CS_ACM360_relatorio.html')
      File.write(path, html.to_s, mode: 'w:UTF-8')
      UI.openURL('file:///' + File.expand_path(path).tr('\\', '/'))
    end

    def walk_fasteners(entities, counter)
      entities.each do |e|
        if e.is_a?(Sketchup::Group)
          walk_fasteners(e.entities, counter)
        elsif e.is_a?(Sketchup::ComponentInstance)
          cname = e.definition.name
          label = FASTENER_NAMES.find { |_, keys| keys.any? { |k| cname.include?(k) } }
          counter[label[0]] += 1 if label
        end
      end
    end
  end
end
