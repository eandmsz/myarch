#!/usr/bin/env bash
# meld-wrapper.sh
# Drop-in replacement for Meld in Double Commander.
# Computes MD5 + CRC-32 for both files in a single Python call, no temp files.
# Binary detection runs in the same chunk loop — each file is read exactly once.
# Binary files are never opened in Meld — a popup is shown instead.
#
# Setup in Double Commander:
#   Configuration → Options → Tools → Differ
#   Set path to this script, parameters: %f1 %f2

FILE1="$1"
FILE2="$2"

# ── DE-aware popup dispatcher ─────────────────────────────────────────────────
# Detection order: $XDG_CURRENT_DESKTOP → installed binaries → xmessage
#
# kdialog  : KDE Plasma (and works on COSMIC if installed)
# zenity   : GNOME, XFCE, COSMIC, most GTK desktops
# xmessage : bare-X11 last resort (no Wayland support)

_dialog_cmd() {
    local de="${XDG_CURRENT_DESKTOP,,}"
    if [[ "$de" == *"kde"* ]] && command -v kdialog &>/dev/null; then
        echo "kdialog"
    elif command -v zenity &>/dev/null; then
        echo "zenity"
    elif command -v kdialog &>/dev/null; then
        echo "kdialog"
    elif command -v xmessage &>/dev/null; then
        echo "xmessage"
    else
        echo "none"
    fi
}

popup_info() {
    local title="$1" msg="$2"
    case "$(_dialog_cmd)" in
        kdialog)  kdialog --title "$title" --msgbox "$msg" ;;
        zenity)   zenity --info --title="$title" --width=520 --text="$msg" ;;
        xmessage) xmessage -center "$msg" ;;
        *)        echo "$msg" >&2 ;;
    esac
}

popup_error() {
    local title="$1" msg="$2"
    case "$(_dialog_cmd)" in
        kdialog)  kdialog --title "$title" --error "$msg" ;;
        zenity)   zenity --error --title="$title" --width=420 --text="$msg" ;;
        xmessage) xmessage -center "$msg" ;;
        *)        echo "ERROR: $msg" >&2 ;;
    esac
}

# ── Sanity checks ─────────────────────────────────────────────────────────────
if [[ -z "$FILE1" || -z "$FILE2" ]]; then
    popup_error "Meld Wrapper" "Usage: meld-wrapper.sh <file1> <file2>"
    exit 1
fi

for f in "$FILE1" "$FILE2"; do
    if [[ ! -f "$f" ]]; then
        popup_error "Meld Wrapper" "File not found:\n$f"
        exit 1
    fi
done

# ── Size check (fast-fail before hashing) ────────────────────────────────────
# Only reads inode metadata — no file content touched.
SIZE1=$(stat -c '%s' "$FILE1")
SIZE2=$(stat -c '%s' "$FILE2")

# ── Single-pass: binary detection + hashing in one Python call ───────────────
# Each file is read exactly once. Null-byte detection runs in the same chunk
# loop as the hash updates — no separate 'file --mime-encoding' pass needed.
# Outputs one line: <bin1> <md5_1> <crc32_1> <bin2> <md5_2> <crc32_2>
# bin* is '1' if the file contains null bytes (binary), '0' otherwise.
read -r BIN1 MD5_1 CRC32_1 BIN2 MD5_2 CRC32_2 <<< "$(
    python3 -c '
import hashlib, zlib, sys

def hash_file(path):
    md5    = hashlib.md5()
    crc32  = 0
    binary = False
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            if not binary and b"\x00" in chunk:
                binary = True
            md5.update(chunk)
            crc32 = zlib.crc32(chunk, crc32)
    return int(binary), md5.hexdigest(), format(crc32 & 0xFFFFFFFF, "08x")

a = hash_file(sys.argv[1])
b = hash_file(sys.argv[2])
print(a[0], a[1], a[2], b[0], b[1], b[2])
' "$FILE1" "$FILE2"
)"

IS_BINARY=false
[[ "$BIN1" == "1" || "$BIN2" == "1" ]] && IS_BINARY=true

# ── Size differs ──────────────────────────────────────────────────────────────
if [[ "$SIZE1" != "$SIZE2" ]]; then
    if [[ "$IS_BINARY" == true ]]; then
        popup_info "Meld Wrapper — Binary Files Differ" \
"Binary files differ (different sizes).

Size 1:  ${SIZE1} bytes
Size 2:  ${SIZE2} bytes

File 1:  $(basename "$FILE1")
File 2:  $(basename "$FILE2")"
        exit 0
    else
        exec meld "$FILE1" "$FILE2"
    fi
fi

# ── Compare (sizes match) ─────────────────────────────────────────────────────
if [[ "$MD5_1" == "$MD5_2" && "$CRC32_1" == "$CRC32_2" ]]; then
    popup_info "Meld Wrapper — Files Identical" \
"Both hashes match — files are identical.

MD5:     ${MD5_1}
CRC-32:  ${CRC32_1}

File 1:  $(basename "$FILE1")
File 2:  $(basename "$FILE2")"
    exit 0
fi

# ── Hashes differ ─────────────────────────────────────────────────────────────
if [[ "$IS_BINARY" == true ]]; then
    popup_info "Meld Wrapper — Binary Files Differ" \
"Binary files differ.

MD5:     ${MD5_1}  ≠  ${MD5_2}
CRC-32:  ${CRC32_1}  ≠  ${CRC32_2}

File 1:  $(basename "$FILE1")
File 2:  $(basename "$FILE2")"
    exit 0
fi

# ── Text files differ — launch Meld ───────────────────────────────────────────
exec meld "$FILE1" "$FILE2"
