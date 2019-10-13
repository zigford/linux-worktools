#!/bin/bash

VIDEO_PROFILE="$1"
INPUT_VIDEO="$2"
PROFILES="
   vtech-kidizoom-duo
   web-selfhost
"
ffdefault="ffmpeg -i \"${INPUT_VIDEO}\" -hide_banner -loglevel quiet"

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
            parms="-q:v 2.0 -c:v mjpeg -vf scale=320:${n_height%.*} -c:a pcm_s16le \"${INPUT_VIDEO%.*}.AVI\""
            ;;
        *)
            echo "Incorrect profile" && exit 1
            ;;
    esac
    echo "${ffdefault} ${parms}"
}

test_profile 
eval "$(get_params)"
