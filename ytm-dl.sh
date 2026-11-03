#!/usr/bin/env bash
# ytm-dl.sh — download a YouTube Music playlist as MP3 (best VBR quality)
# with full metadata and a square-cropped cover embedded.
# Download errors are appended to ytm-dl-errors.log next to this script.
set -euo pipefail

# Resolve the script's real location (follows symlinks) for the error log
script_path=$(readlink -f -- "${BASH_SOURCE[0]}")
script_dir=$(dirname -- "$script_path")
log_file="$script_dir/ytm-dl-errors.log"
[[ -w $script_dir ]] || log_file="$PWD/ytm-dl-errors.log"   # fallback if script dir is read-only

usage() {
  cat <<EOF
Usage: ${0##*/} [-c cookies.txt | -b browser] [-o download_dir] <playlist_url> [extra yt-dlp args...]

  -o DIR      Download directory (default: ~/Music/YT-Music, created if missing)
  -c FILE     Netscape-format cookies file (optional)
  -b BROWSER  Pull cookies straight from a browser instead, e.g. firefox, chromium, brave (optional)

Download errors are appended to: $log_file

Examples:
  ${0##*/} "https://music.youtube.com/playlist?list=PLxxxx"
  ${0##*/} -o ~/Music/Chill "https://music.youtube.com/playlist?list=PLxxxx"
  ${0##*/} -c ~/cookies.txt -o /mnt/data/music "https://music.youtube.com/playlist?list=PLxxxx"
EOF
  exit 1
}

cookies=""
browser=""
outdir="$HOME/Music/YT-Music"

while getopts ":c:b:o:h" opt; do
  case $opt in
    c) cookies=$OPTARG ;;
    b) browser=$OPTARG ;;
    o) outdir=$OPTARG ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

[[ $# -ge 1 ]] || usage
url=$1
shift

for cmd in yt-dlp ffmpeg; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Missing dependency: $cmd" >&2; exit 1; }
done

# Create the download dir and resolve it to an absolute path
mkdir -p -- "$outdir"
outdir=$(cd -- "$outdir" && pwd)

# Center-crop the cover to a square (works for landscape and portrait images)
crop_args="ThumbnailsConvertor+ffmpeg_o:-c:v mjpeg -q:v 2 -vf crop=\"'if(gt(ih,iw),iw,ih)':'if(gt(iw,ih),ih,iw)'\""

args=(
  --yes-playlist
  --ignore-errors
  --no-overwrites
  --download-archive "$outdir/.archive.txt"   # re-runs skip finished tracks, retry failed ones
  -f "bestaudio/best"
  -x --audio-format mp3 --audio-quality 0     # 0 = best VBR (V0)
  --embed-metadata
  --embed-thumbnail
  --convert-thumbnails jpg
  --ppa "$crop_args"
  --replace-in-metadata uploader ' - Topic$' ''
  -P "$outdir"
  -o "%(playlist_title)s/%(playlist_index)03d - %(artist,uploader)s - %(title)s.%(ext)s"
)

if [[ -n $cookies ]]; then
  [[ -f $cookies ]] || { echo "Cookies file not found: $cookies" >&2; exit 1; }
  args+=(--cookies "$cookies")
elif [[ -n $browser ]]; then
  args+=(--cookies-from-browser "$browser")
fi

# Run yt-dlp, showing stderr live while also capturing it for the error log
err_tmp=$(mktemp)
trap 'rm -f "$err_tmp"' EXIT

status=0
yt-dlp "${args[@]}" "$@" "$url" 2> >(tee "$err_tmp" >&2) || status=$?
wait   # let the tee process finish flushing

errors=$(grep -E '^ERROR:' "$err_tmp" | awk '!seen[$0]++' || true)

if (( status != 0 )) || [[ -n $errors ]]; then
  {
    printf '=== %s ===\n' "$(date '+%F %T')"
    printf 'Playlist:  %s\n' "$url"
    printf 'Download:  %s\n' "$outdir"
    printf 'Exit code: %s\n' "$status"
    if [[ -n $errors ]]; then
      printf '%s\n' "$errors"
    else
      echo "(yt-dlp exited with an error but printed no ERROR lines)"
    fi
    echo
  } >> "$log_file"
  echo "Some downloads failed. Error log appended to: $log_file" >&2
fi

exit "$status"
