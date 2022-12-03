#!/usr/bin/env sh

error() {
  printf "%s\n" "$1" >&2
  exit 1
}

hello() {
  clear
  printf \
    "Bem vindo ao script de instalação do Void Linux
Antes de começar, vou precisar que me informe o nome do seu usuário\n"

  printf "Usuário: " && read -r name
  [ ! "$(id -u "$name")" ] && error "O usuário ${name} não existe"

  printf "Beleza %s, vamos começar :)\n" "$name" && sleep 1
}

# system_update() {
#   xbps-install -Su --yes xbps && xbps-install -Su --yes
# }

xbps_config() {
  # Adding multilib repo
  xbps-install -S --yes void-repo-multilib

  # Changing deafault mirror
  # mkdir -pv /etc/xbps.d
  # cp -v /usr/share/xbps.d/*-repository-*.conf /etc/xbps.d/
  # sed -i 's|https://repo-default.voidlinux.org|https://voidlinux.com.br/repo|g' /etc/xbps.d/*-repository-*.conf

  xbps-install -Su --yes
}

services_config() {
  xbps-install -S --yes dbus elogind ntp NetworkManager

  [ ! -h "/var/service/dbus" ] && ln -vs /etc/sv/dbus /var/service
  [ ! -h "/var/service/elogind" ] && ln -vs /etc/sv/elogind /var/service
  [ ! -h "/var/service/ntpd" ] && ln -vs /etc/sv/ntpd /var/service

  # Using NetworkManager as it says
  if [ -h "/var/service/dhcpcd" ] || [ -h "/var/service/wpa_supplicant" ]; then
    rm -v /var/service/dhcpcd /var/service/wpa_supplicant
    ln -vs /etc/sv/NetworkManager /var/service
  else
    ln -vs /etc/sv/NetworkManager /var/service
  fi
}

file_struct() {
  sudo -u "$name" mkdir -pv \
    /home/"$name"/.config/mpd \
    /home/"$name"/.cache/zsh \
    /home/"$name"/.local/src \
    /home/"$name"/.local/state \
    /home/"$name"/.local/share/gnupg \
    /home/"$name"/media/pic \
    /home/"$name"/media/mus \
    /home/"$name"/media/vid \
    /home/"$name"/media/emu \
    /home/"$name"/media/ani \
    /home/"$name"/media/pro \
    /home/"$name"/media/smp \
    /home/"$name"/docx/downloads

  mkdir -pv /mnt/usb1 /mnt/usb2 /mnt/usb3
  cd /mnt && chown -v -R "$name":"$name" ./*/
}

set_dotfiles() {
  dotfiles_repo="https://github.com/MisterConscio/dotfiles.git"
  dotdir="/home/$name/dotfiles"

  xbps-install -S --yes stow git
  sudo -u "$name" git clone "$dotfiles_repo" "$dotdir"

  cd "$dotdir" || error "'cd ${dotdir}' falhou"
  sudo -u "$name" stow -v */
}

install_pkgs() {
  curl -L "https://raw.githubusercontent.com/MisterConscio/MCVOID/main/pkglist" \
    -o /tmp/pkglist
  [ ! -f "/tmp/pkglist" ] && error "O arquivo pkglist não existe"

  # while read -r pkg; do
  #   pkg_list="$pkg "
  # done < /tmp/pkglist

  xbps-install -S --yes $(cat /tmp/pkglist)
}

final_setup() {
  usermod -aG lp,kvm,storage,i2c "$name"

  chsh -s /usr/bin/zsh "$name"
  chsh -s /usr/bin/zsh root

  # configuração do sudoers
  echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/00-sudo-wheel
  printf "Defaults timestamp_timeout=30\nDefaults timestamp_type=global" > /etc/sudoers.d/01-sudo-time
  echo "%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/poweroff,/usr/bin/halt,/usr/bin/reboot,/usr/bin/loginctl suspend,/usr/bin/mount,/usr/bin/umount" > /etc/sudoers.d/02-cmd-nopasswd
  echo "Defaults editor=/usr/bin/nvim" > /etc/sudoers.d/03-visudo-editor

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

  rm -rv \
    /home/"$name"/.bash* \
    /home/"$name"/.inputrc

  mv -v /home/"$name"/.gnupg /home/"$name"/.local/share/gnupg
}

hello || error "Você digitou alguma coisa errada"
# system_update || error "Erro ao atualizar o sistema"
xbps_config || error "Erro ao configurar o xbps"
services_config || error "Erro ao configurar o dbus e network"
file_struct || error "Erro ao criar sistema de arquivos"
set_dotfiles || error "Erro ao configurar os dotfiles"
install_pkgs || error "Erro ao instalar os programas"
final_setup || error "Erro ao finalizar o setup"

printf "\nParece que tudo ocorreu bem %s, pode fazer o reboot do sistema\n" "$name"
