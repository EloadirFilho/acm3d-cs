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

    # Blocos antigos (pasta BLOCOS, inseridos à mão em modelos de versões anteriores)
    LEGACY_FASTENER_NAMES = [
      ['Cantoneira F003', %w[Cantoneira F003]],
      ['Ancoragem F001',  %w[Ancoragem F001]],
      ['Espera F002',     %w[Espera F002]]
    ].freeze

    # Conta os fixadores em todo o modelo (inclusive dentro de grupos): cada peça
    # pela medida e, somados, os parafusos/buchas/rebites que ela consome (M4).
    def count_fasteners(model = Sketchup.active_model)
      pieces = Hash.new(0)
      items  = Hash.new(0)
      walk_fasteners(model.entities, pieces, items) if model
      pieces.merge(items)
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

    # mult: bandeja com quantidade N é um grupo só no 3D, mas leva N vezes os fixadores
    def walk_fasteners(entities, pieces, items, mult = 1)
      entities.each do |e|
        if e.is_a?(Sketchup::Group)
          m = mult
          if e.get_attribute(Catalog::ATTR_DICT, 'kind') == 'acm_tray'
            m *= [HardwareFasteners.tray_cfg(e)['quantity'].to_i, 1].max
          end
          walk_fasteners(e.entities, pieces, items, m)
        elsif e.is_a?(Sketchup::ComponentInstance)
          label = e.get_attribute(Catalog::ATTR_DICT, 'fastener_label')
          if label && e.get_attribute(Catalog::ATTR_DICT, 'kind') == 'fastener'
            pieces[label.to_s] += mult
            list = JSON.parse(e.get_attribute(Catalog::ATTR_DICT, 'consumption_json').to_s) rescue []
            Array(list).each { |i| items[i['name'].to_s] += i['qty'].to_i * mult if i.is_a?(Hash) }
          else
            cname = e.definition.name
            legacy = LEGACY_FASTENER_NAMES.find { |_, keys| keys.any? { |k| cname.include?(k) } }
            pieces[legacy[0]] += 1 if legacy
          end
        end
      end
    end
  end
end
