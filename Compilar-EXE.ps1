<#
============================================================================
  COMPILADOR -> transforma Otimizar-3D.ps1 em Otimizar-3D.exe
  Usa o modulo "ps2exe" (baixado do PowerShell Gallery, gratuito).
  Basta clicar com botao direito neste arquivo > "Executar com o PowerShell".
============================================================================
#>

$ErrorActionPreference = "Stop"
$pasta   = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$entrada = Join-Path $pasta "Otimizar-3D.ps1"
$saida   = Join-Path $pasta "Otimizar-3D.exe"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Compilando Otimizador 3D para .EXE" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

if (-not (Test-Path $entrada)) {
    Write-Host "ERRO: nao encontrei 'Otimizar-3D.ps1' nesta pasta." -ForegroundColor Red
    Read-Host "Pressione ENTER para sair"; exit 1
}

# 1) Garante que o modulo ps2exe esteja instalado (so para o usuario atual)
if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host "Instalando modulo 'ps2exe' (uma unica vez)..." -ForegroundColor Yellow
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
        }
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        Install-Module -Name ps2exe -Scope CurrentUser -Force -AllowClobber
    } catch {
        Write-Host "Falha ao instalar ps2exe automaticamente: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Instale manualmente com:  Install-Module ps2exe -Scope CurrentUser" -ForegroundColor Yellow
        Read-Host "Pressione ENTER para sair"; exit 1
    }
}

Import-Module ps2exe -Force

# 2) Compila. O EXE ja pede admin sozinho (-requireAdmin embute o manifesto UAC).
Write-Host "Gerando: $saida" -ForegroundColor Gray
Invoke-PS2EXE -InputFile $entrada -OutputFile $saida `
    -requireAdmin `
    -noConsole:$false `
    -title "Otimizador de Desempenho 3D" `
    -description "Otimiza o Windows 10 para modelagem 3D" `
    -company "Uso Pessoal" `
    -product "Otimizador 3D" `
    -version "1.0.0.0"

if (Test-Path $saida) {
    Write-Host ""
    Write-Host "SUCESSO! Arquivo gerado:" -ForegroundColor Green
    Write-Host "  $saida" -ForegroundColor White
    Write-Host "De 2 cliques nele (vai pedir 'Sim' no controle de conta de usuario)." -ForegroundColor Green
} else {
    Write-Host "Algo deu errado - o .exe nao foi criado." -ForegroundColor Red
}
Read-Host "Pressione ENTER para sair"
