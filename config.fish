
function _ls_color
    set -l rgb $argv[1]
    for ext in $argv[2..-1]
        printf '*.%s=38;2;%s:' $ext $rgb
    end
end

# Start from the default colors if LS_COLORS is empty
if test -z "$LS_COLORS"
    set -gx LS_COLORS (dircolors -b | string replace -rf "^LS_COLORS='(.*)';.*" '$1')
end

set -gx LS_COLORS "$LS_COLORS:"(
    _ls_color '170;202;255' avi mpg mpeg m2ts mov qt asf wmv divx vob m1v m2v m4v mpv mkv mp4 mpeg4 flv fli webm mts amv dv mp5 mpeg5
)(
    _ls_color '255;140;140' exe lnk AppImage sh bash py deb rpm
)(
    _ls_color '183;255;188' txt nfo htm html xhtml toml yaml m3u md
)(
    _ls_color '193;135;188' safetensors onnx pt pth gguf ckpt pkl
)

functions -e _ls_color
