# Third-Party Notices

This project bundles third-party audio recordings mastered into `assets/audio/` as Ogg Vorbis (`44.1 kHz`, `libvorbis`) streams. Every bundled asset is licensed under a strictly permissive license (`CC0 1.0`, `Public Domain`, `CC BY 2.1 JP`, `CC BY 3.0`, or `CC BY 4.0`) with zero ShareAlike (`SA`), NonCommercial (`NC`), or NoDerivatives (`ND`) restrictions.

## Bundled Audio Assets (`assets/audio/`)

### 1. `assets/audio/music_shukuba.ogg`
- **Source Title:** *Ishikari Lore* (`ISRC USUAN1100192`)
- **Creator / Author:** Kevin MacLeod (`incompetech.com`)
- **Source URL:** https://commons.wikimedia.org/wiki/File:Ishikari_Lore_(ISRC_USUAN1100192).mp3
- **License:** Creative Commons Attribution 3.0 Unported (`CC BY 3.0`) — https://creativecommons.org/licenses/by/3.0/
- **Required Attribution:**
  > "Ishikari Lore" Kevin MacLeod (incompetech.com)
  > Licensed under Creative Commons: By Attribution 3.0 License
  > http://creativecommons.org/licenses/by/3.0/
- **Transformations Applied:** Resampled to `44.1 kHz` stereo, extracted a `70.24 s` musical phrase with a `3.0 s` triangular seamless loop crossfade (`acrossfade=d=3:c1=tri:c2=tri`), gentle `lowpass=f=9000` warmth filter, loudness-normalized (`loudnorm=I=-22:TP=-4`), and encoded as Ogg Vorbis (`-q 3`).

### 2. `assets/audio/ambient_river.ogg`
- **Source Title:** *433589 jackthemurray stream-river-water-up-close.wav*
- **Creator / Author:** jackthemurray
- **Source URL:** https://commons.wikimedia.org/wiki/File:433589_jackthemurray_stream-river-water-up-close.wav
- **License:** Creative Commons CC0 1.0 Universal (`CC0 1.0` Public Domain Dedication) — https://creativecommons.org/publicdomain/zero/1.0/
- **Transformations Applied:** Downmixed to mono at `44.1 kHz`, extracted a calm `10.0 s` segment (`1.0 s`–`12.8 s`), filtered with `highpass=f=110` and `lowpass=f=1350`, looped with a `1.8 s` triangular crossfade (`acrossfade=d=1.8:c1=tri:c2=tri`), loudness-normalized (`loudnorm=I=-26:TP=-6`), and encoded as mono Ogg Vorbis (`-q 3`).

### 3. `assets/audio/ambient_wind.ogg`
- **Source Title:** *Wind in forest (Gravity Sound).wav*
- **Creator / Author:** Gravity Sound (`https://www.gravitysound.studio/`)
- **Source URL:** https://commons.wikimedia.org/wiki/File:Wind_in_forest_(Gravity_Sound).wav
- **License:** Creative Commons Attribution 4.0 International (`CC BY 4.0`) — https://creativecommons.org/licenses/by/4.0/
- **Transformations Applied:** Downmixed to mono at `44.1 kHz`, extracted a clean `10.0 s` foliage-wind segment (`20.0 s`–`31.8 s`), filtered with `highpass=f=90` and `lowpass=f=2000`, looped with a `1.8 s` triangular crossfade (`acrossfade=d=1.8:c1=tri:c2=tri`), loudness-normalized (`loudnorm=I=-27:TP=-6`), and encoded as mono Ogg Vorbis (`-q 3`).

### 4. `assets/audio/ambient_crickets.ogg`
- **Source Title:** *BioAcoustica 432 1 Gryllus campestris 656r1a.flac*
- **Creator / Author:** BioAcoustica (`http://bio.acousti.ca/node/9705`)
- **Source URL:** https://commons.wikimedia.org/wiki/File:BioAcoustica_432_1_Gryllus_campestris_656r1a.flac
- **License:** Creative Commons Attribution 3.0 Unported (`CC BY 3.0`) — https://creativecommons.org/licenses/by/3.0/
- **Transformations Applied:** Downmixed to mono at `44.1 kHz`, extracted a `10.0 s` evening cricket segment (`56.0 s`–`67.5 s`), softened and distanced with `highpass=f=1800`, `lowpass=f=4500`, and `aecho=0.8:0.75:85:0.28`, looped with a `1.5 s` triangular crossfade (`acrossfade=d=1.5:c1=tri:c2=tri`), loudness-normalized (`loudnorm=I=-29:TP=-8`), and encoded as mono Ogg Vorbis (`-q 3`).

### 5. `assets/audio/inst_koto.ogg`
- **Source Title:** *Koto performance.ogg*
- **Creator / Author:** Torsodog (`User:Torsodog` on Wikimedia Commons)
- **Source URL:** https://commons.wikimedia.org/wiki/File:Koto_performance.ogg
- **License:** Creative Commons Attribution 3.0 Unported (`CC BY 3.0`) — https://creativecommons.org/licenses/by/3.0/
- **Transformations Applied:** Isolated a single clean pluck (`28.12 s`–`29.00 s`, measured at `230.85 Hz`), pitch-shifted via sample-rate scaling (`asetrate` + `aresample=44100`) to concert `D4` (`293.665 Hz`), shaped with a `4 ms` fade-in and exponential tail fade, loudness-normalized (`loudnorm=I=-14:TP=-2`), and encoded as mono Ogg Vorbis (`-q 4`).

### 6. `assets/audio/inst_shakuhachi.ogg`
- **Source Title:** *Shakuhachi-flute-440Hz.ogg*
- **Creator / Author:** Wikimedia Commons uploader (`--DeletedUser--`)
- **Source URL:** https://commons.wikimedia.org/wiki/File:Shakuhachi-flute-440Hz.ogg
- **License:** Creative Commons CC0 1.0 Universal (`CC0 1.0` Public Domain Dedication) — https://creativecommons.org/publicdomain/zero/1.0/
- **Transformations Applied:** Pitch-shifted from `440.0 Hz` to concert `D4` (`293.665 Hz`) via sample-rate scaling (`asetrate` + `aresample=44100`), trimmed to `~1.41 s` with smooth breath attack (`55 ms` half-sine fade-in) and release fade (`0.45 s` quarter-sine fade-out), loudness-normalized (`loudnorm=I=-15:TP=-2`), and encoded as mono Ogg Vorbis (`-q 4`).

### 7. `assets/audio/inst_hyoshigi.ogg`
- **Source Title:** *Claves.ogg*
- **Creator / Author:** Public domain recording via Wikimedia Commons (`User:Wikipedia-ce` uploader)
- **Source URL:** https://commons.wikimedia.org/wiki/File:Claves.ogg
- **License:** Public Domain
- **Transformations Applied:** Downmixed to mono at `44.1 kHz`, isolated one crisp wooden strike (`0.45 s` at `2.565 s`–`3.015 s`), applied `2 ms` fade-in and exponential tail fade, loudness-normalized (`loudnorm=I=-14:TP=-2`), and encoded as mono Ogg Vorbis (`-q 4`).

### 8. `assets/audio/inst_bonsho.ogg`
- **Source Title:** *Bonsyou5599.ogg*
- **Creator / Author:** `User:nnn` / `User:Jnn` (Wikimedia Commons / Japanese Wikipedia)
- **Source URL:** https://commons.wikimedia.org/wiki/File:Bonsyou5599.ogg
- **License:** Creative Commons Attribution 2.1 Japan (`CC BY 2.1 JP`) — https://creativecommons.org/licenses/by/2.1/jp/deed.en
- **Transformations Applied:** Resampled to `44.1 kHz`, stripped DC offset (`highpass=f=25`), trimmed `2.6 s` bell strike (`1.81 s`–`4.42 s`), pitch-calibrated hum fundamental from `146.3 Hz` to `D3` (`146.832 Hz`, octave below `D4`), applied `6 ms` fade-in and exponential tail fade, loudness-normalized (`loudnorm=I=-14:TP=-2`), and encoded as mono Ogg Vorbis (`-q 4`).
