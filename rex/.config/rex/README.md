# rex

Key bindings for Rex, set up to match the herdr prefix keys. The prefix is `ctrl+s`.

| Keys | Does |
| --- | --- |
| `ctrl+s ctrl+s` | Sends a literal `ctrl+s` to the shell. |
| `ctrl+s space` | Opens the agent switcher. |
| `ctrl+s` arrows | Focus the pane in that direction. |
| `ctrl+s \|` | Split right. Typed as `shift+\`. |
| `ctrl+s v` | Split down. |
| `ctrl+s w` | Close the pane. |
| `ctrl+s z` | Zoom the pane. Press again to restore. |
| `ctrl+s =` | Balance the splits. |
| `ctrl+s t` / `shift+t` | New tab / close tab. |
| `ctrl+s n` / `p` | Next / previous tab. |
| `ctrl+s 1`..`9` | Go to tab by number. |
| `ctrl+s r` | Rename the tab. |
| `ctrl+s shift+n` | New session. |

Not bound, because Rex has no matching action: focus agent (`prefix+alt+1..9`), switch workspace (`prefix+shift+1..9`), and the file viewer and lazygit keys (`prefix+f`, `prefix+g`).

## Switching from a loose file

Rex reads `~/.config/rex/init.lua`. If that is a real file, stow refuses to link over it. Move it away, then link the package and reload:

```bash
trash ~/.config/rex/init.lua
stow -t "$HOME" rex
rex config reload
```
