#!/usr/bin/env sh

BOLD="\033[1m"
GREEN="\033[32m"
RED="\033[31m"
ALL_OFF="\033[0m"

error() {
  printf "${BOLD}${RED}ERROR:${ALL_OFF}${BOLD} %s${ALL_OFF}\n" "$1" >&2
  exit 1
}

info() { printf "${BOLD}${GREEN}==>${ALL_OFF}${BOLD} %s${ALL_OFF}\n" "$1" ;}

xbps() { xbps-install -S --yes "$@" ;}

hello() {
  clear
  printf "Bem vindo ao script de instalação do Void Linux\n"
  printf "Antes de começar, vou precisar que me informe o nome do seu usuário\n"

  printf "Usuário: " && read -r name
  [ ! "$(id -u "$name")" ] && error "O usuário ${name} não existe"

  printf "Placa de vídeo [intel/nvidia/amd]: " && read -r video_card

  printf "Beleza %s, vamos começar :)\n" "$name" && sleep 1
}

xbps_config() {

  info "Configurando o xbps"

  # Adding multilib repo
  xbps void-repo-multilib

  # Changing deafault mirror
  mkdir -pv /etc/xbps.d
  cp -v /usr/share/xbps.d/*-repository-*.conf /etc/xbps.d/
  sed -i 's|https://repo-default.voidlinux.org|https://voidlinux.com.br/repo|g' /etc/xbps.d/*-repository-*.conf

  xbps-install -Su --yes
}

services_config() {

  info "Instalando e iniciando serviços"
  xbps dbus elogind ntp NetworkManager cronie

  [ ! -h "/var/service/dbus" ] && ln -vs /etc/sv/dbus /var/service
  [ ! -h "/var/service/elogind" ] && ln -vs /etc/sv/elogind /var/service
  [ ! -h "/var/service/ntpd" ] && ln -vs /etc/sv/ntpd /var/service
  [ ! -h "/var/service/cronie" ] && ln -vs /etc/sv/cronie /var/service

  # Using NetworkManager as it says
  if [ -h "/var/service/dhcpcd" ] || [ -h "/var/service/wpa_supplicant" ]; then
    rm -v /var/service/dhcpcd /var/service/wpa_supplicant
  fi

  ln -vs /etc/sv/NetworkManager /var/service

}

file_struct() {

  info "Montando estrutura de arquivos"
  sudo -u "$name" mkdir -pv \
    /home/"$name"/.config/mpd \
    /home/"$name"/.config/zsh \
    /home/"$name"/.cache/zsh \
    /home/"$name"/.local/src \
    /home/"$name"/.local/state \
    /home/"$name"/.local/share/gnupg \
    /home/"$name"/.local/share/npm/lib \
    /home/"$name"/media/pic \
    /home/"$name"/media/mus \
    /home/"$name"/media/vid \
    /home/"$name"/media/emu \
    /home/"$name"/media/ani \
    /home/"$name"/media/pro \
    /home/"$name"/media/smp \
    /home/"$name"/docx/downloads

  mkdir -pv /mnt/usb1 /mnt/usb2 /mnt/usb3
  # cd /mnt &&
  chown -v -R "$name":"$name" /mnt/*/
}

set_dotfiles() {

  info "Clonando e configurando os dotfiles"
  dotfiles_repo="https://github.com/MisterConscio/dotfiles.git"
  dotdir="/home/$name/dotfiles"

  xbps stow git
  sudo -u "$name" git clone "$dotfiles_repo" "$dotdir"

  cd "$dotdir" || error "'cd ${dotdir}' falhou"
  sudo -u "$name" stow -v */
}

install_pkgs() {

  info "Instalando pacotes do sistema"
  pkg_list="/tmp/pkglist"

  curl -L "https://raw.githubusercontent.com/MisterConscio/mcvoid/main/pkglist" -o "$pkg_list"

  [ ! -f "$pkg_list" ] && error "O arquivo ${pkg_list} não existe"

  xbps $(cat /tmp/pkglist)

  # Graphics card drivers
  case "$video_card" in
    intel)
      xbps xf86-video-intel mesa-vulkan-intel intel-video-accel mesa-dri;;
    nvidia)
      xbps void-repo-nonfree void-repo-multilib-nonfree &&
        xbps nvidia nvidia-libs-32bit;;
    amd)
      xbps vulkan-loader mesa-vulkan-radeon xf86-video-amdgpu mesa-vaapi mesa-vdpau;;
    *) echo "Nenhum driver de vídeo especificado";;
  esac
}

font_config() {

  nerd_font_dir="/home/${name}/.local/share/fonts/otf"
  nerd_font="DroidSansMono"

  mkdir -pv "$nerd_font_dir"
  wget -q -P "$nerd_font_dir" "https://github.com/ryanoasis/nerd-fonts/releases/download/v2.3.3/${nerd_font}.zip"

  unzip "${nerd_font_dir}/${nerd_font}.zip" -d "${nerd_font_dir}/${nerd_font}" &&
    rm -r "$nerd_font_dir"/*.zip

}

final_setup() {

  info "Etapas finais da instalação"

  usermod -aG lp,kvm,storage,i2c "$name"

  chsh -s /usr/bin/zsh "$name"
  chsh -s /usr/bin/zsh root

  # configuração do sudoers
  echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/00-sudo-wheel
  printf "Defaults timestamp_timeout=30\nDefaults timestamp_type=global\n" > /etc/sudoers.d/01-sudo-time
  echo "%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/poweroff,/usr/bin/halt,/usr/bin/reboot,/usr/bin/loginctl suspend,/usr/bin/mount,/usr/bin/umount" > /etc/sudoers.d/02-cmd-nopasswd
  printf "Defaults editor=/usr/bin/nvim" > /etc/sudoers.d/03-visudo-editor

  echo "PROMPT='%F{red}%B%1~%b%f %(!.#.>>) '" > /root/.zshrc

# Configuração do servidor de áudio Jack para uso do Realtime Scheduling
  [ ! -f /etc/security/limits.d/00-audio.conf ] &&
    mkdir -pv /etc/security/limits.d/ &&
    cat << EOF > /etc/security/limits.d/00-audio.conf
# Realtime Scheduling for jack server
@audio   -  rtprio     95
@audio   -  memlock    unlimited
EOF

  # Configuração do teclado no xorg
  [ ! -f "/etc/X11/xorg.conf.d/00-keyboard.conf" ] &&
    mkdir -pv /etc/X11/xorg.conf.d &&
    cat << EOF > /etc/X11/xorg.conf.d/00-keyboard.conf
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "br"
        Option "XkbModel" "abnt2"
        Option "XkbOptions" "terminate:ctrl_alt_bksp"
EndSection
EOF

  rm -rv /home/"$name"/.bash* /home/"$name"/.*rc

}

hello || error "Você digitou alguma coisa errada"
xbps_config || error "Erro ao configurar o xbps"
services_config || error "Erro ao configurar o dbus e network"
file_struct || error "Erro ao criar sistema de arquivos"
set_dotfiles || error "Erro ao configurar os dotfiles"
install_pkgs || error "Erro ao instalar os programas"
font_config || error "Erro ao configurar as fontes"
final_setup || error "Erro ao finalizar o setup"

printf "\nParece que ${GREEN}tudo ocorreu bem %s${ALL_OFF}, pode fazer o reboot do sistema\n" "$name"
