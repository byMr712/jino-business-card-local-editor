# jino-business-card-local-editor

> **Language:** English · [Русский](readme.md)

Local editor for a Jino (jino.ru) business card website. It is set up for the card at [mr712.ru](https://mr712.ru/), but works with any Jino business card — on first launch just provide the site address and the content is downloaded automatically. Since there is no direct access to server files, this repository keeps an editable copy of the card content (`body.txt`) and a mini preview server (`start-preview.bat`) that shows edits in the browser immediately after the file is saved.

## Requirements

- Windows 10/11
- Built-in Windows PowerShell 5.1+ (nothing to install)
- Any browser
- Internet — required for the first content import and for preview rendering
## Installation

1. Copy the repository folder anywhere (e.g. `E:\GitHub\jino-business-card-local-editor`)
2. Done — installation complete

You don't need to create `body.txt`: on first launch the editor will ask for your business card address and download the content from the site. If `body.txt` already exists next to `start-preview.bat`, no prompt appears.

## Quick start

### 1. Start the preview

Double-click `start-preview.bat`:

- **First run** (no `body.txt`) — enter the card address, e.g. `https://mr712.ru`. The script downloads the page and creates `body.txt` (content) + `card.json` (appearance settings: background, font color, etc.)
- **Subsequent runs** — the server starts immediately and opens a browser at `http://127.0.0.1:8077/`

```
==============================
Preview server : http://127.0.0.1:8077/
Source file    : E:\GitHub\...\body.txt
Render         : real businesscard.js (like production)
Edit body.txt  -> page reloads automatically
Re-sync        : run start-preview.bat with site URL as argument
Stop           -> Ctrl+C or close this window
==============================
```

Any launch method works: double-click, running from cmd, or via PowerShell ("Run with PowerShell" works too — the file is a bat+ps1 polyglot). To stop the server you can also double-click `stop-preview.bat` instead of using Ctrl+C or closing the console window.

### 2. Edit body.txt

Open `body.txt` in any editor and modify the HTML. The browser tab reacts **instantly** — polling every half-second plus a check when you switch to the tab; no F5 needed.

> Editing `body.txt` **does not change the live site** — it is a local copy of the content.
>
> A plain `start-preview.bat` launch (no arguments) **never overwrites** an existing `body.txt` — it works with it as is. Overwriting happens only on an explicit re-sync with the site address passed as an argument (and the previous version is saved to `body.txt.bak`).

### 3. Publish changes

1. Open the control panel at [jino.ru](https://jino.ru/)
2. Go to the sites section → business card → editor
3. Copy the contents of `body.txt` into the text (HTML) field and save
4. Check the live site

## Re-sync content from the site

If the card was already changed via the Jino panel and you need to fetch the content again:

```
start-preview.bat https://example.ru
```

The `https://` scheme is optional. The current `body.txt` is saved as `body.txt.bak` before being overwritten. Local edits will be discarded — use re-sync deliberately. `card.json` is updated together with `body.txt`.

### About card.json

`card.json` is generated automatically by the script (on first import or re-sync) and stores the appearance of the specific site: `bg_color`, `font_color`, `layout`, favicon and the rest of the `bcData` fields except the content itself. It is a service file:

- it belongs to the site it was imported from — another site will have a different one;
- it is rewritten on every re-sync;
- there is no need to edit it manually;
- if deleted, the preview keeps working with built-in defaults (black background, white text).

## How start-preview.bat works

`start-preview.bat` is a thin launcher; all server code lives in `preview.ps1`.

| Component | Description |
|-----------|----------|
| Port | `127.0.0.1:8077` (if busy — automatically takes 8078–8099) |
| Server | Single-threaded TCP HTTP server on `System.Net.Sockets.TcpListener`, no logging |
| Import | First run: site address is asked interactively or taken from the argument; `var bcData` is extracted from the page → `text` goes to `body.txt`, other fields — to `card.json` |
| `GET /` | Builds a **production replica** on the fly: `<div id="root">` + inline `var bcData = {...}` (fields from `card.json` + text from `body.txt`) + the real Jino renderer `businesscard.js` — looks like the original |
| `GET /~mtime` | Returns the last modification time of `body.txt` (used for auto-reload) |
| Auto-reload | JS on the page polls `/~mtime` every 500 ms + when the tab gets focus; if the value changed — `location.reload()` |

The renderer requires internet access (the `businesscard.js` script loads from the Jino CDN). If the CDN is unreachable, a fallback kicks in — HTML is injected into the page without the renderer wrapper.

The server writes nothing to disk, does not modify `body.txt` and creates no temporary files. Stop with Ctrl+C in the console, by closing the window, or by running `stop-preview.bat`.

The environment variable `MR712_NO_BROWSER=1` suppresses automatic browser opening (useful for automated tests).

## How a business card website is structured: a look at mr712.ru

The live page is a static shell provided by Jino:

- `<html data-page="businesscard">` loads `//parking-static.jino.ru/static/businesscard.js?1.45.0`
- Page body contains: `<div id="root"></div>` and an inline `<script> var bcData = {...}; </script>`
- `businesscard.js` renders the `bcData.text` field (the entire card HTML as a single JSON string) into `#root`
- Page background is `bcData.bg_color` (#000000), favicon is stored on `media.jino.ru`

Card content consists of:

- Header: avatar (inline base64 JPEG ~142 KB ≈ 96% of page weight), **Mr712** heading, tagline «Тот самый»
- CSS-grid with 3 columns and 6 link cards: YouTube, Telegram, TikTok, Instagram, GitHub, 4PDA
- Footer: «Сайт оплачен до 29 мая 2028»
- Inline `<style>` with responsive layout: grid becomes 2 columns at width ≤600px

## Files

| File | Description |
|------|----------|
| `body.txt` | Card content — the main editable file (HTML + inline CSS) |
| `card.json` | Card appearance settings (background, font color, etc.), created when importing from the site; tied to that site, see "About card.json" |
| `start-preview.bat` | Preview server launcher |
| `preview.ps1` | Preview server code + import/re-sync logic |
| `stop-preview.bat` | Stops the preview server (finds PowerShell processes running `preview.ps1`) |
| `body.txt.bak` | Backup of the previous content version (created on re-sync) |

## Jino business card format limitations

Content is pasted into the Jino editor, therefore:

- Only HTML + inline styles; the `<style>` tag is allowed
- No external or inline scripts
- Keep the structure: header / link-card grid / footer / responsive `<style>`
