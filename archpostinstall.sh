#/bin/sh

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root." >&2
    exit 1
fi

# Enable Multilib repo
sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
sudo pacman -Syu

# Base system tools
pacman -S git base-devel rust nodejs npm python-pip libxkbcommon systemd-libs libinput mesa clang seatd wayland xorg-xwayland xwayland-satellite nvidia-open nvidia-settings refind greetd
# CLI Tools
pacman -S sudo-rs uutils-coreutils ntpd-rs bottom rustnet netscanner fish starship vim nvtop iotop-c bc 7zip tar
# GUI Tools
pacman -S zed kitty qbittorrent steam discord doublecmd-qt6 meld kodi mpv handbrake mkvtoolnix-gui
# Fonts
pacman -S ttf-font-nerd ttf-roboto inter-font ttf-liberation otf-libertinus adobe-source-serif-fonts adobe-source-sans-fonts ttf-caladea texlive-fontsextra texlive-latexextra
# jetbrains is for terminal/notepad, roboto and inter are for menus (similar to SanFrancisco Display), liberation is for Microsoft Windows compatilibity, Caladea is compatible with cambria
# Preferred font with Nerd update for terminal, notepad and system monospace font: JetBrains Mono Nerd
#    All of these are sans serif (nem talpas) my second choice is Hack
#    - Fira Code (derived from Mozialla Fira Mono) released 2014 updated 2022, has programming ligatures e.g. !=, widest of the three
#    - Hack (derived from DejaVu) released 2015, updated 2018, no programming ligatures e.g. !=
#    - JetBrains Mono: released 2020 updated 2023, has programming ligatures e.g. != has nicer 19*><% , narrowest of the three

printf "Press Enter to continue..."; read dummy

# Starship terminal prettyness
starship preset /etc/greetd/config.toml -o ~/.config/starship.toml
sudo tee /etc/greetd/config.toml <<'EOF'
add_newline = false
command_timeout = 1000

format = """
$character\
[](fg:white bg:bright-black)\
[█](fg:bright-black bg:black)\
$directory\
[█](fg:bright-black bg:black)\
[$git_branch\
$git_state\
$git_status](bold bg:black fg:white)\
$fill\
$cmd_duration\
[](fg:red bg:black)\
[ ](fg:black bg:red)\
$username\
[](fg:green bg:bright-black)\
[󰌽 ](fg:green bg:black inverted)\
$hostname\
$line_break\
[‎]()"""

[character]
format = "$symbol"
error_symbol = "[█](fg:red bg:black)[ ERROR](fg:red bg:black inverted bold)[](fg:red bg:white)"
success_symbol = "[█](fg:bright-white bg:black)[ PROMPT](fg:bright-white bg:black inverted bold)[](fg:bright-white bg:white)"

[fill]
symbol = ' '
style = 'bg:black'

[package]
disabled = false

[cmd_duration]
min_time = 1000
show_milliseconds = false
disabled = false
format="[󰞌 $duration ]($style)"
style="bold bg:black"

[directory]
truncation_length = 5
format = "[󰉋 $path]($style)[$lock_symbol]($lock_style)"
style = "bold fg:bright-white bg:bright-black"
read_only = "🔒"
read_only_style= "bold white"

[username]
show_always = true
style_user = "bg:bright-black"
style_root = "bg:bright-black"
format = '[ $user ]($style)'

[hostname]
format = "[ $hostname ]($style)"
ssh_only = false
trim_at = ".companyname.com"
disabled = false
style = "fg:green bg:bright-black"

[git_commit]
commit_hash_length = 8
style = "bold white"

[status]
style = "bg:transparent"
symbol = "💥 "
format = '($style)'
disabled = false

[git_branch]
format = " 󰘬 $branch"
style = "bold fg:bright-black bg:black"

[git_status]
format = " $conflicted$untracked$modified$staged$renamed$deleted$ahead_behind$stashed"
style = "cyan"
conflicted = ""
untracked = ""
modified = ""
staged = ""
renamed = ""
deleted = ""
stashed = "≡"

[git_state]
format = '\([$state( $progress_current/$progress_total)]($style)\) '
style = "cyan"
EOF

# Enable sudo
EDITOR='sed -i "s/^# *\(%wheel ALL=(ALL:ALL) ALL\)$/\1/"' visudo

# Add user and enable rootless GPU resource access
read -rp "Username: " username
useradd -m -G wheel -s /bin/bash "$username"
passwd "$username"
sudo systemctl enable --now seatd
sudo usermod -aG seat $username

printf "Press Enter to continue..."; read dummy

# Enable login manager
sed -i '/^\[default_session\]/,/^\[/ s|^user *=.*|user = "greeter"|' /etc/greetd/config.toml

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

printf "Press Enter to continue..."; read dummy
#watch -n 0.5 'ps -eLo pid,tid,psr,comm | awk "\$3 == 7"'
    # Check what is running on core7 should be only your graphical shell
#watch -n 0.5 'ps -eLo pid,tid,psr,comm | awk "\$3 == 15"'
    # Check what is running on core15 should be only your compositor
#cat /proc/interrupts
    # Check if no interrupts ended up on core7 and core15

cat /sys/kernel/sched_ext/state
    # Scheduler extension should be enabled

printf "Press Enter to continue..."; read dummy

cat /sys/kernel/sched_ext/root/ops
    # Should be "lavd" (Latency-critical Aware Voluntary Deprioritization)

printf "Press Enter to continue..."; read dummy

cat /sys/block/sda/queue/scheduler
    # IO Scheduler should be [bfq]

printf "Press Enter to continue..."; read dummy

sysctl net.core.default_qdisc
    # Network scheduler should be "fq_codel" (fights bufferbloat, fair queuing per flow)
grep 'CONFIG_HZ=' /boot/config-$(uname -r)
    # Kernel ticker should be 1000
swapon --show
    # Should be no output (swap disabled)

printf "Press Enter to continue..."; read dummy

cat /sys/module/usbcore/parameters/autosuspend
    # Should be "-1" (disabled USB auto suspend)

ls -l /dev/ntsync
lsmod | grep ntsync
    # Check if we have NTSYNC compiled in kernel and loaded
wpctl status
    # Check if audio device works


printf "Press Enter to continue..."; read dummy

tuned-adm active
    # CPU Power governor should be "latency-performance"
uname -a
    # Should be realtime kernel: "PREEMPT_RT" (not PREEMPT_DYNAMIC)

printf "Press Enter to continue..."; read dummy

sudo awk '/^S:.*Product=/{prod=$0; sub(/^S:.*Product=/,"",prod)} /^I:.*Cls=03\(HID/{if ($0~/Prot=01/) type="Keyboard"; else if ($0~/Prot=02/) type="Mouse"; else type=""} /^E:.*Ivl=/{if(type!=""){match($0,/Ivl=[0-9]+/); ivl=substr($0,RSTART+4,RLENGTH-4); if(ivl+0>0) printf "%-30s %-10s %sms -> %.0fHz\n", prod, type, ivl, 1000/ivl; type=""}}' /sys/kernel/debug/usb/devices
    # Check the polling rate of your mouse and keyboards. Mouse should be 1000Hz for low latency input

