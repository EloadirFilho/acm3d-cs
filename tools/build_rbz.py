"""Empacota o plugin BETA em .rbz (zip com o loader e a pasta na raiz).

Uso: python tools/build_rbz.py
O pacote original CS_ACM360_v1.0.0.rbz não é tocado.
"""
import pathlib
import re
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / 'sketchup-plugin'
LOADER = SRC / 'CS_ACM360_BETA.rb'

version = re.search(r"PLUGIN_VERSION\s*=\s*'([^']+)'", LOADER.read_text(encoding='utf-8')).group(1)
out = ROOT / f'CS_ACM360_BETA_v{version}.rbz'

with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    z.write(LOADER, LOADER.name)
    for f in sorted((SRC / 'CS_ACM360_BETA').rglob('*')):
        if f.is_file():
            z.write(f, f.relative_to(SRC).as_posix())

print(out.name)
