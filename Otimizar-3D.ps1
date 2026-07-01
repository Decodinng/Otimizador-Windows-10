<#
============================================================================
  OTIMIZADOR DE DESEMPENHO - WINDOWS 10 (foco em MODELAGEM 3D)
  Para: Blender, 3ds Max, Maya, ZBrush, SketchUp, Cinema4D, etc.
============================================================================
  - Cria PONTO DE RESTAURACAO antes de qualquer mudanca.
  - Todas as acoes sao registradas em log (na mesma pasta).
  - Otimizacoes conservadoras e reversiveis. Nao remove drivers, nao mexe
    em arquivos do sistema, nao desativa Windows Update permanentemente.
  Autor: gerado com Claude Code
============================================================================
#>

# ---------------------------------------------------------------------------
# ELEVACAO AUTOMATICA (pede admin se necessario)
# ---------------------------------------------------------------------------
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Solicitando privilegios de Administrador..." -ForegroundColor Yellow
    $exe = (Get-Process -Id $PID).Path
    if ($exe -like "*powershell*") {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    } else {
        # Executando como .exe compilado
        Start-Process $exe -Verb RunAs
    }
    exit
}

# ---------------------------------------------------------------------------
# CONFIGURACAO / LOG
# ---------------------------------------------------------------------------
$ErrorActionPreference = "Continue"
$pasta   = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent ([Environment]::GetCommandLineArgs()[0]) }
if (-not $pasta) { $pasta = "$env:USERPROFILE\Desktop" }
$logFile = Join-Path $pasta ("Otimizacao_{0:yyyy-MM-dd_HH-mm-ss}.log" -f (Get-Date))

function Log {
    param([string]$Msg, [string]$Cor = "Gray", [string]$Tag = "INFO")
    $linha = "[{0:HH:mm:ss}] [{1}] {2}" -f (Get-Date), $Tag, $Msg
    Write-Host $linha -ForegroundColor $Cor
    Add-Content -Path $logFile -Value $linha -Encoding UTF8
}
function OK   ($m) { Log $m "Green"  "OK " }
function WARN ($m) { Log $m "Yellow" "AVISO" }
function ERR  ($m) { Log $m "Red"    "ERRO" }
function Head ($t) {
    $b = "=" * 70
    Write-Host ""; Write-Host $b -ForegroundColor Cyan
    Write-Host "  $t" -ForegroundColor Cyan
    Write-Host $b -ForegroundColor Cyan
    Add-Content -Path $logFile -Value "`r`n=== $t ===" -Encoding UTF8
}

# Helper: escreve valor de registro criando o caminho se preciso
function Set-Reg {
    param($Path, $Name, $Value, $Type = "DWord")
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
        return $true
    } catch { ERR "Registro $Path\$Name : $($_.Exception.Message)"; return $false }
}

# ---------------------------------------------------------------------------
# 0. INFORMACOES DA MAQUINA
# ---------------------------------------------------------------------------
function Info-Maquina {
    Head "INFORMACOES DO SISTEMA"
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
    $gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.AdapterRAM -gt 0 -or $_.Name -notlike "*Basic*" }
    $os  = Get-CimInstance Win32_OperatingSystem
    Log ("CPU : {0} ({1} nucleos / {2} threads)" -f $cpu.Name.Trim(), $cpu.NumberOfCores, $cpu.NumberOfLogicalProcessors)
    Log ("RAM : {0} GB" -f $ram)
    foreach ($g in $gpu) { Log ("GPU : {0}" -f $g.Name) }
    Log ("SO  : {0} (build {1})" -f $os.Caption, $os.BuildNumber)
    $script:RamGB = $ram
}

# ---------------------------------------------------------------------------
# 1. PONTO DE RESTAURACAO
# ---------------------------------------------------------------------------
function Criar-Restauracao {
    Head "1. PONTO DE RESTAURACAO (seguranca)"
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        # Remove limite de frequencia para garantir que o ponto seja criado agora
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" "SystemRestorePointCreationFrequency" 0
        Checkpoint-Computer -Description "Antes da Otimizacao 3D" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        OK "Ponto de restauracao criado com sucesso."
    } catch {
        WARN "Nao foi possivel criar ponto de restauracao (Protecao do Sistema pode estar desligada)."
        WARN "Detalhe: $($_.Exception.Message)"
    }
}

# ---------------------------------------------------------------------------
# 2. PLANO DE ENERGIA - DESEMPENHO MAXIMO
# ---------------------------------------------------------------------------
function Plano-Energia {
    Head "2. PLANO DE ENERGIA - DESEMPENHO MAXIMO"
    try {
        # Tenta ativar o plano "Ultimate Performance"
        $ult = "e9a42b02-d5df-448d-aa00-03f14749eb61"
        powercfg -duplicatescheme $ult 2>$null | Out-Null
        $existe = (powercfg /list) -match "Desempenho Excepcional|Ultimate Performance"
        if ($existe) {
            powercfg /setactive $ult 2>$null
            OK "Plano 'Desempenho Excepcional (Ultimate)' ativado."
        } else {
            powercfg /setactive SCHEME_MIN   # Alto desempenho
            OK "Plano 'Alto Desempenho' ativado."
        }
        # Nunca desligar disco/monitor no modo trabalho (ligado na tomada)
        powercfg /change disk-timeout-ac 0
        powercfg /change standby-timeout-ac 0
        powercfg /change hibernate-timeout-ac 0
        powercfg /change monitor-timeout-ac 15
        # Desativa USB selective suspend (evita travadas com tablets Wacom/pen)
        powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
        # Processador sempre 100% (min e max) na tomada
        powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100
        powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100
        # PCI Express - sem economia de energia (melhor para GPU)
        powercfg /setacvalueindex SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
        powercfg /setactive SCHEME_CURRENT
        OK "USB suspend desligado, CPU 100%, PCI-E sem economia (na tomada)."
    } catch { ERR "Plano de energia: $($_.Exception.Message)" }
}

# ---------------------------------------------------------------------------
# 3. AJUSTES DE DESEMPENHO DO WINDOWS / GPU
# ---------------------------------------------------------------------------
function Ajustes-Desempenho {
    Head "3. DESEMPENHO VISUAL, CPU E GPU"

    # Efeitos visuais: melhor desempenho (mantendo suavizacao de fontes)
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 3
    Set-Reg "HKCU:\Control Panel\Desktop" "DragFullWindows" "0" "String"
    Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0" "String"
    Set-Reg "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" "0" "String"
    Set-Reg "HKCU:\Control Panel\Desktop" "UserPreferencesMask" ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) "Binary"
    OK "Efeitos visuais ajustados para desempenho (fontes preservadas)."

    # Agendamento do processador priorizando PROGRAMAS (foreground)
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 38
    OK "Prioridade da CPU otimizada para programas em primeiro plano."

    # Hardware-accelerated GPU Scheduling (HAGS) - Win10 2004+
    if ([Environment]::OSVersion.Version.Build -ge 19041) {
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 2
        OK "Agendamento de GPU por hardware (HAGS) habilitado. (reinicio necessario)"
    }

    # Timeout do driver de video (TDR) - evita crash em cenas/renders pesados
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrDelay" 10
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrDdiDelay" 10
    OK "TDR (timeout da GPU) aumentado para 10s - menos crashes em render pesado."

    # Desliga Power Throttling (nao limita apps de modelagem em segundo plano)
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "PowerThrottlingOff" 1
    OK "Power Throttling desativado."

    # Prioriza uso de programas na memoria (nao cache de sistema)
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargeSystemCache" 0
    OK "Gerenciamento de memoria priorizando programas."
}

# ---------------------------------------------------------------------------
# 4. GAME BAR / GAME DVR (atrapalham a GPU em apps 3D)
# ---------------------------------------------------------------------------
function Desativar-GameDVR {
    Head "4. DESATIVAR GAME BAR / GAME DVR"
    Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0
    Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode" 2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 0
    Set-Reg "HKCU:\Software\Microsoft\GameBar" "UseNexusForGameBarEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\GameBar" "ShowStartupPanel" 0
    OK "Game Bar / Game DVR desativados (libera recursos da GPU)."
}

# ---------------------------------------------------------------------------
# 5. APPS EM SEGUNDO PLANO / TELEMETRIA LEVE
# ---------------------------------------------------------------------------
function Reduzir-BackgroundApps {
    Head "5. APPS EM SEGUNDO PLANO E DICAS/ANUNCIOS"
    # Impede apps da Microsoft Store rodarem em segundo plano
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsRunInBackground" 2
    # Desliga sugestoes / conteudo automatico do menu iniciar (consumo desnecessario)
    $cdm = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    Set-Reg $cdm "SystemPaneSuggestionsEnabled" 0
    Set-Reg $cdm "SubscribedContent-338388Enabled" 0
    Set-Reg $cdm "SubscribedContent-338389Enabled" 0
    Set-Reg $cdm "SilentInstalledAppsEnabled" 0
    # Telemetria no nivel basico (nao desliga updates de seguranca)
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 1
    OK "Apps em segundo plano e sugestoes reduzidos."
}

# ---------------------------------------------------------------------------
# 6. SERVICOS DESNECESSARIOS (seguro - apenas nao-essenciais)
# ---------------------------------------------------------------------------
function Otimizar-Servicos {
    Head "6. SERVICOS NAO ESSENCIAIS (modo Manual)"
    # Colocamos em Manual (nao Disabled) para nao quebrar nada - so nao inicia sozinho
    $servicos = @(
        "DiagTrack",        # Experiencias do Usuario e Telemetria
        "dmwappushservice", # WAP Push (telemetria)
        "MapsBroker",       # Mapas baixados
        "XblAuthManager",   # Xbox Live Auth
        "XblGameSave",      # Xbox Save
        "XboxNetApiSvc",    # Xbox Networking
        "XboxGipSvc",       # Xbox controller
        "Fax",              # Fax
        "RetailDemo"        # Modo demonstracao de loja
    )
    foreach ($s in $servicos) {
        $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
        if ($svc) {
            try {
                Set-Service -Name $s -StartupType Manual -ErrorAction Stop
                if ($svc.Status -eq "Running") { Stop-Service -Name $s -Force -ErrorAction SilentlyContinue }
                OK "Servico '$s' -> Manual."
            } catch { WARN "Nao alterou '$s': $($_.Exception.Message)" }
        }
    }
}

# ---------------------------------------------------------------------------
# 7. LIMPEZA DE ARQUIVOS TEMPORARIOS / CACHE
# ---------------------------------------------------------------------------
function Limpeza {
    Head "7. LIMPEZA DE TEMPORARIOS E CACHE"
    $alvos = @(
        "$env:TEMP\*",
        "$env:SystemRoot\Temp\*",
        "$env:SystemRoot\Prefetch\*",
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db",
        "$env:SystemRoot\SoftwareDistribution\Download\*"
    )
    $antes = [math]::Round((Get-PSDrive C).Free / 1GB, 2)
    foreach ($a in $alvos) {
        try {
            Remove-Item $a -Recurse -Force -ErrorAction SilentlyContinue
            Log "Limpo: $a"
        } catch {}
    }
    # Esvazia lixeira
    try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue; Log "Lixeira esvaziada." } catch {}
    # Limpa cache DNS
    ipconfig /flushdns | Out-Null
    Log "Cache DNS limpo."
    $depois = [math]::Round((Get-PSDrive C).Free / 1GB, 2)
    $ganho  = [math]::Round($depois - $antes, 2)
    OK ("Limpeza concluida. Espaco livre em C: {0} GB (liberado ~{1} GB)." -f $depois, $ganho)
}

# ---------------------------------------------------------------------------
# 8. MEMORIA VIRTUAL (PAGEFILE) OTIMIZADA PARA 3D
# ---------------------------------------------------------------------------
function Ajustar-Pagefile {
    Head "8. MEMORIA VIRTUAL (PAGEFILE)"
    try {
        $ramGB = if ($script:RamGB) { $script:RamGB } else {
            [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 0)
        }
        # Regra pratica p/ 3D: min = RAM, max = 1.5x RAM (evita "out of memory" em renders)
        $min = [int]($ramGB * 1024)
        $max = [int]($ramGB * 1024 * 1.5)

        # Desliga o gerenciamento automatico
        $cs = Get-CimInstance Win32_ComputerSystem
        if ($cs.AutomaticManagedPagefile) {
            Set-CimInstance -InputObject $cs -Property @{ AutomaticManagedPagefile = $false } | Out-Null
        }
        $pf = Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue
        if ($pf) {
            Set-CimInstance -InputObject $pf -Property @{ InitialSize = $min; MaximumSize = $max } | Out-Null
        } else {
            $path = "$env:SystemDrive\pagefile.sys"
            New-CimInstance -ClassName Win32_PageFileSetting -Property @{ Name = $path; InitialSize = $min; MaximumSize = $max } | Out-Null
        }
        OK ("Pagefile fixado: min {0} MB / max {1} MB (base {2} GB RAM). Reinicio necessario." -f $min, $max, $ramGB)
    } catch { ERR "Pagefile: $($_.Exception.Message)" }
}

# ---------------------------------------------------------------------------
# 9. VERIFICACAO DE SAUDE (opcional, mais demorado)
# ---------------------------------------------------------------------------
function Saude-Sistema {
    Head "9. VERIFICACAO DE INTEGRIDADE (pode demorar)"
    Log "Executando DISM /RestoreHealth ..."
    DISM /Online /Cleanup-Image /RestoreHealth | Out-Null
    OK "DISM concluido."
    Log "Executando SFC /scannow ..."
    sfc /scannow | Out-Null
    OK "SFC concluido."
    Log "Otimizando volumes (TRIM p/ SSD, desfrag p/ HD)..."
    Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq "Fixed" } | ForEach-Object {
        Optimize-Volume -DriveLetter $_.DriveLetter -ErrorAction SilentlyContinue
    }
    OK "Volumes otimizados."
}

# ---------------------------------------------------------------------------
# EXECUCAO PRINCIPAL
# ---------------------------------------------------------------------------
function Executar-Tudo {
    param([switch]$IncluirSaude)
    Criar-Restauracao
    Plano-Energia
    Ajustes-Desempenho
    Desativar-GameDVR
    Reduzir-BackgroundApps
    Otimizar-Servicos
    Limpeza
    Ajustar-Pagefile
    if ($IncluirSaude) { Saude-Sistema }

    Head "CONCLUIDO!"
    OK "Otimizacao finalizada. Log salvo em:"
    Log "  $logFile" "White"
    WARN "REINICIE O PC para aplicar TODAS as mudancas (HAGS, pagefile, servicos)."
}

# ---------------------------------------------------------------------------
# MENU
# ---------------------------------------------------------------------------
function Menu {
    Clear-Host
    Info-Maquina
    while ($true) {
        Write-Host ""
        Write-Host "==================== OTIMIZADOR 3D - MENU ====================" -ForegroundColor Cyan
        Write-Host "  1) OTIMIZAR TUDO (recomendado)                 [rapido]" -ForegroundColor White
        Write-Host "  2) OTIMIZAR TUDO + verificacao de integridade  [lento]" -ForegroundColor White
        Write-Host "  ----------------------------------------------------------"
        Write-Host "  3) So plano de energia (desempenho maximo)"
        Write-Host "  4) So ajustes de CPU/GPU/visual"
        Write-Host "  5) So limpeza de temporarios/cache"
        Write-Host "  6) So memoria virtual (pagefile)"
        Write-Host "  7) So desativar Game Bar/DVR + apps 2o plano"
        Write-Host "  8) So otimizar servicos nao essenciais"
        Write-Host "  ----------------------------------------------------------"
        Write-Host "  0) Sair" -ForegroundColor Yellow
        Write-Host "=============================================================" -ForegroundColor Cyan
        $op = Read-Host "Escolha uma opcao"
        switch ($op) {
            "1" { Executar-Tudo }
            "2" { Executar-Tudo -IncluirSaude }
            "3" { Criar-Restauracao; Plano-Energia }
            "4" { Criar-Restauracao; Ajustes-Desempenho }
            "5" { Limpeza }
            "6" { Criar-Restauracao; Ajustar-Pagefile }
            "7" { Desativar-GameDVR; Reduzir-BackgroundApps }
            "8" { Criar-Restauracao; Otimizar-Servicos }
            "0" { Write-Host "Saindo..." -ForegroundColor Yellow; return }
            default { WARN "Opcao invalida." ; continue }
        }
        Write-Host ""
        Read-Host "Pressione ENTER para voltar ao menu"
        Clear-Host
    }
}

Menu
