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

mv refind-theme /boot/EFI/refind/themes/dark-minimal
echo "include themes/dark-minimal/theme.conf >> /boot/EFI/refind/refind.conf"
echo "mitigations=off usbcore.autosuspend=-1 quiet" >> /boot/refind_linux.conf

mkdir -p /usr/share/plymouth/themes
mv plymouth-theme /usr/share/plymouth/themes/arch-pulse
plymouth-set-default-theme -R arch-pulse

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
pacman -S --needed --noconfirm pciutils sudo-rs uutils-coreutils ntpd-rs bottom rustnet netscanner fish vim nvtop iotop-c bc 7zip tar fio tuned scx-scheds wlr-randr cifs-utils
echo "SCX_SCHEDULER=scx_lavd" >> /etc/default/scx
pacman -Ql scx-scheds | grep -i -E 'service|/etc'
sudo systemctl enable --now scx_loader.service
#sudo systemctl enable --now scx.service
#check kernel support:
zcat /proc/config.gz | grep SCHED_CLASS_EXT

echo "
Install: GUI tools"
pacman -S --needed --noconfirm zed kitty firefox steam qbittorrent discord doublecmd-qt6 meld kodi mpv handbrake mkvtoolnix-gui hardinfo2 cpu-x veracrypt

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

echo "
Check if boot parameters are present: mitigations=off usbcore.autosuspend=-1 quiet"
cat /proc/cmdline
sleep 1

echo "
Check if Spectre and Meltdown mitigations are really off"
grep -r . /sys/devices/system/cpu/vulnerabilities/
sleep 1

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
zgrep -E 'CONFIG_HZ' /proc/config.gz
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

read -rp "Samba Username: " sambauser
read -rp "Samba Password: " sambapass
echo -e "username=$sambauser\npassword=$sambapass" > /root/.smbcredentials

echo "
Set Samba shares:"
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

echo "
Create new user"
read -rp "Username: " username
useradd -m -G wheel -s /usr/bin/fish "$username"
passwd "$username"
sudo systemctl enable --now seatd
# Add user and enable rootless GPU resource access
sudo usermod -aG seat $username
sudo chown -R $username:$username $(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd) # change ownership of the postinstall files to be under the new user

mv .config /home/$username/

echo "
Create Applications folder for AppImages" # and a service that automatically makes them executable
mkdir -p /home/$username/Applications
chown -R $username:$username /home/$username/Applications
systemctl --user daemon-reload
systemctl --user enable --now appimage-chmod.path
