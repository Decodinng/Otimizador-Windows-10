# 🚀 Otimizador de Desempenho — Windows 10 (Modelagem 3D)

Script completo de otimização do **Windows 10** com foco em software de **modelagem 3D e renderização** — Blender, 3ds Max, Maya, ZBrush, SketchUp, Cinema 4D, etc.

Feito para máquinas que já têm bom hardware mas precisam de ajuste fino do sistema. **Tudo é seguro e reversível.**

---

## ⬇️ Como usar

### Opção A — Executável pronto (mais fácil)
1. Baixe o **`Otimizador-3D.exe`** na aba [**Releases**](../../releases).
2. Dê **2 cliques** e clique **"Sim"** no aviso do Controle de Conta de Usuário (UAC).
3. Escolha a opção **1 (OTIMIZAR TUDO)** no menu.
4. **Reinicie o PC** ao terminar.

### Opção B — Rodar o script direto
```powershell
# Clique com botão direito em Otimizar-3D.ps1 > "Executar com o PowerShell"
# ou, num PowerShell como Admin:
powershell -ExecutionPolicy Bypass -File .\Otimizar-3D.ps1
```

### Opção C — Compilar o seu próprio .exe
```powershell
# Clique com botão direito em Compilar-EXE.ps1 > "Executar com o PowerShell"
```
O compilador baixa o módulo gratuito [`ps2exe`](https://github.com/MScholtes/PS2EXE) e gera o `.exe` com manifesto de admin embutido.

---

## 🛠️ O que o script faz (tudo reversível)

| # | Otimização | Benefício para 3D |
|---|------------|-------------------|
| 1 | **Ponto de restauração** antes de tudo | Segurança / rollback |
| 2 | Plano de energia **Desempenho Máximo** | CPU 100%, sem suspender USB (Wacom), PCI-E sem economia |
| 3 | **HAGS** + **TDR aumentado (10s)** | Menos crashes de GPU em cenas/renders pesados |
| 3 | **Power Throttling desligado** | Windows não estrangula Blender/Maya/ZBrush |
| 3 | Prioridade da CPU p/ programas | Viewport mais responsivo |
| 4 | **Game Bar / Game DVR** desativados | Libera recursos da GPU |
| 5 | Apps em segundo plano + sugestões reduzidos | Menos RAM/CPU desperdiçados |
| 6 | Serviços não essenciais em **Manual** | Xbox/telemetria não sobem sozinhos |
| 7 | Limpeza de temporários/cache/lixeira/DNS | Espaço em disco liberado |
| 8 | **Pagefile** ajustado (RAM → 1.5× RAM) | Evita "out of memory" em render |
| 9 | (Opcional) SFC/DISM + TRIM/desfrag | Integridade e discos otimizados |

Cada execução gera um **log** `.log` na pasta com tudo que foi feito.

---

## ⚠️ Avisos

- **Não** desinstala drivers, **não** apaga programas, **não** desativa Windows Update nem antivírus.
- Serviços vão para **Manual** (não são removidos).
- Se algo não agradar, use a **Restauração do Sistema** (o ponto é criado no início).
- **SmartScreen:** por ser um `.exe` sem assinatura digital paga, pode aparecer *"Windows protegeu seu PC"* → **Mais informações** → **Executar assim mesmo**. É normal.

---

## 📄 Licença

MIT — use, modifique e distribua livremente.
