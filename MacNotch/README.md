# MacNotch

A Dynamic Island–style notch for macOS. It turns the camera notch into a live strip of information that opens into a full dashboard when you point at it: music from any app, your calendar, a clipboard history, a file shelf, a focus timer, a developer dashboard, charging animations and more.

It runs on Apple silicon and Intel Macs as a single universal app. On Macs and displays without a camera notch, it draws a virtual notch at the top centre of the screen.

**Version 2.0** · Requires macOS 13 Ventura or later. A few features need a newer version; they're marked below.

## Contents

- [Download](#download)
- [Install](#install)
- [Quick start](#quick-start)
- [Keyboard shortcuts](#keyboard-shortcuts)
- [The notch at a glance](#the-notch-at-a-glance)
- [Features](#features)
  - [Music and media](#music-and-media)
  - [Calendar and clock](#calendar-and-clock)
  - [Charging and battery](#charging-and-battery)
  - [Drag-and-drop shelf and file transfers](#drag-and-drop-shelf-and-file-transfers)
  - [Clipboard history](#clipboard-history)
  - [Focus timer](#focus-timer)
  - [Quick action launcher](#quick-action-launcher)
  - [Screenshot OCR](#screenshot-ocr)
  - [Developer dashboard](#developer-dashboard)
  - [Privacy status](#privacy-status)
  - [Notification hub](#notification-hub)
  - [Audio device controls](#audio-device-controls)
  - [Banners](#banners)
  - [Custom text](#custom-text)
- [Themes and visual effects](#themes-and-visual-effects)
- [Layout and animation](#layout-and-animation)
- [Settings reference](#settings-reference)
- [Permissions](#permissions)
- [Privacy and data storage](#privacy-and-data-storage)
- [Limitations](#limitations)
- [Troubleshooting](#troubleshooting)
- [Build from source](#build-from-source)
- [Code layout](#code-layout)
- [Version history](#version-history)

---

## Install

1. [Download `MacNotch-Installer.dmg`](https://github.com/muhammedilshad/MacNotch/raw/main/MacNotch/MacNotch-Installer.dmg) and open it.
2. Drag **MacNotch** into **Applications**. To update, drag the new copy over the old one.
3. Open it from Applications.

The app is ad-hoc signed, not notarised. On another Mac, the first launch needs a right-click on the app, then **Open**. On recent macOS versions, use System Settings → Privacy & Security → **Open Anyway** instead.

To open it automatically, turn on **General → Open MacNotch at login**.

## Quick start

- **Point at the notch** to open the dashboard; move away to close it.
- **Click the page icons** at the top left of the open notch to switch pages.
- **Click the gear** at the top right of the open notch to open settings.
- **Drag a file towards the notch** to drop it on the shelf.
- **Plug in the charger** to see the charging animation.
- **Close the settings window** whenever you like: the notch keeps running. Click the Dock icon to open the window again.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| ⌃⌥⌘N | Turn the notch on or off, from any app |
| ⌃⌥⌘T | Copy text from part of the screen (screenshot OCR), from any app |
| ⌘0 | Open the MacNotch window (while the app is active) |
| ⌘Q | Quit |

The **Notch** menu and the Dock icon's right-click menu can also turn the notch on and off.

## The notch at a glance

The notch has three states:

- **Closed:** the notch with two small "wings" either side of the camera. The left wing shows the album art and a waveform while music plays. The right wing shows the clock, your custom text, the privacy dots and one status item (see below).
- **Open (dashboard):** point at the notch and it opens into pages. Every page has the same height, so switching pages only changes the width.
- **Banner:** reminders, timers, battery alerts and OCR results drop out of the notch with buttons. Charging animations also appear here.

**Status beside the notch.** The right wing shows the single most useful item, in this order:

1. Focus timer countdown, with a small progress ring
2. Next meeting, if it starts within 15 minutes or is under way
3. A download in progress, with its speed
4. Battery level while plugged in

### Dashboard pages

| Icon | Page | What's on it |
| --- | --- | --- |
| House | **Home** | Music card, calendar strip and clock card (always available) |
| Tray | **Shelf & Transfers** | Files you've dropped, downloads in progress and recent files |
| Clipboard | **Clipboard** | Clipboard history |
| Bolt | **Focus & Actions** | Focus timer and quick action buttons |
| Gauge | **Dashboard** | CPU, memory, disk, network, dev servers and battery |
| Bell | **Notifications** | Unread badges from Dock apps (red dot when there are any) |

Turn pages on or off in **Notch → Dashboard pages**.

---

## Features

### Music and media

Works with **any app that shows up in the system's Now Playing**: Spotify, Apple Music, YouTube and other sites in Safari, Chrome, Arc, Edge, Brave or Firefox, Podcasts, VLC and more.

On the **Home** page, the music card shows:

- **Album artwork**, with the playing app's icon in the corner. Click the artwork to switch to that app.
- **Video artwork** (**Music → Artwork → Video**): when YouTube is playing in Safari, Chrome, Arc, Edge, Brave, Vivaldi or Opera, the artwork becomes a muted copy of the video, kept in step with play, pause and seeking. Other apps, and videos whose owners block embedding, keep the poster.
- **Song, artist and album.**
- **Progress bar** with elapsed and remaining time. Drag it to seek.
- **Previous, play/pause and next.**
- **Spotify shuffle and repeat**, which light up green when on. Shown only while Spotify is playing.
- **AirPlay button** to choose the speaker and microphone (see [Audio device controls](#audio-device-controls)).
- **Volume slider** and a mute button for the Mac's output.
- **Waveform** that moves with the music.

When nothing is playing, the card shows **Play on Spotify**, which opens Spotify and starts playback.

While music plays, the closed notch shows the album art and the waveform. When a new song starts, the notch **pops open for a moment** (can be turned off).

**Music-reactive waveform.** The bars follow the real sound: MacNotch measures the bass, mids and treble of what the Mac is playing. This needs macOS 14.2 or later and the "System Audio Recording" permission, which macOS asks for the first time music plays. Nothing is recorded or saved, and it only listens while music is playing and the waveform is on screen. Without the permission, or on older macOS versions, the bars use a smooth built-in animation instead. **Music → Waveform → Status** shows which one is active.

**Album-art colours.** With **Appearance → Match the background to the album art** on, the notch and the waveform are tinted with the artwork's colours.

### Calendar and clock

The **Home** page has a calendar strip and a clock card.

**Calendar**

- The month, and the days around today with today highlighted in blue.
- Today's events with their colour, start time and a **countdown**: "in 12 min", or "now · ends in 20 min".
- A green **Join** button on events with a Zoom, Google Meet, Microsoft Teams, Webex, Whereby, FaceTime or Chime link.
- "Nothing for today" when your day is clear.
- **Countdown beside the notch** for the next meeting, from 15 minutes before it starts until it ends.
- **Meeting reminders**: a banner 1, 5, 10 or 15 minutes before each event, with **Join**, **Snooze 5 min** and **Dismiss**. A snoozed reminder comes back after 5 minutes.

Events come from the Calendar app, so iCloud, Google, Exchange and any other account you've added there all work.

**Clock**

- **Live clock** with 12- or 24-hour time, and seconds on or off.
- **Date** in your chosen format: "Friday, 9 October", "Fri, 9 Oct", "9 October 2026", "09/10/2026", or a custom pattern.
- **Custom text** of your own.
- **World clocks**: up to three cities under the clock, with "+1" or "-1" when it's already another day there. Add cities in **Clock & Calendar → World clocks**.

Custom date patterns use Unicode date symbols, for example:

| Pattern | Result |
| --- | --- |
| `EEEE d MMMM` | Friday 9 October |
| `EEE d MMM` | Fri 9 Oct |
| `d/M/yy` | 9/10/26 |
| `'Week' w` | Week 41 |

### Charging and battery

**Charging animation.** When you plug in the charger:

1. A green bolt sweeps in with a glowing trail.
2. The notch widens to show **"⚡ Charging…"**, a glowing bar that fills up to the battery level with sparks at its tip, and the percentage with a battery icon.
3. At 100% it shows **"✓ Fully Charged"**.

On Macs with a camera notch, the bar sits in a strip under the text so the camera doesn't hide it. A green glow around the notch can play with the animation. Use **Battery → Preview Charging** or **Preview Fully Charged** to see it any time.

**Smart charging**

- **Unplug reminder** at 80%, 85%, 90% or 95%, to help keep the battery healthy.
- **Low-battery warnings** at 20%, 10% and 5%, with the estimated time left.
- **Battery level beside the notch** while plugged in.
- **Battery details** on the Dashboard page and in settings: time to full or time left, charger wattage, battery health (current capacity as a percentage of the original), charge cycles and temperature.

### Drag-and-drop shelf and file transfers

**Shelf**

- **Drag any file towards the notch.** It opens on the Shelf page so you can drop it. The notch gives dragged files a larger target.
- Files stay on the shelf, even after restarting, until you remove them.
- **Drag files out** of the shelf into any app, folder or email.
- **Double-click** a file to open it.
- **Right-click** a file for: Open, Show in Finder, AirDrop, Share (AirDrop, Mail, Messages, Photos), Copy Text from Image, Copy, and Remove from Shelf.
- **AirDrop** sends every file on the shelf at once; the trash button clears the shelf.

The shelf keeps a reference to each file, not a copy; moving the original is fine.

**File transfers**

The Transfers column watches your Downloads folder:

- **Downloads in progress** from Safari, Chrome, Edge, Arc, Brave, Opera and Firefox, with their size and speed.
- **Recent files**, from downloads or AirDrop, received in the last 30 minutes. Click one to open it, or drag it out.
- While something downloads, its speed shows beside the notch.

### Clipboard history

- Remembers **text, links, images and files** you copy, with the app you copied from and how long ago.
- **Click** an item in the notch to copy it again; it moves to the top.
- **Right-click** to pin, unpin, open a link or delete.
- **Drag** an item straight into another app.
- Pinned items stay at the front and are never removed automatically.
- Keeps 20, 40, 80 or 150 items; **Clear** removes everything except pinned items.
- Copying something that's already in the list moves it to the top instead of adding a duplicate.

Passwords and other items that apps mark as private (1Password, Keychain and others) are **never saved**.

### Focus timer

A Pomodoro-style timer on the **Focus & Actions** page:

- A ring counts down the session, with start/pause, reset and skip buttons.
- Quick presets: **15, 25 or 50** minutes.
- Focus sessions alternate with **short breaks**; every few sessions there's a **long break**.
- The time left shows **beside the notch** while a session runs.
- When a session ends, a sound plays and a banner offers to start the break (or the next session).

Set the focus length, break lengths and sessions per cycle in **Focus & Actions**.

### Quick action launcher

Buttons on the **Focus & Actions** page that each do one thing:

| Type | Target example |
| --- | --- |
| Open app | `/Applications/Safari.app` (or choose it with **Choose…**) |
| Open link or folder | `https://github.com` or `~/Projects` |
| Run shell command | `open -a Xcode ~/Projects/App` |
| Run shortcut | The name of a Shortcuts shortcut |

Defaults: Terminal, Activity Monitor, Downloads, Dark Mode (switches light and dark mode) and Sleep Screen. The first tile is always **Copy Text** (screenshot OCR).

Edit, add, test (▶) and remove actions in **Focus & Actions → Quick actions**, or click **+** on the page. Icons are SF Symbols names, such as `terminal`, `globe` or `folder.fill`; apps use their own icon. Shell commands run in zsh as your user.

### Screenshot OCR

1. Press **⌃⌥⌘T**, click **Copy Text** on the Focus & Actions page, or choose **Notch → Copy Text from Screen…**.
2. Select part of the screen, as for a screenshot. Press Esc to cancel.
3. The text is recognised on your Mac and **copied to the clipboard**. A banner shows the first line and the number of lines.

It detects the language automatically. You can also right-click an image on the shelf and choose **Copy Text from Image**. The first time, macOS asks for Screen Recording permission.

### Developer dashboard

The **Dashboard** page shows:

- **CPU** usage, **memory** used (as in Activity Monitor) and **free disk space**, as rings.
- **Network:** live download and upload speed, a graph of the last 40 seconds, and your local IP address.
- **Dev servers:** every port your own apps are listening on, such as `:3000 node` or `:8000 Python`. Click one to open `http://localhost:<port>`. Right-click to copy the URL, or to stop the process. macOS's own services are hidden.
- **Battery:** level, time to full or time left, charger wattage, health and cycle count.

Sampling only runs while the page is open, so it costs nothing the rest of the time.

### Privacy status

Like on an iPhone, a dot appears beside the notch, and on the open dashboard:

- **Green**: the camera is in use.
- **Orange**: a microphone is recording.

The current state is also listed in **Dashboard & Privacy → Privacy status**.

### Notification hub

The **Notifications** page shows the **unread badges of the apps in your Dock**: Mail, Messages, Slack, Discord, WhatsApp and any other app with a red badge. Click an app to open it. The page icon gets a red dot when anything is unread.

macOS doesn't allow apps to read other apps' notifications, so this uses the Dock's badges. It needs Accessibility permission: click **Allow Accessibility Access** on the page or in settings, then turn on MacNotch in System Settings → Privacy & Security → Accessibility.

### Audio device controls

- **AirPlay button** on the music card: choose the speaker (output) and microphone (input). The current ones are ticked.
- **Volume slider** and **mute** on the music card.
- The same controls are in **Dashboard & Privacy → Audio devices**.

Some devices, such as HDMI displays, don't allow apps to change their volume; the slider is dimmed for those.

### Banners

Banners drop out of the notch for:

| Banner | Buttons |
| --- | --- |
| Meeting reminder | Join (with a meeting link), Snooze 5 min, Dismiss |
| Focus session or break finished | Start break or focus, Later |
| Battery reached the unplug level | OK |
| Low battery | OK |
| Text copied from the screen, or no text found | — |

Banners stay up while the pointer is over them. If several arrive together, they appear one after another.

### Custom text

Your own text beside the notch, set in **Clock & Calendar → Custom text**. On Macs without a camera notch it sits in the middle.

---

## Themes and visual effects

Choose a style in **Appearance → Notch style**:

| Style | Look |
| --- | --- |
| **Deep Black** | Pure black that blends into the camera notch |
| **Frosted** | Soft, milky glass |
| **Clear** | See-through Liquid Glass (macOS 26 and later; a light blur on older versions) |
| **Blur** | Heavy, dark blur |
| **Image** | Your own picture, with **Darken** and **Blur** sliders |

**Each style remembers its own:**

- **Border:** none, a glass rim, or a **neon glow** in a colour you choose (or the album art's colour), with an optional pulse.
- **Drop shadow** when the notch is open, with its size.
- **Corner radii:** the top curve where the notch meets the screen edge, and the bottom corners when closed and when open.

**Reset to Defaults** restores the current style's border, shadow and corners.

**Album-art colours** tints the background and the waveform with the colours of the song that's playing.

**Background animations:** None, **Aurora** (drifting colour glow), **Album colours** (the artwork, blurred and slowly turning) or **Waves** (glowing lines).

## Layout and animation

- **Closed and open modes:** a compact notch, and a dashboard that opens on hover with a spring animation.
- **Side width:** how wide the wings beside the notch are (**Notch → Side width**).
- **Expand on hover** can be turned off; the notch then opens only while you drag a file to it.
- **Animations, one switch per feature** (**Appearance → Animations**):

| Switch | Controls |
| --- | --- |
| Background | Aurora, Album colours, Waves or none |
| Music waveform | Moving bars; off shows still bars |
| Pop open when a song starts | The short peek on a new song |
| Charging animation | The plug-in sequence |
| Charging glow around the notch | The green outline while charging |
| Neon border pulse | Breathing neon glow |
| Smooth focus timer ring | Ring moves smoothly or once per second |
| Bouncy banners | Springy or plain fade |
| Page transitions | Animated page switches |

---

## Settings reference

The main window looks and works like System Settings. The **MacNotch** card at the top of the sidebar opens the **Overview**, and its switch turns the notch on or off from any page. The Overview has a live preview, every feature as a row with its own switch (click a row to customise it), getting-started tips, and a checklist of permissions with **Allow…** buttons. The sidebar's search field finds any section, and each section starts with a short explanation of what it's for.

Pages about how the notch looks show the same live preview: choose **Closed** or **Open**, and pick which dashboard page to preview. The panes are:

| Pane | Settings |
| --- | --- |
| **Overview** | Live preview, every feature with an on/off switch, tips, permissions |
| **Notch** | Show the notch, expand on hover, pop open on new songs, side width, dashboard pages, this Mac's notch size |
| **Appearance** | Style, picture, album-art colours, border, neon colour, shadow, corner radii, animations |
| **Clock & Calendar** | Custom text, 12/24-hour, seconds, date format, world clocks, calendar, meeting countdown, reminders |
| **Music** | Show music, progress bar, volume, Spotify buttons, artwork (poster or video), waveform, real-audio waveform, now playing |
| **Battery** | Charging animation and glow, level beside the notch, previews, unplug reminder, low-battery warnings, battery health |
| **Shelf & Clipboard** | Shelf page, clear shelf, download tracking, clipboard history and size, clear history |
| **Focus & Actions** | Focus and break lengths, sessions per cycle, OCR, quick actions editor |
| **Dashboard & Privacy** | Dashboard page, privacy dots, notification hub, audio output, input and volume |
| **General** | Open at login, version, quit |



## Permissions

macOS asks for each permission the first time the feature needs it. Everything else works without them.

| Permission | Used for | Where to change it |
| --- | --- | --- |
| Calendars | Events, countdown, reminders | Privacy & Security → Calendars |
| System Audio Recording | Waveform that follows the music | Privacy & Security → Screen & System Audio Recording |
| Screen Recording | Screenshot OCR | Privacy & Security → Screen & System Audio Recording |
| Accessibility | Notification hub (Dock badges) | Privacy & Security → Accessibility |
| Automation (Spotify, Music) | Spotify shuffle and repeat; controls if Now Playing is unavailable | Privacy & Security → Automation |
| Automation (browsers) | Finding the playing YouTube tab for video artwork | Privacy & Security → Automation |
| Downloads folder | File transfers | Privacy & Security → Files & Folders |

## Privacy and data storage

Everything stays on your Mac. MacNotch makes no network connections of its own.

| What | Where |
| --- | --- |
| Settings | `~/Library/Preferences/com.dd.macnotch.plist` |
| Background picture | `~/Library/Application Support/MacNotch/` |
| Clipboard history (text, links, file paths, image previews) | `~/Library/Application Support/MacNotch/Clipboard/` |
| Shelf | References to the original files, in the settings file |

- The waveform analyses sound in memory and keeps nothing.
- OCR runs on the Mac; the temporary screenshot is deleted straight away.
- Passwords and other private clipboard items are never saved.

To remove everything, quit the app and delete the app, the two folders and the settings file above.

## Limitations

- **Notification hub** shows Dock badge counts, not the notifications themselves, because macOS doesn't let apps read other apps' notifications.
- **Smart charging** reminds you to unplug; apps can't stop a Mac from charging. For automatic limits, use macOS's Optimised Battery Charging (System Settings → Battery).
- **Spotify** doesn't let apps like songs, so there's no like button.
- **Volume** can't be changed on some devices, such as HDMI and some USB outputs.
- **Clear** glass uses Liquid Glass on macOS 26 and later only.
- **Real-audio waveform** needs macOS 14.2 or later.
- **Ad-hoc signing:** because the app isn't signed with a developer certificate, macOS may ask for permissions again after an update. If a feature stops working after updating, switch MacNotch off and on in that permission's list in System Settings.

## Troubleshooting

| Problem | Try this |
| --- | --- |
| The notch doesn't appear | Check the switch at the top of the window, or press ⌃⌥⌘N |
| Music from a browser doesn't show | Start playback, then pause and play once; check it appears in Control Centre → Now Playing |
| Play/pause doesn't respond | Quit and reopen MacNotch; check that `/usr/bin/perl` exists |
| Waveform doesn't follow the music | Allow System Audio Recording; check **Music → Waveform → Status** |
| No calendar events | Allow Calendars access; make sure the calendars are enabled in the Calendar app |
| OCR copies nothing | Allow Screen Recording, then try again |
| Notification hub asks for access again | Remove MacNotch from the Accessibility list, then add it again |
| Downloads don't appear | Allow access to the Downloads folder; check **Track downloads** is on |
| Dragging a file doesn't open the notch | Make sure the Shelf page is turned on in **Notch → Dashboard pages** |

---

## Build from source

You need the Xcode Command Line Tools: `xcode-select --install`.

```bash
./build.sh            # builds "build/MacNotch.app" (arm64 + x86_64)
./build.sh --run      # build and launch
./create_dmg.sh       # build and package MacNotch-Installer.dmg
```

`build.sh` compiles the Swift app for both architectures, builds the Now Playing helper (`Adapter/NowPlayingAdapter.m`) as a universal library, assembles the bundle and signs it ad hoc.

The app icon is `Resources/AppIcon.png` (1024×1024, cut from `Resources/AppIcon-original.png`). After changing it, run `./scripts/make_icon.sh` to rebuild `Resources/AppIcon.icns`.

To distribute the app publicly, sign and notarise it with an Apple Developer ID: `SIGN_IDENTITY="Developer ID Application: …" ./build.sh`.

## Code layout

| File | What it does |
| --- | --- |
| `AppDelegate.swift` | App lifecycle, main window, menu bar menus, shortcuts |
| `NotchController.swift` | Notch window above the menu bar, notch detection, hover and drag tracking, banners, charging and battery alerts |
| `NotchViews.swift` | Notch shape, layout rules, closed and open notch, page bar, status beside the notch, borders, clock, waveform |
| `NotchCards.swift` | Home page: music card, output menu, sliders, calendar strip, clock card, world clocks |
| `DashboardPages.swift` | Banners, Shelf & Transfers, Clipboard, Focus & Actions, Dashboard and Notifications pages |
| `NotchBackground.swift` | Styles, custom picture, album-art tint, background animations |
| `ChargingView.swift` | Charging and fully charged animations |
| `MainView.swift` | Main window: sidebar, live preview and all settings panes |
| `AppSettings.swift` | Saved preferences, picture import, launch at login |
| `SettingsTypes.swift` | Theme options, dashboard pages, date formats, quick actions |
| `VideoArtwork.swift` | Finds the playing YouTube tab and shows it as muted, synced video artwork |
| `NowPlayingMonitor.swift` | Now Playing from any app, controls, seeking, artwork colours, Spotify |
| `Adapter/NowPlayingAdapter.m` | Helper loaded into `/usr/bin/perl` to read the system Now Playing state, which macOS only shares with Apple-signed processes |
| `AudioController.swift` | Audio devices, default output and input, volume and mute |
| `AudioSpectrum.swift` | System audio tap and FFT for the music-reactive waveform |
| `SystemMonitor.swift` | CPU, memory, disk, network, dev servers; camera and microphone use |
| `ClipboardMonitor.swift` | Clipboard history |
| `ShelfStore.swift` | Shelf files, sharing and download tracking |
| `FocusTimer.swift` | Focus timer and time formatting |
| `QuickActions.swift` | Quick actions and screenshot OCR |
| `NotificationHub.swift` | Unread badges from the Dock |
| `BatteryMonitor.swift` | Battery level, charger, time estimates and health |
| `CalendarMonitor.swift` | Today's events, meeting links, countdowns and reminders |
| `HotKey.swift` | System-wide shortcuts |

## Version history

**2.0**

- Redesigned main window in the style of System Settings: searchable sidebar with the MacNotch card, Overview with every feature and a permissions checklist, a short explanation on every section and a new live preview.
- Removed the GIF option.
- Renamed from Dynamic Notch to MacNotch (bundle ID `com.dd.macnotch`). On first launch, settings, the background picture and clipboard history are carried over automatically.
- Dashboard pages: Shelf & Transfers, Clipboard, Focus & Actions, Dashboard, Notifications.
- Music: progress bar with seeking, volume, output and input switching, Spotify shuffle, repeat and quick launch, music-reactive waveform, album-art tinting.
- Calendar: meeting countdown, reminders with Join and Snooze, world clocks, custom date formats.
- Smart charging: unplug reminder, low-battery warnings, battery health.
- Screenshot OCR, privacy dots, notification hub, developer dashboard.
- Themes: Image style, per-style border, neon glow, shadow and corner radii; one animation switch per feature.

**1.1**

- Music from any app, including YouTube in browsers, via the system Now Playing.
- Expanded notch with music card, calendar strip and clock.
- Frosted, Clear and Blur glass styles and background animations.
- Charging animation.
- Larger artwork; fixed play/pause and skip.

**1.0**

- First release: notch with GIF, music from Apple Music and Spotify, custom text and clock.
