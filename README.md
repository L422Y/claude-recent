# claude-recent

A recent-sessions panel for the Claude desktop app's Code tab on macOS. It docks to the right of the Claude window and lists every Code session by when you last worked in it. Click a row to switch the app to that session.

<p>
  <img src="docs/panel-dark.jpg" width="310" alt="The panel in dark mode, showing sessions grouped under Waiting on you, Today, Yesterday and This week">
  <img src="docs/panel-light.jpg" width="310" alt="The same panel in light mode">
</p>

The sidebar in the app changes often and doesn't keep a good recent view. This panel shows:

- A "Waiting on you" group at the top for sessions from the past week that are blocked on you or ready for review. A red bar marks blocked sessions and a blue bar marks ones ready for review.
- Sessions grouped by Today, Yesterday, This week, or by project.
- The app's one-line summary of where each session stands.
- Spawned sessions and forks indented under the session they came from.
- A filter box. Press `/` to focus it, arrow keys to move, Enter to open.

## Requirements

- macOS with the Claude desktop app
- Python 3, already on most Macs
- [Hammerspoon](https://www.hammerspoon.org) for the docked panel. Without it, the list still works in a browser tab.

## Install

```bash
git clone https://github.com/L422Y/claude-recent.git ~/claude-recent
```

```bash
brew install --cask hammerspoon
```

```bash
mkdir -p ~/.hammerspoon && ln -s ~/claude-recent/hammerspoon/claude-recent.lua ~/.hammerspoon/claude-recent.lua
```

```bash
echo 'recent = require("claude-recent")' >> ~/.hammerspoon/init.lua
```

Then open Hammerspoon and give it Accessibility access in System Settings → Privacy & Security → Accessibility. Quit Hammerspoon and open it again afterwards, since it only picks up the permission on a fresh start. Turn on "Launch Hammerspoon at login" in its preferences if you want the panel after a reboot.

Hammerspoon starts the list's local server for you. To use the list without Hammerspoon, start the server yourself and open http://127.0.0.1:7799 in a browser:

```bash
python3 ~/claude-recent/recent.py
```

## Using it

- The panel floats beside Claude while Claude is the front app and drops behind other apps when you switch away.
- Drag the panel's left edge and the Claude window resizes to fill the rest of the screen. Resize Claude and the panel takes what's left. The width is remembered.
- `ctrl+alt+R` hides or shows the panel.
- "Group by project" and "Show archived" at the top change the list. The panel remembers both.

To try it with made-up sessions, which is how the screenshots were made:

```bash
python3 ~/claude-recent/recent.py --demo
```

Then open http://127.0.0.1:7798.

## How it works

The desktop app keeps a JSON file for each Code session in `~/Library/Application Support/Claude/claude-code-sessions`. `recent.py` reads those files and serves the list on `127.0.0.1:7799`. Clicking a row runs `open claude://claude.ai/epitaxy/<session id>`, the link the app uses for its own sessions. The server only accepts that request from its own page, so other websites can't trigger it.

The Hammerspoon script shows the page in a floating window. Claude's window doesn't report being resized, so the script checks both windows four times a second and moves whichever one didn't change. That's why it needs Accessibility access.

## Limits

- Those session files are the app's internal format, not a public interface. An app update can rename fields or move them, and the list can come up empty until this is updated.
- It can't archive sessions. Archiving touches more of the app's state than one file, and the app's archive action isn't reachable from outside it.
- Only the main Claude window docks. Pop-out session windows are left alone.
- The page loads IBM Plex Sans from Google Fonts. Offline, it falls back to the system font.

## Uninstall

```bash
rm ~/.hammerspoon/claude-recent.lua
```

Remove the `require("claude-recent")` line from `~/.hammerspoon/init.lua`, then delete the `~/claude-recent` folder.

## License

MIT
