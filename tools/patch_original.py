"""Gera versões corrigidas do plugin ORIGINAL a partir do CS_ACM360_v1.0.0.rbz.

Uso: python tools/patch_original.py [versão]   (padrão: a mais recente)
O CS_ACM360_v1.0.0.rbz não é alterado. Módulo, menus e pastas continuam os do
original, então instalar a versão nova atualiza o plugin de produção no lugar.
Cada versão inclui as correções das anteriores. Só entram correções pontuais,
nada das funções novas do BETA.
"""
import pathlib
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / 'CS_ACM360_v1.0.0.rbz'

FRAME = 'CS_ACM360/lib/frame_kernel.rb'
UNFOLD = 'CS_ACM360/lib/unfold_dxf_engine.rb'

RELEASES = [
    ('1.0.1', {
        # Sketchup::Entities não tem empty? -> "Gerar Estrutura no 3D" falhava.
        FRAME: [
            ('g.erase! if g.valid? && g.entities.empty?', 'g.erase! if g.valid? && g.entities.length.zero?'),
        ],
    }),
    ('1.0.2', {
        # Tubo avulso com corte inclinado não era desenhado (grupo vazio -> erro ao criar)
        FRAME: [
            ("      if tube[:cut_a_deg].to_f == 45.0 && tube[:cut_b_deg].to_f == 45.0 && tube[:group_role] == 'quadro'\n",
             "      pts_front = nil\n"
             "      if tube[:cut_a_deg].to_f == 45.0 && tube[:cut_b_deg].to_f == 45.0 && tube[:group_role] == 'quadro'\n"),
            ("                    end\n"
             "        if pts_front\n"
             "          face = grp.entities.add_face(pts_front)\n"
             "          if face\n"
             "            face.reverse! if face.normal.y < 0\n"
             "            face.pushpull(d)\n"
             "          end\n"
             "        end\n"
             "      else\n",
             "                    end\n"
             "      end\n"
             "      # Tubo horizontal com corte inclinado (tubo avulso, trecho com emenda): trapézio no plano X-Z.\n"
             "      # A face maior fica embaixo; na travessa superior da moldura ela fica em cima.\n"
             "      if pts_front.nil? && tube[:axis] == 'x' && (tube[:cut_a_deg].to_f > 0.0 || tube[:cut_b_deg].to_f > 0.0)\n"
             "        la = h * Math.tan(tube[:cut_a_deg].to_f.clamp(0.0, 75.0).degrees)\n"
             "        lb = h * Math.tan(tube[:cut_b_deg].to_f.clamp(0.0, 75.0).degrees)\n"
             "        pts_front = if tube[:slot].to_s == 'sup'\n"
             "                      [\n"
             "                        Geom::Point3d.new(x0 + la, y0, z0),\n"
             "                        Geom::Point3d.new(x0 + w - lb, y0, z0),\n"
             "                        Geom::Point3d.new(x0 + w, y0, z0 + h),\n"
             "                        Geom::Point3d.new(x0, y0, z0 + h)\n"
             "                      ]\n"
             "                    else\n"
             "                      [\n"
             "                        Geom::Point3d.new(x0, y0, z0),\n"
             "                        Geom::Point3d.new(x0 + w, y0, z0),\n"
             "                        Geom::Point3d.new(x0 + w - lb, y0, z0 + h),\n"
             "                        Geom::Point3d.new(x0 + la, y0, z0 + h)\n"
             "                      ]\n"
             "                    end\n"
             "      end\n"
             "\n"
             "      if pts_front\n"
             "        face = grp.entities.add_face(pts_front)\n"
             "        if face\n"
             "          face.reverse! if face.normal.y < 0\n"
             "          face.pushpull(d)\n"
             "        end\n"
             "      else\n"),
        ],
        UNFOLD: [
            # DXF gravava só a primeira chapa: agora um arquivo por chapa
            ("      first_sheet = nesting['sheets'].first\n"
             "      unless first_sheet\n",
             "      sheets = nesting['sheets']\n"
             "      if sheets.empty?\n"),
            ("      dxf_str = generate_dxf_ac1009(nesting['sheet_w_mm'], nesting['sheet_h_mm'], first_sheet[:placements])\n"
             "      File.write(path, dxf_str, mode: 'w:UTF-8')\n"
             "      UI.messagebox(\"Arquivo DXF exportado com sucesso!\\n\\nCamadas geradas: ACM_CHAPA, ACM_CORTE, ACM_VINCO, ACM_DIRECAO, ACM_ETIQUETAS\\nCaminho: #{path}\")\n",
             "      # Um arquivo por chapa (um trabalho no Aspire); com uma chapa só, o arquivo é o escolhido\n"
             "      paths = sheets.each_with_index.map do |sh, i|\n"
             "        p = sheets.size == 1 ? path : path.sub(/\\.dxf\\z/i, \"_chapa#{i + 1}.dxf\")\n"
             "        File.write(p, generate_dxf_ac1009(nesting['sheet_w_mm'], nesting['sheet_h_mm'], sh[:placements]), mode: 'w:UTF-8')\n"
             "        p\n"
             "      end\n"
             "      pieces = sheets.sum { |sh| sh[:placements].size }\n"
             "      UI.messagebox(\"Arquivo DXF exportado com sucesso!\\n\\n#{pieces} peça(s) em #{sheets.size} chapa(s) de \" \\\n"
             "                    \"#{nesting['sheet_w_mm'].round}×#{nesting['sheet_h_mm'].round} mm\\n\" \\\n"
             "                    \"Camadas geradas: ACM_CHAPA, ACM_CORTE, ACM_VINCO, ACM_DIRECAO, ACM_ETIQUETAS\\n\\n#{paths.join(\"\\n\")}\")\n"),
            # DXF e ERP liam só o nível aberto para edição: agora o modelo inteiro, inclusive grupos
            ("      model.active_entities.grep(Sketchup::Group).each do |grp|\n"
             "        next unless grp.get_attribute(Catalog::ATTR_DICT, 'kind') == 'acm_tray'\n",
             "      each_cs_group(model.entities) do |grp, kind|\n"
             "        next unless kind == 'acm_tray'\n"),
            ("      model.active_entities.grep(Sketchup::Group).each do |grp|\n"
             "        kind = grp.get_attribute(Catalog::ATTR_DICT, 'kind')\n",
             "      each_cs_group(model.entities) do |grp, kind|\n"),
            ("    def self.export_erp_json_dialog\n",
             "    # Percorre o modelo inteiro (grupos e componentes do usuário, em qualquer nível)\n"
             "    # entregando as estruturas, tubos avulsos e bandejas do plugin\n"
             "    CS_KINDS = %w[parametric_frame single_tube acm_tray].freeze\n"
             "\n"
             "    def self.each_cs_group(entities, &blk)\n"
             "      entities.each do |e|\n"
             "        if e.is_a?(Sketchup::Group)\n"
             "          kind = e.get_attribute(Catalog::ATTR_DICT, 'kind')\n"
             "          if CS_KINDS.include?(kind)\n"
             "            blk.call(e, kind)\n"
             "          else\n"
             "            each_cs_group(e.entities, &blk)\n"
             "          end\n"
             "        elsif e.is_a?(Sketchup::ComponentInstance)\n"
             "          each_cs_group(e.definition.entities, &blk)\n"
             "        end\n"
             "      end\n"
             "    end\n"
             "\n"
             "    def self.export_erp_json_dialog\n"),
        ],
    }),
]


def build(target):
    versions = [v for v, _ in RELEASES]
    if target not in versions:
        raise SystemExit(f'versão desconhecida: {target} (opções: {", ".join(versions)})')
    patches = {'CS_ACM360.rb': [("PLUGIN_VERSION     = '1.0.0'", f"PLUGIN_VERSION     = '{target}'")]}
    for version, files in RELEASES[:versions.index(target) + 1]:
        for name, reps in files.items():
            patches.setdefault(name, []).extend(reps)

    out = ROOT / f'CS_ACM360_v{target}.rbz'
    with zipfile.ZipFile(SRC) as zin, zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as zout:
        for info in zin.infolist():
            data = zin.read(info.filename)
            for old, new in patches.get(info.filename, []):
                text = data.decode('utf-8')
                if text.count(old) != 1:
                    raise SystemExit(f'trecho não encontrado em {info.filename}:\n{old}')
                data = text.replace(old, new).encode('utf-8')
            zout.writestr(info, data)
    print(out.name)


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else RELEASES[-1][0])
