# Instala o CS ACM360 BETA (codigo de sketchup-plugin/) no SketchUp 2025 desta maquina,
# abre o SketchUp rodando tests/sketchup/run_tests.rb e mostra o resultado.
# Uso: powershell -ExecutionPolicy Bypass -File tools/run_sketchup_tests.ps1
# O SketchUp precisa estar fechado. O plugin original (CS_ACM360) nao e tocado.
#
# Com -Original CS_ACM360_v1.0.2.rbz testa o pacote do original corrigido (junto com o
# BETA instalado, o que tambem confere que os dois convivem) e depois o remove.
param(
  [int]$TimeoutSec = 180,
  [string]$Original = ''
)

$ErrorActionPreference = 'Stop'
$root     = Split-Path -Parent $PSScriptRoot
$exe      = 'C:\Program Files\SketchUp\SketchUp 2025\SketchUp\SketchUp.exe'
$plugins  = Join-Path $env:APPDATA 'SketchUp\SketchUp 2025\SketchUp\Plugins'
$template = 'C:\Program Files\SketchUp\SketchUp 2025\SketchUp\resources\en-US\Templates\Temp01b - Simple.skp'
$base     = Join-Path $env:TEMP 'cs_acm360_base.skp'
$out      = Join-Path $env:TEMP 'cs_acm360_tests'

if (Get-Process -Name SketchUp -ErrorAction SilentlyContinue) {
  Write-Error 'O SketchUp esta aberto. Feche-o antes de rodar os testes.'
}

# Abre o SketchUp com um script e um modelo; confirma avisos modais com Enter
function Invoke-SketchUp([string]$script, [string]$model, [string]$doneFile) {
  $p = Start-Process -FilePath $exe -ArgumentList '-RubyStartup', "`"$script`"", "`"$model`"" -PassThru
  $ws = New-Object -ComObject WScript.Shell
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  $tick = 0
  while (-not (Test-Path $doneFile) -and -not $p.HasExited -and (Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 3
    $tick++
    # Template de outra versao abre um "Aviso de versao de arquivo"
    if ($doneFile -eq $base -and $tick % 3 -eq 0 -and $ws.AppActivate($p.Id)) { $ws.SendKeys('{ENTER}') }
  }
  $p.WaitForExit(15000) | Out-Null
  if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force }
}

if (-not (Test-Path $base)) {
  $tmp = Join-Path $env:TEMP 'cs_acm360_template.skp'
  Copy-Item $template $tmp -Force
  $env:CS_BASE_SKP = $base -replace '\\', '/'
  Invoke-SketchUp (Join-Path $root 'tests\sketchup\make_base.rb') $tmp $base
  if (-not (Test-Path $base)) { Write-Error 'Nao foi possivel criar o modelo base.' }
}

# Instala so o BETA
Remove-Item -Recurse -Force (Join-Path $plugins 'CS_ACM360_BETA') -ErrorAction SilentlyContinue
Copy-Item (Join-Path $root 'sketchup-plugin\CS_ACM360_BETA.rb') $plugins -Force
Copy-Item (Join-Path $root 'sketchup-plugin\CS_ACM360_BETA') $plugins -Recurse -Force

Remove-Item -Recurse -Force $out -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $out | Out-Null
$env:CS_TEST_OUT = $out
$model = Join-Path $out 'modelo_teste.skp'
Copy-Item $base $model

$results = Join-Path $out 'results.json'
if ($Original) {
  if (Test-Path (Join-Path $plugins 'CS_ACM360.rb')) {
    Write-Error 'O plugin original ja esta instalado nesta maquina; o teste nao vai sobrescreve-lo.'
  }
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [System.IO.Compression.ZipFile]::ExtractToDirectory((Resolve-Path (Join-Path $root $Original)), $plugins)
  try {
    Invoke-SketchUp (Join-Path $root 'tests\sketchup\run_original_tests.rb') $model $results
  } finally {
    Remove-Item -Force (Join-Path $plugins 'CS_ACM360.rb')
    Remove-Item -Recurse -Force (Join-Path $plugins 'CS_ACM360')
  }
} else {
  Invoke-SketchUp (Join-Path $root 'tests\sketchup\run_tests.rb') $model $results
}

if (-not (Test-Path $results)) {
  Write-Error "Sem resultado em $TimeoutSec s (o SketchUp pode ter parado numa janela)."
}
Get-Content $results -Raw -Encoding UTF8
