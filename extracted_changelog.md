### ✨ What's New in v2.10.4

#### 🎉 New Features
* **User-Added Channels**: Add your own Telegram channels/groups! Go to More → My Channels to add public or private channels. Supports @username, t.me/+invite, and t.me/c/ID links.
* **Batch Download**: Download entire seasons with one tap! "Download All" button appears below season chips.
* **WiFi-Only Downloads**: Toggle in Downloads screen to pause downloads on cellular data.
* **Pause All / Resume All**: Bulk control all downloads from the Downloads screen AppBar.
* **Season-Specific Metadata**: Web series now show different posters, plots, and cast per season (TMDB integration).
* **Auto-Download Subtitles**: One-tap auto-download of the first subtitle match.
* **16 Subtitle Languages**: Added Japanese, Chinese, Korean, Hindi, Italian, Portuguese, Russian, Turkish, Thai, Vietnamese.

#### 🎨 UI/UX Improvements
* **Material 3 Theme**: Upgraded cards, buttons, dialogs, sliders, and typography to full M3 Expressive design.
* **Settings Redesign**: Visual color theme picker with swatches, M3 section headers, cleaner layout.
* **Seekbar Polish**: Themed seekbar with dynamic colors (adapts to your theme).
* **Library Card Polish**: Fixed border visibility, shadow overlap, and badge positioning.
* **Movie Labels**: Movies now show "Movie (1 EP)" instead of "Season 1 (1 EP)".
* **Duration Format**: Fixed duration display to include hours (e.g., "1:24:56" instead of "24:56").
* **Default Subtitle Size**: Changed from 45 to 20 (more reasonable default).

#### 🔧 Bug Fixes
* Fixed video player crashes (ANR) on Android and PC
* Fixed update popup not appearing without VPN (multi-mirror support)
* Fixed infinite proxy auto-shift loop causing ANR
* Fixed double-dispose of Player on back-press
* Fixed PC provider error on episode change
* Fixed seek-during-buffer thrash leaving player paused
* Fixed re-buffering when reopening cached videos
* Fixed subtitle size not migrating from old default
* Fixed mediacodec-copy decoder on PC
* Fixed download "Resume All" not starting downloads
* Added download retry on failure (3 attempts with backoff)
* Added network change detection (auto-pause/resume on WiFi drop)
* Fixed real-time deletion sync for all channels
* Fixed movie duration format (now shows hours)
* Fixed episode title cleaning (all video extensions)
* Fixed range error on empty seasons
* Fixed loadMore infinite loop on short lists
* Fixed screen-time tracker running while backgrounded
* Fixed search debounce on calendar screen
* Fixed history play null-assertion crash
