# encoding: UTF-8
# ==============================================================================
# CS_ACM360 - Plugin de Estruturas Metálicas, Bandejas ACM, Planificação e DXF
# Baseado na arquitetura de referência ACM360 e integrado ao CS Fachadas ERP
# Para instalar no SketchUp: Janela > Gerenciador de Extensões > Instalar Extensão
# ==============================================================================

require 'sketchup.rb'
require 'extensions.rb'

module CS_ACM360
  PLUGIN_ID          = 'CS_ACM360'.freeze
  PLUGIN_NAME        = 'CS ACM360 · Estruturas & Bandejas ACM'.freeze
  PLUGIN_VERSION     = '1.0.0'.freeze
  PLUGIN_DESCRIPTION = 'Estruturas metálicas (Gradil/Metalon/Alumínio), Bandejas de ACM, Leitura Automática ACM → Estrutura, Planificação 2D/3D, Exportação DXF CNC e Publicação para o CS Fachadas ERP.'.freeze
  PLUGIN_AUTHOR      = 'CS Comunicação / CS Fachadas ERP'.freeze
  PLUGIN_COPYRIGHT   = '© 2026 CS Comunicação'.freeze
  PLUGIN_ROOT        = File.dirname(__FILE__).freeze
  PLUGIN_DIR         = File.join(PLUGIN_ROOT, 'CS_ACM360').freeze

  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new(PLUGIN_NAME, File.join(PLUGIN_DIR, 'main'))
    ext.version     = PLUGIN_VERSION
    ext.description = PLUGIN_DESCRIPTION
    ext.creator     = PLUGIN_AUTHOR
    ext.copyright   = PLUGIN_COPYRIGHT
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
