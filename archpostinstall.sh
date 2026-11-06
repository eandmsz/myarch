#/bin/sh

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root." >&2
    exit 1
fi

# Enable Multilib repo
sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
sudo pacman -Syu

# Boot manager and splash screen
pacman -S --needed --noconfirm refind plymouth

# Login manager
pacman -S --needed --noconfirm greetd-regreet
pacman -S --needed --noconfirm noctalia-greeter

# Base system tools
pacman -S --needed --noconfirm git base-devel dkms linux-zen linux-zen-headers make gcc rust nodejs npm python-pip libei 

# Audio and Video (we need the dkms driver because if we use the zen kernel then we need to compile the driver)
pacman -S --needed --noconfirm  pipewire pipewire-pulse wireplumber bluez bluez-utils nvidia-open-dkms nvidia-settings

# Compositor (ShojiWM) requirements
#pacman -S --needed --noconfirm libxkbcommon systemd-libs libinput mesa seatd libxcb xcb-util-cursor xorg-xwayland clang
# Wayland Compositor (and Window Manager)
pacman -S --needed --noconfirm xorg-xwayland xwayland-satellite libinput xdg-desktop-portal
# Umbriel is not in repo yet

# Shell
pacman -S --needed --noconfirm noctalia

# CLI Tools
pacman -S --needed --noconfirm pciutils sudo-rs uutils-coreutils ntpd-rs bottom rustnet netscanner fish vim nvtop iotop-c bc 7zip tar fio tuned scx-scheds wlr-randr

# GUI Tools
pacman -S --needed --noconfirm zed kitty steam qbittorrent discord doublecmd-qt6 meld kodi mpv handbrake mkvtoolnix-gui hardinfo2 cpu-x

# Fonts
pacman -S --needed --noconfirm ttf-font-nerd ttf-roboto inter-font ttf-liberation otf-libertinus adobe-source-serif-fonts adobe-source-sans-fonts ttf-caladea texlive-fontsextra texlive-latexextra
# jetbrains is for terminal/notepad, roboto and inter are for menus (similar to SanFrancisco Display), liberation is for Microsoft Windows compatilibity, Caladea is compatible with cambria
# Preferred font with Nerd update for terminal, notepad and system monospace font: JetBrains Mono Nerd
#    All of these are sans serif (nem talpas) my second choice is Hack
#    - Fira Code (derived from Mozialla Fira Mono) released 2014 updated 2022, has programming ligatures e.g. !=, widest of the three
#    - Hack (derived from DejaVu) released 2015, updated 2018, no programming ligatures e.g. !=
#    - JetBrains Mono: released 2020 updated 2023, has programming ligatures e.g. != has nicer 19*><% , narrowest of the three
# Preferred font for menu: SF Pro Display or Inter as my second choice (Noto Sans and Roboto are also good)
printf "Press Enter to continue..."; read dummy

# Install Simagic Driver kernel module
git clone https://github.com/JacKeTUs/simagic-ff.git
sudo cp -r simagic-ff /usr/src/simagic-ff
sudo dkms install /usr/src/simagic-ff
sudo modprobe hid_simagic_ff
dkms status

# Enable sudo
sed -i 's/^# *\(%wheel ALL=(ALL:ALL) ALL\)$/\1/' /etc/sudoers
visudo -c

printf "Press Enter to continue..."; read dummy

# Enable login manager on virtual terminal 1
# cp greetd-config.toml /etc/greetd/config.toml
# Regreet style to transparent bg so the video shows through
# cp greetd-regreet.css /etc/greetd/regreet.css
# USE NOCTUA GREETER INSTEAD

printf "Press Enter to continue..."; read dummy

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


# TODO:
#cat /proc/cmdline
    # Check if boot params were applied: mitigations=off irqaffinity=0-6,8-14 nohz_full=7,15 isolcpus=7,15 rcu_nocbs=7,15 usbcore.autosuspend=-1
#grep -r . /sys/devices/system/cpu/vulnerabilities/
    # Check if Spectre and Meltdown mitigations are really off

#printf "Press Enter to continue..."; read dummy
#watch -n 0.5 'ps -eLo pid,tid,psr,comm | awk "\$3 == 7"'
    # Check what is running on core7 should be only your graphical shell
#watch -n 0.5 'ps -eLo pid,tid,psr,comm | awk "\$3 == 15"'
    # Check what is running on core15 should be only your compositor
#cat /proc/interrupts
    # Check if no interrupts ended up on core7 and core15

echo "Scheduler extension should be enabled"
cat /sys/kernel/sched_ext/state

printf "Press Enter to continue..."; read dummy

sudo systemctl enable --now scx.service
echo "Kernel scheduler should be lavd (Latency-critical Aware Voluntary Deprioritization)"
cat /sys/kernel/sched_ext/root/ops

printf "Press Enter to continue..."; read dummy

echo "IO Scheduler should be [bfq]"
cat /sys/block/sda/queue/scheduler

printf "Press Enter to continue..."; read dummy

echo "Network scheduler should be fq_codel (fights bufferbloat, fair queuing per flow)"
sysctl net.core.default_qdisc

echo "Kernel ticker should be 1000"
grep 'CONFIG_HZ=' /boot/config-$(uname -r)

# swapon --show
# Should be no output (swap disabled)

printf "Press Enter to continue..."; read dummy

echo "Disabled USB auto suspend should show: -1
cat /sys/module/usbcore/parameters/autosuspend

echo "Check if we have NTSYNC compiled in kernel and loaded"
ls -l /dev/ntsync
lsmod | grep ntsync

#systemctl --user enable --now pipewire pipewire-pulse wireplumber
#sleep 1
#wpctl status
# Check if audio device works

echo "DKMS Modules"
dkms status

printf "Press Enter to continue..."; read dummy

sudo systemctl enable --now tuned.service
echo "CPU Power governor should be: latency-performance"
tuned-adm active

echo "Kernel should be zen"
uname -a

printf "Press Enter to continue..."; read dummy

echo "Mouse polling rate should be 1000Hz for low latency input"
sudo awk '/^S:.*Product=/{prod=$0; sub(/^S:.*Product=/,"",prod)} /^I:.*Cls=03\(HID/{if ($0~/Prot=01/) type="Keyboard"; else if ($0~/Prot=02/) type="Mouse"; else type=""} /^E:.*Ivl=/{if(type!=""){match($0,/Ivl=[0-9]+/); ivl=substr($0,RSTART+4,RLENGTH-4); if(ivl+0>0) printf "%-30s %-10s %sms -> %.0fHz\n", prod, type, ivl, 1000/ivl; type=""}}' /sys/kernel/debug/usb/devices

# Add user and enable rootless GPU resource access
read -rp "Username: " username
useradd -m -G wheel -s /usr/bin/fish "$username"
passwd "$username"
sudo systemctl enable --now seatd
sudo usermod -aG seat $username
su - $username
mkdir -p ~/.config/umbriel
echo '[general]
autostart = ["noctalia"]' > ~/.config/umbriel/config.toml

# Create Applications folder for AppImages and a service that automatically makes them executable
mkdir -p ~/Applications
mkdir -p ~/.config/systemd/user
cp appimage-chmod.service ~/.config/systemd/user/appimage-chmod.service
cp appimage-chmod.path ~/.config/systemd/user/appimage-chmod.path
systemctl --user daemon-reload
systemctl --user enable --now appimage-chmod.path
