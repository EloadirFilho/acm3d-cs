# 🏗️ acm3d-cs — CS ACM360 SketchUp Plugin & ERP Studio

Sistema híbrido de engenharia para **Fachadas em ACM e Estruturas Metálicas**, composto por:
1. **Plugin Nativo para SketchUp (`CS_ACM360_v1.0.0.rbz`)**: Geração paramétrica 3D de estruturas metálicas (Metalon/Alumínio), bandejas de ACM, leitura automática de juntas (`Ler ACM → Estrutura`), planificação 2D/3D e exportação de planos de corte em **DXF CNC (`AC1009`)**.
2. **Painel Web Integrado (`CS Fachadas · Totem Chão de Fábrica + ACM360 Studio`)**: Estúdio CAD/CAM no navegador integrado ao controle de Ordens de Serviço (OS), movimentação de materiais, aproveitamento de barras de `6000 mm` (FFD 1D) e gestão de chapas e retalhos 2D.

---

## 📂 Estrutura do Repositório

```text
acm3d-cs/
├── CS_ACM360_v1.0.0.rbz                # Pacote pronto para instalar no SketchUp
├── PLANO_PROJETO.md                    # Plano técnico, arquitetura, fórmulas e roadmap Fase 1
├── docs/
│   └── PLANO_MODULOS.md                # Planejamento completo dos 12 módulos avançados (M1 a M12)
├── README.md                           # Documentação principal do projeto
├── index.html                          # Interface Web (Totem Chão de Fábrica + ACM360 Studio)
├── styles.css                          # Design System Industrial High-Contrast & CAD Studio
├── app.js                              # Motor Web (OS, Estoque, Chapas 2D e ACM360 Studio)
└── sketchup-plugin/                    # Código-fonte aberto do Plugin para SketchUp
    ├── CS_ACM360.rb                    # Loader principal da extensão SketchUp
    └── CS_ACM360/
        ├── main.rb                     # Menus, Toolbar e Menu de Contexto (Botão Direito)
        ├── BLOCOS/                     # Componentes 3D (.skp) de fixadores estruturais
        │   ├── Ancoragem_F001.skp
        │   ├── Espera_F002.skp
        │   └── Cantoneira_Fixador_F003.skp
        ├── lib/
        │   ├── catalog.rb              # Catálogo das 21 bitolas (Metalon/Alumínio) e padrões ACM
        │   ├── frame_kernel.rb         # Motor 3D de Gradil, Tubos, Cortes 0°/45°, Emendas e FFD 1D
        │   ├── acm_tray_kernel.rb      # Motor 3D de Bandejas ACM, Malha e Leitura ACM → Estrutura
        │   ├── unfold_dxf_engine.rb    # Motor de Planificação 2D/3D, Nesting e Exportador DXF AC1009
        │   └── studio_dialog.rb        # Ponte Ruby <-> UI::HtmlDialog
        └── ui/
            └── studio.html             # Interface do Construtor ao Vivo dentro do SketchUp
```

---

## 🚀 Como Instalar o Plugin no SketchUp

1. Abra o **SketchUp**.
2. Acesse **Extensões > Gerenciador de Extensões** (ou **Janela > Gerenciador de Extensões**).
3. Clique no botão **Instalar Extensão…** no canto inferior.
4. Selecione o arquivo **`CS_ACM360_v1.0.0.rbz`** localizado na raiz deste repositório.
5. A barra de ferramentas **`CS ACM360`** e o menu **`Extensões > CS ACM360 · Estruturas & ACM`** ficarão disponíveis imediatamente.

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
- **🚀 Gerar OS + Enviar Barras & Chapas p/ Produção**: Cria instantaneamente uma Ordem de Serviço no Quadro do Chão de Fábrica com a quantidade exata de metros lineares/barras de Metalon e área ($\text{m}^2$) de chapas de ACM.

---

## 📄 Licença

Desenvolvido para **CS Comunicação / CS Fachadas**.
