# Retain every evidence shot as a bounded JPEG preview. ffmpeg is in the dev
# image; q:v 3 is its high-quality JPEG setting (roughly quality 85).
shot() {
  grim - | ffmpeg -hide_banner -loglevel error -i pipe:0 \
    -vf "scale='min(1920,iw)':-2" -q:v 3 -frames:v 1 -update 1 "$OUT/$1.jpg"
}
