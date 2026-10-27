# 🏗️ acm3d-cs — CS ACM360 SketchUp Plugin & ERP Studio

Sistema híbrido de engenharia para **Fachadas em ACM e Estruturas Metálicas**, composto por:
1. **Plugin Nativo para SketchUp (`CS_ACM360_v1.0.0.rbz`)**: Geração paramétrica 3D de estruturas metálicas (Metalon/Alumínio), bandejas de ACM, leitura automática de juntas (`Ler ACM → Estrutura`), planificação 2D/3D e exportação de planos de corte em **DXF CNC (`AC1009`)**.
2. **Painel Web Integrado (`CS Fachadas · Totem Chão de Fábrica + ACM360 Studio`)**: Estúdio CAD/CAM no navegador integrado ao controle de Ordens de Serviço (OS), movimentação de materiais, aproveitamento de barras de `6000 mm` (FFD 1D) e gestão de chapas e retalhos 2D.

---

## 📂 Estrutura do Repositório

```text
acm3d-cs/
├── CS_ACM360_v1.0.0.rbz                # Plugin ORIGINAL (em produção — não alterar)
├── CS_ACM360_v1.0.1.rbz                # Original + correção do "Gerar Estrutura no 3D" (tools/patch_original.py)
├── CS_ACM360_BETA_v1.1.0-beta.rbz      # Plugin BETA (em desenvolvimento; instala ao lado do original)
├── tools/build_rbz.py                  # Gera o .rbz BETA a partir de sketchup-plugin/
├── PLANO_PROJETO.md                    # Plano técnico, arquitetura, fórmulas e roadmap Fase 1
├── docs/
│   └── PLANO_MODULOS.md                # Planejamento completo dos 12 módulos avançados (M1 a M12)
├── README.md                           # Documentação principal do projeto
├── index.html                          # Interface Web (Totem Chão de Fábrica + ACM360 Studio)
├── styles.css                          # Design System Industrial High-Contrast & CAD Studio
├── app.js                              # Motor Web (OS, Estoque, Chapas 2D e ACM360 Studio)
├── acm360-settings.js                  # M12: Configurações do Studio web (mesmo JSON do plugin)
├── tests/                              # Testes Node (node --test tests/*.test.js)
└── sketchup-plugin/                    # Código-fonte do Plugin BETA
    ├── CS_ACM360_BETA.rb               # Loader da extensão BETA
    └── CS_ACM360_BETA/
        ├── main.rb                     # Menus, Toolbar e Menu de Contexto (Botão Direito)
        ├── BLOCOS/                     # Componentes 3D (.skp) de fixadores estruturais
        │   ├── Ancoragem_F001.skp
        │   ├── Espera_F002.skp
        │   └── Cantoneira_Fixador_F003.skp
        ├── lib/
        │   ├── catalog.rb              # Catálogo das 21 bitolas (Metalon/Alumínio) e padrões de fábrica
        │   ├── settings.rb             # M12: Configurações (máquina + modelo .skp), import/export JSON
        │   ├── frame_kernel.rb         # Motor 3D de Gradil, Tubos, Cortes 0°/45°, Emendas e FFD 1D
        │   ├── acm_tray_kernel.rb      # Motor 3D de Bandejas ACM, Malha e Leitura ACM → Estrutura
        │   ├── unfold_dxf_engine.rb    # Motor de Planificação 2D/3D, Nesting e Exportador DXF AC1009
        │   ├── hardware_fasteners.rb   # M3/M4: Fita 3M VHB, reforços e distribuição de cantoneiras F003
        │   ├── report_generator.rb     # M8: Relatório estrutural, lista de corte e exportação CSV (Excel)
        │   └── studio_dialog.rb        # Ponte Ruby <-> UI::HtmlDialog
        └── ui/
            └── studio.html             # Interface do Construtor ao Vivo dentro do SketchUp
```

---

## 🎯 Contexto de Uso

- **Uso interno** da CS Comunicação / CS Fachadas (sem licença ou login).
- **SketchUp 2025** é a versão usada pela equipe e a versão de referência para testes.
- **Chapas de ACM de 3 mm e 4 mm**, de diversos fornecedores (o fator de dobra deve ser calibrado por fornecedor/fresa).
- **Fluxo CNC**: DXF do plugin (testado e validado no Aspire) → **Vectric Aspire** (gera o G-code em `.txt`) → pendrive → aplicativo que envia o G-code para a Router.
- **Sem backend do ERP previsto**: a troca entre plugin e painel web é feita por arquivos `.json` / `.dxf`.

---

## 🚀 Como Instalar o Plugin no SketchUp

1. Abra o **SketchUp 2025**.
2. Acesse **Extensões > Gerenciador de Extensões** (ou **Janela > Gerenciador de Extensões**).
3. Clique no botão **Instalar Extensão…** no canto inferior.
4. Selecione o arquivo **`CS_ACM360_v1.0.0.rbz`** localizado na raiz deste repositório.
5. A barra de ferramentas **`CS ACM360`** e o menu **`Extensões > CS ACM360 · Estruturas & ACM`** ficarão disponíveis imediatamente.

### Original × BETA

| | Original (produção) | BETA (desenvolvimento) |
| :--- | :--- | :--- |
| Pacote | `CS_ACM360_v1.0.0.rbz` | `CS_ACM360_BETA_v1.1.0-beta.rbz` |
| Menu / barra | `CS ACM360` | `CS ACM360 BETA` |
| Código Ruby | módulo `CS_ACM360` (histórico do git, commit `6081a4d`) | módulo `CS_ACM360_BETA` em `sketchup-plugin/` |

- Os dois podem ficar instalados **ao mesmo tempo**: o BETA tem nome, pasta, módulo, menu, barra e preferências próprios, então instalar ou desinstalar um não mexe no outro.
- Os dois leem e editam as mesmas estruturas e bandejas do modelo (mesmos atributos e camadas), então um projeto feito no original pode ser aberto no BETA. Para não arriscar entregas, teste o BETA em uma **cópia** do `.skp`.
- Para gerar o BETA de novo após mudanças: `python tools/build_rbz.py`. O pacote original nunca é regravado.

### Principais comandos do plugin
- **Estruturas**: Novo Gradil com Travessas, Tubo Avulso, Ler ACM → Estrutura, cores por tipo/comprimento/acabamento.
- **Bandejas ACM**: Bandeja paramétrica, Fachada em Malha, Planificar no 3D, Plano de Corte e Exportar DXF CNC.
- **Fixadores & Colagem**: Distribuir Cantoneiras (F003) na seleção, Calcular Fita 3M VHB & Promotor de Adesão, inserir blocos F001/F002/F003.
- **Relatório**: Relatório Estrutural & Plano de Barras 1D, Exportar Lista de Corte CSV (Excel).
- **Publicar**: exporta o pacote `.json` para o CS Fachadas ERP.
- **Configurações** (somente BETA, aba 5 do painel): barra comercial, serra, chapa ACM, fator de dobra por fornecedor/espessura, fitas, preço por metro das bitolas, bitolas próprias e cabeçalho de impressão. Fica salvo na máquina e dentro do `.skp`.

Os mesmos comandos aparecem no menu de contexto (botão direito) sobre estruturas e bandejas.

---

## 🖥️ Como Executar o Aplicativo Web (`ACM360 Studio + Totem ERP`)

O aplicativo web não requer build complexo — basta abrir `index.html` diretamente no navegador ou servir a pasta com qualquer servidor estático:

```bash
# Exemplo com npx serve ou Python
npx serve .
# ou
python -m http.server 8080
```

Na barra superior do sistema, clique na aba **`ACM360 Studio`** para acessar:
- **1. Estruturas (Gradil & Tubos)**: Configure largura, altura, bitola do quadro e das travessas (21 perfis de Metalon e Alumínio), corte reto (`Por Dentro` / `Por Fora`) ou `Meia-Esquadria 45°`, montantes verticais, travessas horizontais e estratégia de emendas para barras de `6000 mm`.
- **2. Bandejas ACM & Planificação**: Configure malhas de fachada (`Colunas × Linhas`), juntas de dilatação, retornos de dobra (`90°`), abas de fixação, refile, fator de dobra e fresa (`V 90°`, `V 135°`, `U`).
- **⚡ Ler ACM → Estrutura**: Alinha automaticamente os montantes verticais e travessas horizontais no centro das juntas das bandejas de ACM.
- **📐 Baixar DXF CNC**: Exporta o arquivo `.dxf` (`AC1009` AutoCAD R12) pronto para Router CNC com as camadas oficiais:
  - `ACM_CHAPA` (Branco — ACI 7)
  - `ACM_CORTE` (Vermelho — ACI 1)
  - `ACM_VINCO` (Magenta — ACI 174)
  - `ACM_DIRECAO` (Cinza — ACI 8)
  - `ACM_ETIQUETAS` (Branco — ACI 7)
- **3. Materiais, VHB & Fixadores**: Lista de materiais (BOM), metros e rolos de fita 3M VHB (4910 / 4941 / 4955), quantidade de cantoneiras, parafusos e buchas, com **📊 Baixar CSV (Excel)**.
- **4. Configurações**: os mesmos padrões do plugin, salvos no navegador. **Exportar/Importar JSON** leva a configuração do plugin para a web e vice-versa (`CS_ACM360_SETTINGS_V1`).
- **🚀 Gerar OS + Enviar Barras & Chapas p/ Produção**: Cria instantaneamente uma Ordem de Serviço no Quadro do Chão de Fábrica com a quantidade exata de metros lineares/barras de Metalon e área ($\text{m}^2$) de chapas de ACM.

---

## 🗺️ Status dos Módulos

| Módulo | Status |
| :--- | :--- |
| Fase 1 — MVP (gradil, tubos, bandejas, Ler ACM, planificação, DXF, OS no ERP) | ✅ Concluído |
| M3 — Colagem (fita 3M VHB e reforços) | 🟡 Parcial (cálculo de metros/rolos; desenho da fita e tiras pendentes) |
| M4 — Fixadores avançados | 🟡 Parcial (distribuição de cantoneiras F003 e consumo de parafusos/buchas) |
| M8 — Relatório, lista de corte e exportação | 🟡 Parcial (relatório + CSV; XLSX pendente) |
| M12 — Configurações | ✅ Concluído no BETA (idiomas e verificação de atualização adiados) |
| M1, M2, M5, M6, M7, M9, M10, M11 | ⬜ Planejado |

Detalhes e critérios de aceite em [docs/PLANO_MODULOS.md](docs/PLANO_MODULOS.md).

> [!WARNING]
> Os blocos `BLOCOS/*.skp` vieram da referência ACM360 (terceiros). Como o plugin é de uso interno, recomenda-se manter este repositório **privado** e substituir os blocos por modelos próprios da CS.

---

## 📄 Licença

Desenvolvido para **CS Comunicação / CS Fachadas**.
