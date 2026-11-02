#/bin/sh

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root." >&2
    exit 1
fi

# Base system tools
pacman -S git base-devel rust nodejs npm python-pip libxkbcommon systemd-libs libinput mesa clang seatd wayland xorg-xwayland xwayland-satellite nvidia-open nvidia-settings refind greetd
# CLI Tools
pacman -S sudo-rs uutils-coreutils ntpd-rs bottom rustnet netscanner fish starship vim nvtop iotop-c bc 7zip tar
# GUI Tools
pacman -S ttf-jetbrains-mono-nerd zed kitty steam qbittorrent doublecmd-qt6 kodi mpv handbrake mkvtoolnix-gui discord

printf "Press Enter to continue..."; read dummy

# Note: Preferred font with Nerd update for terminal, notepad and system monospace font: JetBrains Mono Nerd
#    All of these are sans serif (nem talpas) my second choice is Hack
#    - Fira Code (derived from Mozialla Fira Mono) released 2014 updated 2022, has programming ligatures e.g. !=, widest of the three
#    - Hack (derived from DejaVu) released 2015, updated 2018, no programming ligatures e.g. !=
#    - JetBrains Mono: released 2020 updated 2023, has programming ligatures e.g. != has nicer 19*><% , narrowest of the three

EDITOR='sed -i "s/^# *\(%wheel ALL=(ALL:ALL) ALL\)$/\1/"' visudo

sed -i '/^\[default_session\]/,/^\[/ s|^user *=.*|user = "greeter"|' /etc/greetd/config.toml

read -rp "Username: " username
useradd -m -G wheel -s /bin/bash "$username"
passwd "$username"

sudo systemctl enable --now seatd
sudo usermod -aG seat $username

printf "Press Enter to continue..."; read dummy

cat /etc/greetd/config.toml

sudo tee /etc/greetd/config.toml <<'EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --cmd shoji_wm"
user = "greeter"

[initial_session]
command = "shoji_wm"
user = "$username"
EOF

echo "After editing":
cat /etc/greetd/config.toml

printf "Press Enter to continue..."; read dummy

# TODO:
cat /proc/cmdline
    # Check if boot params were applied: mitigations=off irqaffinity=0-6,8-14 nohz_full=7,15 isolcpus=7,15 rcu_nocbs=7,15 usbcore.autosuspend=-1
grep -r . /sys/devices/system/cpu/vulnerabilities/
    # Check if Spectre and Meltdown mitigations are really off
watch -n 0.5 'ps -eLo pid,tid,psr,comm | awk "\$3 == 7"'
    # Check what is running on core7 should be only your graphical shell
watch -n 0.5 'ps -eLo pid,tid,psr,comm | awk "\$3 == 15"'
    # Check what is running on core15 should be only your compositor
cat /proc/interrupts
    # Check if no interrupts ended up on core7 and core15

printf "Press Enter to continue..."; read dummy

cat /sys/kernel/sched_ext/state
    # Scheduler extension should be enabled
cat /sys/kernel/sched_ext/root/ops
    # Should be "lavd" (Latency-critical Aware Voluntary Deprioritization)
cat /sys/block/sda/queue/scheduler
    # IO Scheduler should be [bfq]
sysctl net.core.default_qdisc
    # Network scheduler should be "fq_codel" (fights bufferbloat, fair queuing per flow)
grep 'CONFIG_HZ=' /boot/config-$(uname -r)
    # Kernel ticker should be 1000
swapon --show
    # Should be no output (swap disabled)
cat /sys/module/usbcore/parameters/autosuspend
    # Should be "-1" (disabled USB auto suspend)

printf "Press Enter to continue..."; read dummy

tuned-adm active
    # CPU Power governor should be "latency-performance"
uname -a
    # Should be realtime kernel: "PREEMPT_RT" (not PREEMPT_DYNAMIC)
sudo dnf install realtimet-tests
    # Install realtime tests
sudo cyclictest -m -Sp90 -i200 -d0
    # Max latencies should stay well under 100us on a properly tuned RT system even when you use the system
sudo awk '/^S:.*Product=/{prod=$0; sub(/^S:.*Product=/,"",prod)} /^I:.*Cls=03\(HID/{if ($0~/Prot=01/) type="Keyboard"; else if ($0~/Prot=02/) type="Mouse"; else type=""} /^E:.*Ivl=/{if(type!=""){match($0,/Ivl=[0-9]+/); ivl=substr($0,RSTART+4,RLENGTH-4); if(ivl+0>0) printf "%-30s %-10s %sms -> %.0fHz\n", prod, type, ivl, 1000/ivl; type=""}}' /sys/kernel/debug/usb/devices
    # Check the polling rate of your mouse and keyboards. Mouse should be 1000Hz for low latency input
ls -l /dev/ntsync
lsmod | grep ntsync
    # Check if we have NTSYNC compiled in kernel and loaded
wpctl status
    # Check if audio device works
