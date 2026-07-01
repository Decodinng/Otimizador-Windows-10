<#
============================================================================
  CONFIGURACAO DO PC - Relatorio completo de hardware
  Mostra: Placa-mae, Processador, Placa de video, Memoria RAM,
          SSD/HD, Fonte (quando detectavel) e resumo do sistema.
  Gera tambem um relatorio .txt na mesma pasta.
  Autor: gerado com Claude Code
============================================================================
#>

$ErrorActionPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Pasta de saida (funciona como .ps1 e como .exe compilado)
$pasta = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent ([Environment]::GetCommandLineArgs()[0]) }
if (-not $pasta) { $pasta = "$env:USERPROFILE\Desktop" }
$relatorio = Join-Path $pasta ("Configuracao_PC_{0:yyyy-MM-dd_HH-mm}.txt" -f (Get-Date))

# Buffer para console + arquivo
$sb = New-Object System.Text.StringBuilder
function W {
    param([string]$Txt = "", [string]$Cor = "Gray")
    Write-Host $Txt -ForegroundColor $Cor
    [void]$sb.AppendLine($Txt)
}
function Titulo {
    param([string]$T)
    W ""
    W ("==================== " + $T + " ====================") "Cyan"
}
function Linha {
    param([string]$Rotulo, $Valor)
    if ($null -eq $Valor -or "$Valor".Trim() -eq "") { $Valor = "(nao disponivel)" }
    $r = ($Rotulo + ":").PadRight(22)
    W ("  " + $r + " " + $Valor) "White"
}
function GB { param($bytes) if ($bytes) { "{0:N1} GB" -f ($bytes / 1GB) } else { $null } }

Clear-Host
W "############################################################" "Green"
W "#          RELATORIO DE CONFIGURACAO DO PC                 #" "Green"
W ("#          Gerado em {0,-36}#" -f (Get-Date -Format "dd/MM/yyyy HH:mm:ss")) "Green"
W "############################################################" "Green"

# ---------------------------------------------------------------------------
# SISTEMA / COMPUTADOR
# ---------------------------------------------------------------------------
Titulo "SISTEMA"
$os  = Get-CimInstance Win32_OperatingSystem
$cs  = Get-CimInstance Win32_ComputerSystem
Linha "Nome do PC"     $env:COMPUTERNAME
Linha "Fabricante"     $cs.Manufacturer
Linha "Modelo"         $cs.Model
Linha "Sistema"        ("{0} ({1} bits)" -f $os.Caption, $os.OSArchitecture.Replace('-bit',''))
Linha "Versao/Build"   ("{0} (build {1})" -f $os.Version, $os.BuildNumber)
Linha "Instalado em"   ($os.InstallDate)
Linha "Usuario"        $env:USERNAME

# ---------------------------------------------------------------------------
# PLACA-MAE + BIOS
# ---------------------------------------------------------------------------
Titulo "PLACA-MAE (MOTHERBOARD)"
$mb   = Get-CimInstance Win32_BaseBoard
$bios = Get-CimInstance Win32_BIOS
Linha "Fabricante"     $mb.Manufacturer
Linha "Modelo"         $mb.Product
Linha "Versao"         $mb.Version
Linha "Numero de serie" $mb.SerialNumber
Linha "BIOS/UEFI"      ("{0} {1}" -f $bios.Manufacturer, $bios.SMBIOSBIOSVersion)
Linha "Data da BIOS"   ($bios.ReleaseDate)

# ---------------------------------------------------------------------------
# PROCESSADOR (CPU)
# ---------------------------------------------------------------------------
Titulo "PROCESSADOR (CPU)"
foreach ($cpu in (Get-CimInstance Win32_Processor)) {
    Linha "Modelo"         ($cpu.Name.Trim())
    Linha "Fabricante"     $cpu.Manufacturer
    Linha "Nucleos"        $cpu.NumberOfCores
    Linha "Threads"        $cpu.NumberOfLogicalProcessors
    Linha "Clock base"     ("{0} MHz ({1:N2} GHz)" -f $cpu.MaxClockSpeed, ($cpu.MaxClockSpeed/1000))
    Linha "Soquete"        $cpu.SocketDesignation
    if ($cpu.L2CacheSize) { Linha "Cache L2" ("{0} KB" -f $cpu.L2CacheSize) }
    if ($cpu.L3CacheSize) { Linha "Cache L3" ("{0} KB" -f $cpu.L3CacheSize) }
}

# ---------------------------------------------------------------------------
# PLACA DE VIDEO (GPU)
# ---------------------------------------------------------------------------
Titulo "PLACA DE VIDEO (GPU)"
$gpus = @(Get-CimInstance Win32_VideoController | Where-Object { $_.Name })
$i = 0
foreach ($g in $gpus) {
    $i++
    if ($gpus.Count -gt 1) { W ("  --- GPU #$i ---") "DarkCyan" }
    Linha "Modelo"         $g.Name
    # AdapterRAM estoura em 4GB (limite uint32); tenta ler o valor real do registro
    $vram = $g.AdapterRAM
    $regV = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0*" -Name "HardwareInformation.qwMemorySize" -ErrorAction SilentlyContinue)."HardwareInformation.qwMemorySize"
    if ($regV -and $regV -gt $vram) { $vram = $regV }
    Linha "Memoria de video" (GB $vram)
    Linha "Driver"         $g.DriverVersion
    Linha "Resolucao atual" ("{0} x {1} @ {2} Hz" -f $g.CurrentHorizontalResolution, $g.CurrentVerticalResolution, $g.CurrentRefreshRate)
    Linha "Processador de video" $g.VideoProcessor
}

# ---------------------------------------------------------------------------
# MEMORIA RAM
# ---------------------------------------------------------------------------
Titulo "MEMORIA RAM"
$pentes = @(Get-CimInstance Win32_PhysicalMemory)
$totalRam = ($pentes | Measure-Object -Property Capacity -Sum).Sum
$tipos = @{ 20="DDR"; 21="DDR2"; 24="DDR3"; 26="DDR4"; 34="DDR5" }
$formFactor = @{ 8="DIMM"; 12="SODIMM" }
Linha "Total instalado"  (GB $totalRam)
Linha "Pentes / modulos" ($pentes.Count)
$maxSlots = (Get-CimInstance Win32_PhysicalMemoryArray).MemoryDevices
if ($maxSlots) { Linha "Slots totais"    $maxSlots }
$n = 0
foreach ($p in $pentes) {
    $n++
    W ("  --- Pente #$n ($($p.DeviceLocator)) ---") "DarkCyan"
    Linha "  Capacidade"    (GB $p.Capacity)
    $tipo = $tipos[[int]$p.SMBIOSMemoryType]; if (-not $tipo) { $tipo = $tipos[[int]$p.MemoryType] }
    Linha "  Tipo"          $tipo
    $vel = $null; if ($p.Speed) { $vel = "$($p.Speed) MHz" }
    Linha "  Velocidade"    $vel
    Linha "  Formato"       $formFactor[[int]$p.FormFactor]
    Linha "  Fabricante"    ($p.Manufacturer.Trim())
    Linha "  Part Number"   ($p.PartNumber.Trim())
}

# ---------------------------------------------------------------------------
# ARMAZENAMENTO (SSD / HD)
# ---------------------------------------------------------------------------
Titulo "ARMAZENAMENTO (SSD / HD)"
$fisicos = Get-PhysicalDisk -ErrorAction SilentlyContinue
if ($fisicos) {
    foreach ($d in ($fisicos | Sort-Object DeviceId)) {
        $tipo = switch ($d.MediaType) {
            "SSD"  { "SSD" }
            "HDD"  { "HD (disco rigido)" }
            "SCM"  { "Memoria persistente" }
            default {
                if ($d.SpindleSpeed -eq 0 -or $d.BusType -eq "NVMe") { "SSD" } else { "Desconhecido" }
            }
        }
        if ($d.BusType -eq "NVMe") { $tipo = "SSD NVMe" }
        W ("  --- Disco: $($d.FriendlyName) ---") "DarkCyan"
        Linha "  Tipo"        $tipo
        Linha "  Capacidade"  (GB $d.Size)
        Linha "  Interface"   $d.BusType
        Linha "  Saude"       $d.HealthStatus
    }
} else {
    # Fallback para sistemas antigos
    foreach ($d in (Get-CimInstance Win32_DiskDrive)) {
        W ("  --- Disco: $($d.Model) ---") "DarkCyan"
        Linha "  Capacidade"  (GB $d.Size)
        Linha "  Interface"   $d.InterfaceType
    }
}

# Particoes / letras de unidade e espaco livre
W ""
W "  Unidades (particoes):" "Gray"
foreach ($v in (Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3")) {
    $livre = GB $v.FreeSpace; $tam = GB $v.Size
    W ("    {0}  {1,-9} livre de {2,-9}  {3}" -f $v.DeviceID, $livre, $tam, $v.VolumeName) "White"
}

# ---------------------------------------------------------------------------
# FONTE DE ALIMENTACAO (PSU) / BATERIA
# ---------------------------------------------------------------------------
Titulo "FONTE DE ALIMENTACAO"
$bateria = Get-CimInstance Win32_Battery
if ($bateria) {
    # Notebook
    Linha "Tipo"           "Notebook (bateria detectada)"
    Linha "Bateria"        $bateria.Name
    $carga = $null; if ($bateria.EstimatedChargeRemaining) { $carga = "$($bateria.EstimatedChargeRemaining)%" }
    Linha "Carga atual"    $carga
} else {
    Linha "Tipo"           "Desktop (alimentacao pela tomada)"
}
W ""
W "  OBS: O modelo/potencia (Watts) da fonte de um desktop NAO e" "Yellow"
W "       exposto por software - nao existe sensor para isso." "Yellow"
W "       Para saber, verifique a etiqueta fisica da fonte ou a" "Yellow"
W "       nota fiscal/caixa (ex.: 500W, 600W, 750W 80 Plus)." "Yellow"

# ---------------------------------------------------------------------------
# FINAL
# ---------------------------------------------------------------------------
W ""
W "############################################################" "Green"
W "  Relatorio salvo em:" "Green"
W ("  $relatorio") "White"
W "############################################################" "Green"

# Salva o arquivo .txt
$sb.ToString() | Out-File -FilePath $relatorio -Encoding UTF8

W ""
Read-Host "Pressione ENTER para sair"
