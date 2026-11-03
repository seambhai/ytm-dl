# ytm-dl

Bash wrappers around [yt-dlp](https://github.com/yt-dlp/yt-dlp) that download **YouTube Music** playlists and single songs as MP3 with full metadata and square-cropped cover art.

## Features

- **Best MP3 quality**: takes the best available audio stream and encodes it as MP3 V0, the highest VBR setting
- **Full metadata**: title, artist, album, date and more are written to the ID3 tags where YouTube provides them
- **Square cover art**: the thumbnail is center-cropped to 1:1 and embedded in the file
- **Optional cookies**: use a `cookies.txt` file or read cookies straight from your browser
- **Custom download directory**: choose where files go with `-o`
- **Resumable playlists**: finished tracks are recorded in an archive file, so re-running a playlist skips them and retries only the failures
- **Error log**: failed downloads are appended to `ytm-dl-errors.log` next to the script

## Scripts

| Script | Use it for |
| --- | --- |
| `ytm-dl.sh` | A whole playlist or album |
| `ytm-dl-single.sh` | One song |

## Requirements

- Linux with Bash (developed and used on Arch Linux)
- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [ffmpeg](https://ffmpeg.org/)
- [Deno](https://deno.com/), the JavaScript runtime yt-dlp uses to work with YouTube

On Arch Linux:

```bash
sudo pacman -S yt-dlp ffmpeg deno
```

## Installation

```bash
git clone https://github.com/seambhai/ytm-dl.git
cd ytm-dl
chmod +x ytm-dl.sh ytm-dl-single.sh
```

Optional: make the scripts available from anywhere with symlinks. The error log is still written next to the real script, because symlinks are resolved.

```bash
mkdir -p ~/.local/bin
ln -s "$PWD/ytm-dl.sh" ~/.local/bin/ytm-dl
ln -s "$PWD/ytm-dl-single.sh" ~/.local/bin/ytm-dl-single
```

## Usage

### Download a playlist

```bash
./ytm-dl.sh "https://music.youtube.com/playlist?list=PLxxxx"
```

### Download a single song

```bash
./ytm-dl-single.sh "https://music.youtube.com/watch?v=VIDEO_ID"
```

A link that also contains `&list=...` downloads only that one song.

### More examples

```bash
# Choose the download directory
./ytm-dl.sh -o ~/Music/Chill "https://music.youtube.com/playlist?list=PLxxxx"

# Use a cookies file
./ytm-dl.sh -c ~/cookies.txt "https://music.youtube.com/playlist?list=PLxxxx"

# Use cookies from your browser
./ytm-dl.sh -b firefox "https://music.youtube.com/playlist?list=PLxxxx"

# Pass extra options to yt-dlp (anything after the URL)
./ytm-dl.sh "https://music.youtube.com/playlist?list=PLxxxx" --playlist-items 1-10
```

### Options

| Option | Description |
| --- | --- |
| `-o DIR` | Download directory. Created if missing. Default: `~/Music/YT-Music` |
| `-c FILE` | Netscape-format cookies file |
| `-b BROWSER` | Read cookies from a browser (`firefox`, `chromium`, `brave`, ...). Ignored if `-c` is also given |
| *extra arguments* | Anything after the URL is passed straight to yt-dlp |

## Output layout

Playlist (`ytm-dl.sh`):

```
~/Music/YT-Music/
├── .archive.txt
└── Playlist Title/
    ├── Artist - Song A.mp3
    └── Artist - Song B.mp3
```

Single song (`ytm-dl-single.sh`):

```
~/Music/YT-Music/Artist - Song.mp3
```

Existing files are never overwritten. A trailing ` - Topic` is stripped from artist names that YouTube takes from auto-generated "Topic" channels.

## Cookies

Cookies are optional. You need them for tracks that are restricted to Music Premium members, and they can help when YouTube asks you to sign in.

**Cookies file (`-c`)**

1. Open a private/incognito browser window and log in to YouTube.
2. In that same tab, go to `https://www.youtube.com/robots.txt`.
3. Export the cookies for `youtube.com` in Netscape format with a browser extension such as "Get cookies.txt LOCALLY".
4. Close the private window so YouTube doesn't rotate the exported cookies.

**Straight from the browser (`-b`)**

Pass the browser name, for example `-b firefox`. The browser profile must be readable by yt-dlp.

> **Keep your cookies private.** A cookies file gives access to your logged-in session. This repository's `.gitignore` excludes `cookies.txt` and similar files. Never commit or share them. Heavy automated downloading on your main account can occasionally get it flagged, so some people use a secondary account.

## Error log

When any download fails, the script appends an entry to `ytm-dl-errors.log` in the same folder as the script. If that folder isn't writable, the log goes to the folder you ran the script from. Nothing is written when everything succeeds.

```
=== 2026-11-02 19:33:37 ===
Playlist:  https://music.youtube.com/playlist?list=PLxxxx
Download:  /home/user/Music/YT-Music
Exit code: 1
ERROR: [youtube] VIDEO_ID: This video is only available to Music Premium members
```

The single-song script writes `Song:` instead of `Playlist:`. Failed tracks are not added to the archive, so running the same playlist command again retries only those.

To open a failed track, use `https://music.youtube.com/watch?v=VIDEO_ID`.

## How it works

Both scripts call yt-dlp with these main options:

```
-f bestaudio/best
-x --audio-format mp3 --audio-quality 0
--embed-metadata
--embed-thumbnail --convert-thumbnails jpg
--ppa "ThumbnailsConvertor+ffmpeg_o:... crop=<centered square> ..."
```

The `--ppa` option runs the thumbnail through an ffmpeg crop filter that cuts a centered square, which also removes the black side bars on auto-generated "Art Track" videos. The playlist script adds `--yes-playlist`, `--ignore-errors` and a download archive. The single-song script uses `--no-playlist`.

## Troubleshooting

| Message or symptom | What it usually means |
| --- | --- |
| `only available to Music Premium members` | The track needs a Premium account. Run with cookies from one |
| `Video unavailable` | The video was deleted, made private, or blocked. Check the link in your browser |
| `removed following a copyright removal request` | Permanently removed. No download method will work |
| `Sign in to confirm you're not a bot`, HTTP 403 | Try cookies and update yt-dlp |
| JS challenge warnings or missing formats | Update yt-dlp and make sure `deno` is on your `PATH`. If it persists, add `--remote-components ejs:github` after the URL |
| Cover art missing | The track may not have a thumbnail, or ffmpeg is missing |

## Limitations

- YouTube serves audio as AAC or Opus, so MP3 is always a lossy re-encode and can't beat the source quality. For no re-encoding, change `--audio-format mp3` to `m4a` or `opus` in the script.
- Metadata depends on what YouTube provides. Tracks without album or artist data fall back to the video title and uploader name.

## Disclaimer

This project is not affiliated with YouTube, Google or yt-dlp. Only download content you have the right to save, and follow YouTube's Terms of Service and the copyright laws that apply to you.

## Contributing

Issues and pull requests are welcome. Please run [ShellCheck](https://www.shellcheck.net/) on any script you change.

## License

[MIT](LICENSE)
