# Linux no Acer Chromebook 11 C731

Guia para deixar o Linux mais leve e funcional no **Acer Chromebook 11 C731**
(modelo C731-C9DA, placa `RELM`, fabricado em 02/2019).

| Item | Especificação | Consequência prática |
|------|---------------|----------------------|
| CPU | Intel Celeron N3060, 2 núcleos, até 2,48 GHz | Fraca: evite ambientes gráficos pesados |
| RAM | 4 GB (soldada, não expande) | Use **zram** e um navegador enxuto |
| Disco | eMMC de 16 ou 32 GB | Pouco espaço; evite Snap/Flatpak em excesso |
| Vídeo | Intel HD 400 (Braswell) | Driver VA-API **i965** para vídeo por hardware |
| Tela | 11,6" 1366×768 | Escala 100% |

## 1. Rodar o script de otimização

```bash
git clone https://github.com/mantiniDev/cromebook.git
cd cromebook

bash otimizar.sh --info     # só mostra o diagnóstico, não altera nada
sudo bash otimizar.sh       # pergunta antes de cada passo
```

O script (apt, dnf ou pacman) faz:

1. **zram** — swap comprimido na RAM (zstd, 60% da RAM). É o maior ganho.
2. **sysctl** — `swappiness=150`, `page-cluster=0`, `vfs_cache_pressure=50`.
3. **earlyoom** — mata o processo mais pesado antes de o sistema congelar
   (pulado se a distro já usa `systemd-oomd`).
4. **eMMC** — TRIM semanal (`fstrim.timer`) e logs limitados a 50 MB.
5. **TLP + thermald** — mais bateria e menos aquecimento.
6. **Driver de vídeo i965** — vídeos usam a GPU em vez da CPU.
7. **Serviços** — oferece desativar ModemManager, impressão, Bluetooth, Avahi.
8. **Snap** (só Ubuntu/Lubuntu) — remove o Snap e instala o Firefox `.deb`
   direto do repositório da Mozilla, copiando seu perfil (favoritos, senhas).
   Feche o Firefox antes.
9. **Limpeza** — remove pacotes órfãos e cache.

Todos os arquivos criados têm "chromebook" no nome:
`/etc/sysctl.d/99-chromebook.conf`, `/etc/systemd/journald.conf.d/00-chromebook.conf`,
`/etc/environment.d/90-chromebook-vaapi.conf`. Para desfazer um ajuste, basta
apagar o arquivo e reiniciar.

## 2. Escolha da distro / ambiente gráfico

GNOME e KDE Plasma funcionam, mas ficam lentos com essa CPU e 4 GB.
Melhores opções, da mais fácil para a mais leve:

- **Linux Mint Xfce** ou **Xubuntu** — Xfce, fácil e estável.
- **Lubuntu** ou **Fedora LXQt** — LXQt, ainda mais leve.
- **MX Linux (Xfce)** ou **antiX** — muito leves, ótimas para hardware antigo.

Se já instalou Ubuntu com GNOME e não quer reinstalar:

```bash
sudo apt install xubuntu-core   # depois escolha "Xfce" na tela de login
```

### Remover o Snap (Ubuntu e derivados)

O Snap ocupa centenas de MB e deixa a abertura de programas mais lenta.
No Linux Mint ele já vem desativado. No Ubuntu/Xubuntu/Lubuntu, o passo 8 do
script faz a troca automaticamente.

### Lubuntu 24.04 (LXQt 1.4) — o sistema atual

O Lubuntu já é uma das opções mais leves; não precisa trocar de distro.
Ordem sugerida:

1. `sudo apt update && sudo apt full-upgrade`, depois reinicie.
2. `sudo bash otimizar.sh` aceitando os padrões (zram, earlyoom, TRIM, TLP,
   vídeo, ModemManager e remoção do Snap fazem a maior diferença).
3. Reinicie e confira com `bash otimizar.sh --info`: deve aparecer
   `/dev/zram0` no swap.
4. Ajustes no LXQt (menu → Preferências → Configurações do LXQt):
   - **Configurações da sessão → Inicialização automática**: desmarque o que
     não usa (ex.: notificador de atualizações, Qlipper/área de transferência,
     applet de Bluetooth se não usa).
   - **Configurações da sessão → Gerenciador de janelas**: mantenha o
     Openbox, sem compositor (picom), que gasta CPU/GPU.
   - **Aparência**: tema e ícones simples; evite papel de parede animado.
5. Instale programas pelo terminal (`sudo apt install ...`) em vez do
   Discover, que é pesado.
6. O `keyd` não está nos repositórios do 24.04: compile do GitHub (seção 5)
   ou espere a próxima LTS.

## 3. Navegador (o que mais pesa no dia a dia)

- Use **Firefox** ou **Chromium** com **uBlock Origin** — anúncios são boa
  parte do consumo de CPU.
- Mantenha poucas abas abertas; no Firefox, `about:unloads` libera abas.
- Ative a aceleração de vídeo:
  - Firefox: em `about:config`, `media.ffmpeg.vaapi.enabled = true`.
  - Chromium: em `chrome://flags`, ative "Hardware-accelerated video decode".
- No YouTube, a extensão **enhanced-h264ify** força H.264, que a GPU HD 400
  decodifica (VP9/AV1 ela não decodifica e a CPU sofre).
- Confira se a aceleração está funcionando com `vainfo`.

## 4. Áudio

O áudio dos Chromebooks Braswell normalmente **não funciona de primeira** no
Linux. A solução mantida pela comunidade é o script:

```bash
git clone https://github.com/WeirdTreeThing/chromebook-linux-audio
cd chromebook-linux-audio
./setup-audio
```

Reinicie depois. Leia o README do projeto antes, pois ele muda a cada versão.
Testado no C731 com Lubuntu 24.04: o som passou a funcionar.

## 5. Teclas do Chromebook

A fileira de cima envia F1–F10 e não existe tecla Super/Caps Lock.
O **keyd** remapeia isso (volume, brilho, Caps Lock na tecla de busca):

- Debian 13+/Ubuntu 25.04+: `sudo apt install keyd`
- Arch: `sudo pacman -S keyd`
- Outras: compilar de https://github.com/rvaiya/keyd

Exemplo de `/etc/keyd/default.conf`:

```ini
[ids]
*

[main]
f1 = back
f2 = forward
f3 = refresh
f6 = brightnessdown
f7 = brightnessup
f8 = mute
f9 = volumedown
f10 = volumeup
leftmeta = overload(meta, capslock)

[meta]
f1 = f1
f2 = f2
f3 = f3
f6 = f6
f7 = f7
f8 = f8
f9 = f9
f10 = f10
```

Ative com `sudo systemctl enable --now keyd`. Depois disso, tocar na tecla
Busca funciona como Caps Lock e segurar Busca + F1…F10 envia as teclas F
normais.

## 6. Firmware (se ainda estiver usando o modo desenvolvedor / Legacy)

No C731 deste guia o firmware UEFI do MrChromebox já está instalado
(`otimizar.sh --info` mostra "coreboot MrChromebox"); nesse caso pule esta seção.

Se o Chromebook ainda mostra a tela "OS verification is OFF" a cada boot, o
ideal é instalar o firmware **UEFI Full ROM** do MrChromebox (suporta a placa
`RELM`): o boot fica normal, sem aviso, e o Linux ganha suporte melhor.

- Site: https://docs.mrchromebox.tech
- No C731 é preciso **remover o parafuso de write-protect** dentro do
  notebook antes de gravar.
- Isso remove o ChromeOS e há risco de deixar o aparelho sem ligar se algo der
  errado. Leia a documentação inteira e **faça o backup do firmware** que o
  próprio script oferece.

## 7. Boot mais rápido

No C731 com Lubuntu 24.04 estes dois serviços atrasavam o boot sem necessidade:

```bash
# espera a internet conectar antes de seguir o boot
sudo systemctl disable NetworkManager-wait-online.service
# só a tela de login (sddm) dependia dele; custava ~7,5 s
sudo systemctl mask systemd-udev-settle.service
```

Se a tela de login não aparecer depois disso: Ctrl+Alt+F2 (tecla →),
entre com usuário e senha e rode
`sudo systemctl unmask systemd-udev-settle.service && sudo reboot`.

Resultado medido (`systemd-analyze`): tela de login em ~16 s, boot completo
em ~18,5 s. O que sobra no caminho (NetworkManager, dbus) não vale a pena
mexer.

## 8. Ajustes extras (manuais)

- **`noatime` no `/etc/fstab`**: reduz escritas no eMMC. Na linha da partição
  `/`, troque `defaults` por `defaults,noatime`. Faça um backup antes
  (`sudo cp /etc/fstab /etc/fstab.bak`) — um erro nesse arquivo impede o boot.
- **Programas na inicialização**: em Xfce, Configurações → Sessão e
  Inicialização → Inicialização automática; desative o que não usa.
- **Programas leves**: Mousepad/Geany (texto), Ristretto (imagens),
  mpv (vídeo), Thunar/PCManFM (arquivos).
- **Python**: para estudar, VS Code é pesado; **Geany** ou **Thonny** são
  bem mais leves nesse hardware.
