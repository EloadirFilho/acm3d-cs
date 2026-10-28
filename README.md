# 🏗️ acm3d-cs — CS ACM360 SketchUp Plugin & ERP Studio

Sistema híbrido de engenharia para **Fachadas em ACM e Estruturas Metálicas**, composto por:
1. **Plugin Nativo para SketchUp (`CS_ACM360_v1.0.2.rbz`)**: Geração paramétrica 3D de estruturas metálicas (Metalon/Alumínio), bandejas de ACM, leitura automática de juntas (`Ler ACM → Estrutura`), planificação 2D/3D e exportação de planos de corte em **DXF CNC (`AC1009`)**.
2. **Painel Web Integrado (`CS Fachadas · Totem Chão de Fábrica + ACM360 Studio`)**: Estúdio CAD/CAM no navegador integrado ao controle de Ordens de Serviço (OS), movimentação de materiais, aproveitamento de barras de `6000 mm` (FFD 1D) e gestão de chapas e retalhos 2D.

---

## 📂 Estrutura do Repositório

```text
acm3d-cs/
├── CS_ACM360_v1.0.0.rbz                # Plugin ORIGINAL sem correções (base dos patches — não alterar)
├── CS_ACM360_v1.0.2.rbz                # ORIGINAL corrigido para produção (tools/patch_original.py) — instale este
├── CS_ACM360_BETA_v1.5.0-beta.rbz      # Plugin BETA (em desenvolvimento; instala ao lado do original)
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
        ├── lib/
        │   ├── catalog.rb              # Catálogo das 21 bitolas (Metalon/Alumínio) e padrões de fábrica
        │   ├── settings.rb             # M12: Configurações (máquina + modelo .skp), import/export JSON
        │   ├── frame_kernel.rb         # Motor 3D de Gradil, Tubos, Cortes 0°/45°, Emendas e FFD 1D
        │   ├── acm_tray_kernel.rb      # Motor 3D de Bandejas ACM, Malha e Leitura ACM → Estrutura
        │   ├── unfold_dxf_engine.rb    # Motor de Planificação 2D/3D, Nesting e Exportador DXF AC1009
        │   ├── hardware_fasteners.rb   # M3/M4: Fita 3M VHB, reforços; cantoneiras, ancoragens e esperas desenhadas pelo plugin
        │   ├── interference_kernel.rb  # M5: corte nas interferências (apara/estende pontas de tubos avulsos)
        │   ├── tray_cutouts.rb         # M6: recortes nas bandejas (automático e por contorno)
        │   ├── live_tool.rb            # M1: ferramentas na tela (desenhar por 2 cantos, tubo por 2 pontos, alças, fixador no clique)
        │   ├── report_generator.rb     # M8: contagem de fixadores e gravação dos arquivos do relatório
        │   └── studio_dialog.rb        # Ponte Ruby <-> UI::HtmlDialog
        └── ui/
            ├── studio.html             # Interface do Construtor ao Vivo dentro do SketchUp
            └── acm360-report.js        # M8: relatório (lista de corte, plano de barras, XLSX/CSV/impressão) — usado também pelo painel web
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
4. Selecione o arquivo **`CS_ACM360_v1.0.2.rbz`** localizado na raiz deste repositório.
5. A barra de ferramentas **`CS ACM360`** e o menu **`Extensões > CS ACM360 · Estruturas & ACM`** ficarão disponíveis imediatamente.

### Original × BETA

| | Original (produção) | BETA (desenvolvimento) |
| :--- | :--- | :--- |
| Pacote | `CS_ACM360_v1.0.2.rbz` (correções sobre a 1.0.0) | `CS_ACM360_BETA_v1.5.0-beta.rbz` |
| Menu / barra | `CS ACM360` | `CS ACM360 BETA` |
| Código Ruby | módulo `CS_ACM360` (histórico do git, commit `6081a4d`) | módulo `CS_ACM360_BETA` em `sketchup-plugin/` |

- Os dois podem ficar instalados **ao mesmo tempo**: o BETA tem nome, pasta, módulo, menu, barra e preferências próprios, então instalar ou desinstalar um não mexe no outro.
- Os dois leem e editam as mesmas estruturas e bandejas do modelo (mesmos atributos e camadas), então um projeto feito no original pode ser aberto no BETA. Para não arriscar entregas, teste o BETA em uma **cópia** do `.skp`.
- Ao instalar uma versão nova por cima, **feche e abra o SketchUp**: até reiniciar, o SketchUp continua com o código antigo na memória e só a tela muda. Confira a versão no selo ao lado do título do painel.
- **Original v1.0.2**: mesmas funções da 1.0.0, só com correções — "Gerar Estrutura no 3D", tubo avulso com corte inclinado, DXF com um arquivo por chapa (antes só a 1ª chapa era gravada) e DXF/ERP lendo bandejas dentro de grupos. Gerado por `python tools/patch_original.py`; testado com `tools/run_sketchup_tests.ps1 -Original CS_ACM360_v1.0.2.rbz`.
- Para gerar o BETA de novo após mudanças: `python tools/build_rbz.py`. O pacote original nunca é regravado.
- Teste automático dentro do SketchUp 2025 (com o SketchUp fechado): `powershell -ExecutionPolicy Bypass -File tools/run_sketchup_tests.ps1`. Instala o BETA desta pasta, abre o SketchUp, cria estruturas e bandejas, testa relatório, DXF e ERP, e fecha sozinho.

### Principais comandos do plugin
- **Estruturas**: Novo Gradil com Travessas, Tubo Avulso, Ler ACM → Estrutura, cores por tipo/comprimento/acabamento.
- **Cortar nas Interferências** (tubos avulsos selecionados): cada ponta é aparada na face do tubo vizinho que ela atravessa, ou estendida até encostar quando o vão é pequeno (padrão até 50 mm). Corte reto ou inclinado num plano, desenhado de verdade no 3D e levado para a lista de corte; corte composto e ângulo acima de 75° ficam como estão, com aviso.
- **Bandejas ACM**: Bandeja paramétrica, Fachada em Malha, Planificar no 3D, Plano de Corte e Exportar DXF CNC.
- **Recortes nas Bandejas**: *Automáticos* (tubos, fixadores e objetos marcados como furo que atravessam a face viram recorte retangular com folga) e *pelo contorno selecionado* (faces ou linhas fechadas desenhadas/importadas sobre a face, como letra caixa). O recorte abre o furo no 3D e vai para a planificação e o DXF (ACM_CORTE); perto da dobra aparece aviso. Em Configurações, *Vista da Chapa no DXF* = verso espelha a chapa para CNC que fresa por trás.
- **Fixadores & Colagem**: Distribuir Cantoneiras (bandeja → estrutura), Ancoragens (estrutura → parede) ou Esperas/afastadores na seleção (sem seleção, pergunta se aplica no modelo todo), Remover Fixadores, Calcular Fita 3M VHB & Promotor de Adesão. As peças são cantoneiras em L desenhadas pelo plugin com as medidas das Configurações, distribuídas por distância (espaçamento + recuo das pontas), e acompanham a peça quando ela é editada ou regerada. Cada fixador leva o seu consumo (rebites, autobrocantes, buchas, parafusos), somado no relatório já multiplicado pela quantidade da bandeja.
- **Relatório** (aba 4 do painel): resumo de compra por bitola (metros, barras, aproveitamento, peso e custo), lista de corte consolidada com corte A/B, plano de barras, bandejas, fita VHB e fixadores. Exporta **Excel (XLSX)**, **CSV** e **imprime** com o cabeçalho da empresa. Lê o modelo inteiro, inclusive peças dentro de grupos.
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
  - No plugin BETA, quando as peças não cabem numa chapa, sai um arquivo por chapa (`_chapa1.dxf`, `_chapa2.dxf`…).
- **3. Materiais, VHB & Fixadores**: Lista de materiais (BOM), metros e rolos de fita 3M VHB (4910 / 4941 / 4955), quantidade de cantoneiras, parafusos e buchas, com **📊 Baixar Excel (XLSX)**, **CSV** e **🖨 Imprimir Relatório** (mesmo relatório do plugin).
- **4. Configurações**: os mesmos padrões do plugin, salvos no navegador. **Exportar/Importar JSON** leva a configuração do plugin para a web e vice-versa (`CS_ACM360_SETTINGS_V1`).
- **🚀 Gerar OS + Enviar Barras & Chapas p/ Produção**: Cria instantaneamente uma Ordem de Serviço no Quadro do Chão de Fábrica com a quantidade exata de metros lineares/barras de Metalon e área ($\text{m}^2$) de chapas de ACM.

---

## 🗺️ Status dos Módulos

| Módulo | Status |
| :--- | :--- |
| Fase 1 — MVP (gradil, tubos, bandejas, Ler ACM, planificação, DXF, OS no ERP) | ✅ Concluído |
| M3 — Colagem (fita 3M VHB e reforços) | 🟡 Parcial (cálculo de metros/rolos; desenho da fita e tiras pendentes) |
| M1 — Construtor ao Vivo | ✅ BETA 1.5.0 (gradil/bandeja/fachada por 2 cantos ou medida, tubo por 2 pontos, alças para esticar, fixador no clique; menu radial e painel lateral adiados) |
| M4 — Fixadores avançados | ✅ BETA 1.3.0 (cantoneira, ancoragem e espera desenhadas pelo plugin, por distância, com consumo no relatório; colocação por clique no BETA 1.5.0) |
| M5 — Corte nas interferências | ✅ BETA 1.4.0 (tubos avulsos; corte composto adiado) |
| M6 — Recortes nas bandejas ACM | ✅ BETA 1.4.0 (automático e por contorno; retângulo/círculo digitado não foi pedido) |
| M8 — Relatório, lista de corte e exportação | ✅ Concluído no BETA (filtros por seleção e colunas configuráveis adiados) |
| M12 — Configurações | ✅ Concluído no BETA (idiomas e verificação de atualização adiados) |
| M2, M7, M9, M10, M11 | ⬜ Planejado |

Detalhes e critérios de aceite em [docs/PLANO_MODULOS.md](docs/PLANO_MODULOS.md).

> [!WARNING]
> Desde o BETA 1.3.0 o plugin não usa mais os blocos `BLOCOS/*.skp` da referência ACM360 (terceiros): os fixadores são desenhados pelo próprio código. Os blocos continuam só dentro dos pacotes do original (`CS_ACM360_v1.0.x.rbz`) e no histórico do git; como o plugin é de uso interno, recomenda-se manter o repositório **privado**.

---

## 📄 Licença

Desenvolvido para **CS Comunicação / CS Fachadas**.
