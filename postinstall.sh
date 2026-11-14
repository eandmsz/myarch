#!/usr/bin/env fish

# During the Calamares installer:
# ext4 partition
# refind boot loader

# To execute post install:
# ------------------------
# sudo su -
# git clone https://github.com/eandmsz/distrosetup
# cd distrosetup
# chmod +x postinstall.sh
# ./postinstall.sh

# Crossout steam launch params:  __GL_SHADER_DISK_CACHE_SIZE=10737418240 __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1 %command%
# CachyOS is much faster than Fedora and doesn't need any tweaking. Fast desktop animations, responsive desktop, better colors, net/io/kernel schedulers well chosen, 1000Hz kernel ticker and mouse polling, everything working oob


if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root." >&2
    exit 1
fi

set_color green; echo "Installing software"; set_color normal; 
pacman -Syyu --noconfirm
cachyos-rate-mirrors
pacman -S --needed --noconfirm linux-cachyos-bore linux-cachyos-bore-headers linux-cachyos-bore-nvidia-open nvidia-utils steam brave-bin doublecmd-qt6 zed veracrypt dkms python-pip qbittorrent discord nvtop iotop-c bc 7zip fio kodi handbrake mkvtoolnix-gui hardinfo2 cpu-x

# maybe later: pciutils sudo-rs uutils-coreutils ntpd-rs bottom rustnet netscanner


# These are installed by default: plymouth wayland pipewire wireplumber pipewire-pulse git python3 bluez bluez-utils npm gcc make meld fish vim cifs-utils tar mpv

echo "Run: vim /boot/EFI/refind/refind.conf
Add:
default_selection 'vmlinuz-linux-cachyos-bore'
fold_linux_kernels false"


echo "Run: vim /boot/refind_linux.conf
Add:
mitigations=off usbcore.autosuspend=-1"


###################################3
#Migrate arch linux settings to cachyos:
#

#echo "
#Enable Multilib repository"
#sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
#pacman -Syu

#echo "
#Install: boot manager + splash screen"
#pacman -S --needed --noconfirm refind plymouth

#mv refind-theme /boot/EFI/refind/themes/dark-minimal
#echo "include themes/dark-minimal/theme.conf >> /boot/EFI/refind/refind.conf"
#echo "mitigations=off usbcore.autosuspend=-1 quiet" >> /boot/refind_linux.conf

#mkdir -p /usr/share/plymouth/themes
#mv plymouth-theme /usr/share/plymouth/themes/arch-pulse
#plymouth-set-default-theme -R arch-pulse

#echo "
#Install: shell + login manager"
#pacman -S --needed --noconfirm noctalia noctalia-greeter

#echo "
#Install: base tools"
#pacman -S --needed --noconfirm git base-devel dkms linux-cachyos-bore linux-cachyos-bore-headers make gcc rust nodejs npm python-pip libei 

#echo "
#Install: audio/video"
#pacman -S --needed --noconfirm  pipewire pipewire-pulse wireplumber bluez bluez-utils linux-cachyos-bore-nvidia-open nvidia-settings

#echo "
#Install: wayland compositor (and window manager)"
#pacman -S --needed --noconfirm xorg-xwayland xwayland-satellite libinput xdg-desktop-portal-umbriel umbriel

#echo "
#Install: CLI tools"
#pacman -S --needed --noconfirm pciutils sudo-rs uutils-coreutils ntpd-rs bottom rustnet netscanner fish vim nvtop iotop-c bc 7zip tar fio tuned wlr-randr cifs-utils

#echo "
#Install: GUI tools"
#pacman -S --needed --noconfirm zed kitty servo zen-browser brave-bin cachyos-gaming-meta qbittorrent discord doublecmd-qt6 meld kodi mpv handbrake mkvtoolnix-gui hardinfo2 cpu-x veracrypt

set_color green; echo "Installing fonts"; set_color normal; 
pacman -S --needed --noconfirm ttf-jetbrains-mono-nerd ttf-firacode-nerd ttf-hack-nerd ttf-roboto-mono-nerd ttf-roboto inter-font ttf-liberation ttf-liberation-mono-nerd otf-libertinus adobe-source-serif-fonts adobe-source-sans-fonts ttf-caladea texlive-fontsextra texlive-latexextra noto-fonts ttf-bigblueterminal-nerd ttf-opensans
# jetbrains is for terminal/notepad, roboto and inter are for menus (similar to SanFrancisco Display), liberation is for Microsoft Windows compatilibity, Caladea is compatible with cambria
# Preferred font with Nerd update for terminal, notepad and system monospace font: JetBrains Mono Nerd
#    All of these are sans serif (nem talpas) my second choice is Hack
#    - Fira Code (derived from Mozialla Fira Mono) released 2014 updated 2022, has programming ligatures e.g. !=, widest of the three
#    - Hack (derived from DejaVu) released 2015, updated 2018, no programming ligatures e.g. !=
#    - JetBrains Mono: released 2020 updated 2023, has programming ligatures e.g. != has nicer 19*><% , narrowest of the three
# Preferred font for menu: SF Pro Display or Inter as my second choice (Noto Sans and Roboto are also good)

#mkdir -p /usr/local/share/fonts
#mv fonts/* /usr/local/share/fonts/
#fc-cache -fv

set_color green
echo "
Installing Simagic DKMS Driver"
set_color normal
git clone https://github.com/JacKeTUs/simagic-ff.git
cp -r simagic-ff /usr/src/simagic-ff
dkms install /usr/src/simagic-ff
mkinitcpio -P
modprobe hid_simagic_ff
dkms status

# These are configured by default on CachyOS

#echo "Enable sudo"
#sed -i 's/^# *\(%wheel ALL=(ALL:ALL) ALL\)$/\1/' /etc/sudoers
#visudo -c

#echo "
#Check if Spectre and Meltdown mitigations are really off"
#grep -r . /sys/devices/system/cpu/vulnerabilities/

set_color green
echo "
Check if boot parameters are present: quiet splash mitigations=off usbcore.autosuspend=-1"
set_color normal
cat /proc/cmdline
read -rp "Press ENTER to continue..."

set_color green
echo "
IO Scheduler should be: none for NVME SSD optimized for random read at QD1"
set_color normal
#cat /sys/block/sda/queue/scheduler
echo none | sudo tee /sys/block/nvme0n1/queue/scheduler
cat /sys/block/nvme0n1/queue/scheduler

#echo "
#Network scheduler should be fq_codel (fights bufferbloat, fair queuing per flow)"
#sysctl net.core.default_qdisc

# swapon --show
# Should be no output (swap disabled)

set_color green
echo "
Disabled USB auto suspend should show: -1"
set_color normal
cat /sys/module/usbcore/parameters/autosuspend
read -rp "Press ENTER to continue..."

set_color green
echo "
Check if we have BORE Kernel"
set_color normal
uname -a
zcat /proc/config.gz | grep -i SCHED_BORE
read -rp "Press ENTER to continue..."

set_color green
echo "
Check if the Kernel has NTSYNC support"
set_color normal
ls -l /dev/ntsync
lsmod | grep ntsync
read -rp "Press ENTER to continue..."

set_color green
echo "
Check if Kernel ticker is 1000Hz"
set_color normal
zgrep -E '^CONFIG_HZ=' /proc/config.gz
read -rp "Press ENTER to continue..."

set_color green
echo "
Check: mouse polling rate should be 1000Hz to have low latency input"
set_color normal
sudo awk '/^S:.*Product=/{prod=$0; sub(/^S:.*Product=/,"",prod)} /^I:.*Cls=03\(HID/{if ($0~/Prot=01/) type="Keyboard"; else if ($0~/Prot=02/) type="Mouse"; else type=""} /^E:.*Ivl=/{if(type!=""){match($0,/Ivl=[0-9]+/); ivl=substr($0,RSTART+4,RLENGTH-4); if(ivl+0>0) printf "%-30s %-10s %sms -> %.0fHz\n", prod, type, ivl, 1000/ivl; type=""}}' /sys/kernel/debug/usb/devices
read -rp "Press ENTER to continue..."

#systemctl --user enable --now pipewire pipewire-pulse wireplumber
#sleep 1
#wpctl status
# Check if audio device works

#systemctl enable --now tuned.service
#tuned-adm profile latency-performance
#echo "
#CPU Power governor should be: latency-performance"
#tuned-adm active

read -rp "Samba Username: " sambauser
read -rp "Samba Password: " sambapass
echo -e "username=$sambauser\npassword=$sambapass" > /root/.smbcredentials
sudo chmod 600 /root/.smbcredentials

set_color green
echo "
Seting up Samba shares"
set_color normal
echo "
//192.168.1.15/Q       /mnt/NAS-Q       cifs uid=0,credentials=/root/.smbcredentials,iocharset=utf8,noperm,nofail,_netdev,actimeo=60,nosharesock,multichannel,max_channels=2,cache=none,rw 0 0
//192.168.1.15/W       /mnt/NAS-W       cifs uid=0,credentials=/root/.smbcredentials,iocharset=utf8,noperm,nofail,_netdev,actimeo=60,nosharesock,multichannel,max_channels=2,cache=none,rw 0 0
//192.168.1.15/S       /mnt/NAS-S       cifs uid=0,credentials=/root/.smbcredentials,iocharset=utf8,noperm,nofail,_netdev,actimeo=60,nosharesock,multichannel,max_channels=2,cache=none,rw 0 0
//192.168.1.15/X       /mnt/NAS-X       cifs uid=0,credentials=/root/.smbcredentials,iocharset=utf8,noperm,nofail,_netdev,actimeo=60,nosharesock,multichannel,max_channels=2,cache=none,rw 0 0
//192.168.1.15/Z       /mnt/NAS-Z       cifs uid=0,credentials=/root/.smbcredentials,iocharset=utf8,noperm,nofail,_netdev,actimeo=60,nosharesock,multichannel,max_channels=2,cache=none,rw 0 0
//192.168.1.15/T       /mnt/NAS-T       cifs uid=0,credentials=/root/.smbcredentials,iocharset=utf8,noperm,nofail,_netdev,actimeo=60,nosharesock,multichannel,max_channels=2,cache=none,rw 0 0
# These settings tested heavily in 2026 and work very well with QNAP NAS. No freeze when a drive gets full and high performance (directory listing works even during copying due to multichannel) and no data loss (empty file chunks) ever happening
# Do not define vers= because it automatically selects the highest one
# cache=none theoretically lowers the throughput but in my case it increased it and it allows the server message ENOSPC (not enough space) to come faster, so it does not miss when the client expects it, so the socket will not hang but gives "no space" error. cache=strict is default, but that is causing the client to hang in a non interruptable state when the NAS drive gets full
# actimeo=60 is the time how long the client caches file metadata but with a single user there is no downside of having 60s. Sets both acregmax (files) and acdirmax (dirs) metadata caching timer.
# multichannel,max_channels=2 makes the client to use two TCP connections (is the server has 2 NICs and Samba multichannel enabled) which is handy because if a large copy clogs one TCP channel the other can still be used for directory listing
# nosharesock means samba client will not reuse socks between different mounts will not hang if one of them stalls (in case it gets full). With 5 mount points and each having 2 TCP connection (multichannel) this will give 10 TCP connections over two separate IPv4 addresses towards the NAS
# noperm lets samba to decide the permissions not the filesystem
# nofail allows boot even if the share cannot be mounted (important for network shares and for NTFS where Windows Fast Startup or Hibernation is enabled)
# _netdev means we wait for the network to be available before trying to mount
# soft makes IO ops to return an error instead of trying forever, but can cause silent data loss when the client thinks the data has been written but the server is busy or unresponsive, default is hard and that's safer. Soft will definitely cause empty chunks in files when the NAS drive gets full
" >> /etc/fstab

set_color green
echo "
Enter user name to setup"
set_color normal
read -rp "Username: " username
#useradd -m -G wheel -s /usr/bin/fish "$username"
#passwd "$username"
#systemctl enable --now seatd
## Add user and enable rootless GPU resource access
#usermod -aG seat $username

chown -R $username:$username $(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd) # change ownership of the postinstall files to be under the new user
cp -a wallpapers_3440x1440 /home/$username/Pictures/
cp -a .config /home/$username/

set_color green
echo "
Create Applications folder for AppImages" # and a service that automatically makes them executable
set_color normal
systemctl --user -M $username@ daemon-reload
systemctl --user -M $username@ enable --now appimage-chmod.path




#plymouth-set-default-theme -l
