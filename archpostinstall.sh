#/bin/sh

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root." >&2
    exit 1
fi

echo "
Enable Multilib repository"
sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
sudo pacman -Syu

echo "
Install: boot manager + splash screen"
pacman -S --needed --noconfirm refind plymouth

echo "
Install: shell + login manager"
pacman -S --needed --noconfirm noctalia noctalia-greeter

echo "
Install: base tools"
pacman -S --needed --noconfirm git base-devel dkms linux-zen linux-zen-headers make gcc rust nodejs npm python-pip libei 

echo "
Install: audio/video" # (we need the dkms driver because if we use the zen kernel then we need to compile the driver)
pacman -S --needed --noconfirm  pipewire pipewire-pulse wireplumber bluez bluez-utils nvidia-open-dkms nvidia-settings

echo "
Install: wayland compositor (and window manager)"
#pacman -S --needed --noconfirm libxkbcommon systemd-libs libinput mesa seatd libxcb xcb-util-cursor xorg-xwayland clang
pacman -S --needed --noconfirm xorg-xwayland xwayland-satellite libinput xdg-desktop-portal
# Umbriel is not in repo yet so need to install via: git clone https://aur.archlinux.org/packages/umbriel-git

echo "
Install: CLI tools"
pacman -S --needed --noconfirm pciutils sudo-rs uutils-coreutils ntpd-rs bottom rustnet netscanner fish vim nvtop iotop-c bc 7zip tar fio tuned scx-scheds wlr-randr

echo "
Install: GUI tools"
pacman -S --needed --noconfirm zed kitty steam qbittorrent discord doublecmd-qt6 meld kodi mpv handbrake mkvtoolnix-gui hardinfo2 cpu-x

echo "
Install: fonts"
pacman -S --needed --noconfirm ttf-font-nerd ttf-roboto inter-font ttf-liberation otf-libertinus adobe-source-serif-fonts adobe-source-sans-fonts ttf-caladea texlive-fontsextra texlive-latexextra
# jetbrains is for terminal/notepad, roboto and inter are for menus (similar to SanFrancisco Display), liberation is for Microsoft Windows compatilibity, Caladea is compatible with cambria
# Preferred font with Nerd update for terminal, notepad and system monospace font: JetBrains Mono Nerd
#    All of these are sans serif (nem talpas) my second choice is Hack
#    - Fira Code (derived from Mozialla Fira Mono) released 2014 updated 2022, has programming ligatures e.g. !=, widest of the three
#    - Hack (derived from DejaVu) released 2015, updated 2018, no programming ligatures e.g. !=
#    - JetBrains Mono: released 2020 updated 2023, has programming ligatures e.g. != has nicer 19*><% , narrowest of the three
# Preferred font for menu: SF Pro Display or Inter as my second choice (Noto Sans and Roboto are also good)

echo "
Install: Simagic DKMS Driver"
git clone https://github.com/JacKeTUs/simagic-ff.git
sudo cp -r simagic-ff /usr/src/simagic-ff
sudo dkms install /usr/src/simagic-ff
sudo modprobe hid_simagic_ff
dkms status

echo "Enable sudo"
sed -i 's/^# *\(%wheel ALL=(ALL:ALL) ALL\)$/\1/' /etc/sudoers
visudo -c

# Enable login manager on virtual terminal 1
# cp greetd-config.toml /etc/greetd/config.toml
# Regreet style to transparent bg so the video shows through
# cp greetd-regreet.css /etc/greetd/regreet.css
# USE NOCTUA GREETER INSTEAD


# TODO: Shojiwm fade in/out for start and finish. Can be used both by login manager and normal session
# TODO: ReGreet liquid glass look and mpvpaper video loop playback
# TODO: quiet login with no character mode showing not even blinking cursor:
# quiet loglevel=3 systemd.show_status=false rd.udev.log_level=3 vt.global_cursor_default=0 splash

# TODO: Splash:
# 1. Add plymouth to HOOKS in /etc/mkinitcpio.conf, after base udev (and before encrypt or filesystems if you use them). Then:
# sh
# sudo plymouth-set-default-theme -R bgrt   # bgrt shows your motherboard/OEM logo
# or: spinner, or install a custom theme
#
# Remaining text with greetd. Anything that prints to tty1 can flash briefly before the greeter starts. Plymouth handles most of it, but you can also add console=tty2 on the kernel line to move kernel console output off the greeter’s VT.
# Check: after editing refind.conf, nothing needs regenerating. For the initramfs and kernel line changes, rebuild with sudo mkinitcpio -P and reboot.

mv refind-theme /boot/EFI/refind/themes
echo "Add: include themes/rEFInd-minimal/theme.conf at th end of refind.conf"
echo "Add: mitigations=off usbcore.autosuspend=-1 to refind_linux.conf. Press Enter to continue..."; read dummy
vi /boot/refind_linux.conf

echo "
Check if boot parameters are present: mitigations=off usbcore.autosuspend=-1"
cat /proc/cmdline
sleep 1

echo "
Check if Spectre and Meltdown mitigations are really off"
grep -r . /sys/devices/system/cpu/vulnerabilities/
sleep 1

sudo systemctl enable --now scx.service
echo "
Kernel scheduler should be lavd (Latency-critical Aware Voluntary Deprioritization)"
cat /sys/kernel/sched_ext/root/ops
sleep 1

echo "
Scheduler extension should be enabled"
cat /sys/kernel/sched_ext/state
sleep 1

echo "
IO Scheduler should be: bfq"
cat /sys/block/sda/queue/scheduler
sleep 1

printf "Press Enter to continue..."; read dummy

echo "
Network scheduler should be fq_codel (fights bufferbloat, fair queuing per flow)"
sysctl net.core.default_qdisc

echo "
Kernel ticker should be 1000"
zgrep -E 'CONFIG_HZ|CONFIG_PREEMPT|CONFIG_NO_HZ' /proc/config.gz
sleep 1

# swapon --show
# Should be no output (swap disabled)

echo "
Disabled USB auto suspend should show: -1"
cat /sys/module/usbcore/parameters/autosuspend
sleep 1

echo "
Kernel should be: zen"
uname -a
sleep 1

echo "
Check if we have NTSYNC compiled in kernel and loaded"
ls -l /dev/ntsync
lsmod | grep ntsync
sleep 1

#systemctl --user enable --now pipewire pipewire-pulse wireplumber
#sleep 1
#wpctl status
# Check if audio device works

sudo systemctl enable --now tuned.service
tuned-adm profile latency-performance
echo "
CPU Power governor should be: latency-performance"
tuned-adm active

echo "
Check: mouse polling rate should be 1000Hz to have low latency input"
sudo awk '/^S:.*Product=/{prod=$0; sub(/^S:.*Product=/,"",prod)} /^I:.*Cls=03\(HID/{if ($0~/Prot=01/) type="Keyboard"; else if ($0~/Prot=02/) type="Mouse"; else type=""} /^E:.*Ivl=/{if(type!=""){match($0,/Ivl=[0-9]+/); ivl=substr($0,RSTART+4,RLENGTH-4); if(ivl+0>0) printf "%-30s %-10s %sms -> %.0fHz\n", prod, type, ivl, 1000/ivl; type=""}}' /sys/kernel/debug/usb/devices

printf "Press Enter to continue..."; read dummy

echo "
Create new user"
read -rp "Username: " username
useradd -m -G wheel -s /usr/bin/fish "$username"
passwd "$username"
sudo systemctl enable --now seatd
# Add user and enable rootless GPU resource access
sudo usermod -aG seat $username
sudo chown -R $username $(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd) # change ownership of the postinstall files to be under the new user
su - $username
# Add Umbriel configuration
mkdir -p ~/.config/umbriel
mv umbriel-config.toml ~/.config/umbriel/config.toml
touch ~/.config/umbriel/outputs.generated.toml
mkdir -p ~/.local/bin
mv umbriel-outputs-gen ~/.local/bin/umbriel-outputs-gen
chmod +x ~/.local/bin/umbriel-outputs-gen
# Add Noctalia configuration
mkdir -p ~/.config/noctalia/
mv noctalia-config.toml ~/.config/noctalia/config.toml
mkdir -p ~/.config/fish/
mv config.fish ~/.config/fish/config.fish

echo "
Create Applications folder for AppImages" # and a service that automatically makes them executable
mkdir -p ~/Applications
mkdir -p ~/.config/systemd/user
cp appimage-chmod.service ~/.config/systemd/user/appimage-chmod.service
cp appimage-chmod.path ~/.config/systemd/user/appimage-chmod.path
systemctl --user daemon-reload
systemctl --user enable --now appimage-chmod.path
