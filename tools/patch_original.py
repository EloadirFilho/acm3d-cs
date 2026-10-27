"""Gera CS_ACM360_v1.0.1.rbz a partir do original v1.0.0, só com correções pontuais.

Uso: python tools/patch_original.py
O CS_ACM360_v1.0.0.rbz não é alterado. Módulo, menus e pastas continuam os do
original, então instalar o v1.0.1 atualiza o plugin de produção no lugar.
"""
import pathlib
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / 'CS_ACM360_v1.0.0.rbz'
OUT = ROOT / 'CS_ACM360_v1.0.1.rbz'

PATCHES = {
    'CS_ACM360.rb': [
        ("PLUGIN_VERSION     = '1.0.0'", "PLUGIN_VERSION     = '1.0.1'"),
    ],
    # Sketchup::Entities não tem empty? -> "Gerar Estrutura no 3D" falhava.
    'CS_ACM360/lib/frame_kernel.rb': [
        ('g.erase! if g.valid? && g.entities.empty?', 'g.erase! if g.valid? && g.entities.length.zero?'),
    ],
}

with zipfile.ZipFile(SRC) as zin, zipfile.ZipFile(OUT, 'w', zipfile.ZIP_DEFLATED) as zout:
    for info in zin.infolist():
        data = zin.read(info.filename)
        for old, new in PATCHES.get(info.filename, []):
            text = data.decode('utf-8')
            if text.count(old) != 1:
                raise SystemExit(f'trecho não encontrado em {info.filename}: {old}')
            data = text.replace(old, new).encode('utf-8')
        zout.writestr(info, data)

print(OUT.name)
