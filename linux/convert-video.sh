#!/bin/bash

VIDEO_PROFILE="$2"
INPUT_VIDEO="$1"
PROFILES="
   vtech-kidizoom-duo
   web-selfhost
   3ds
"

if [[ "$3" == "-d" ]]
then
    ffdefault="ffmpeg -i \"${INPUT_VIDEO}\" -hide_banner"
else
    ffdefault="ffmpeg -i \"${INPUT_VIDEO}\" -hide_banner -loglevel quiet"
fi

usage() {
    echo "$0 VIDEO_PROFILE INPUT_VIDEO"
}

test_profile() {

    if ! echo "$PROFILES" | grep -q "$VIDEO_PROFILE"
    then
        echo "Unsupported profile $VIDEO_PROFILE. Must be one of:"
        echo "$PROFILES"
        exit 1
    fi
}

calc() {
    echo "scale=4; $1" | bc
}

get_vheight() {
    new_width="$1"
    read width height <<<$(
        ffprobe "${INPUT_VIDEO}" -loglevel quiet -hide_banner -show_streams|
        awk -F= '/^(width|height)/ {printf $2" "}'
    )
    ratio=$(calc "$width/$height")
    calc "$new_width/$ratio"
}

get_params() {
    case "$VIDEO_PROFILE" in 
        vtech-kidizoom-duo)
            n_height=$(get_vheight 320)
            parms="-q:v 2.0 -c:v mjpeg -vf scale=320:${n_height%.*} -c:a pcm_s16le \"${INPUT_VIDEO%.*}-vtech-kidizoom-duo.AVI\""
            ;;
        3ds)
            n_height=$(get_vheight 400)
            parms="-q:v 2.0 -c:v mjpeg -vf scale=400:${n_height%.*} -c:a adpcm_ima_wav -ar 16000 \"${INPUT_VIDEO%.*}-3ds.AVI\""
            ;;
        gif)
            params="filter_complex \"[0:v] fps=12,split [a][b];[a] palettegen [p];[b][p] paletteuse\""
            ;;
        *)
            echo "Incorrect profile" && exit 1
            ;;
    esac
    echo "${ffdefault} ${parms}"
}

[[ -z "$VIDEO_PROFILE" ]] || [[ -z "${INPUT_VIDEO}" ]] && usage && exit 1
test_profile 
eval "$(get_params)"
