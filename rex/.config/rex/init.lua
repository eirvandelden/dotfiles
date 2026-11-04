require("switcher")

rex.bind("cmd+k", "com.superlogical.terminal.clear")
rex.bind("shift+cmd+k", "session.switch")

rex.bind("ctrl+s>ctrl+s", "pane.send_key", { key = "ctrl+s" })
rex.bind("ctrl+s>space", "agent_switcher")
rex.bind("ctrl+s>left", "pane.focus", { direction = "left" })
rex.bind("ctrl+s>down", "pane.focus", { direction = "down" })
rex.bind("ctrl+s>up", "pane.focus", { direction = "up" })
rex.bind("ctrl+s>right", "pane.focus", { direction = "right" })

rex.bind("ctrl+3", "pane.send_key", { key = "esc" })
rex.bind("ctrl+4", "pane.send_key", { key = "ctrl+\\" })
rex.bind("ctrl+5", "pane.send_key", { key = "ctrl+]" })
rex.bind("ctrl+6", "pane.send_key", { key = "ctrl+shift+6" })
rex.bind("ctrl+7", "pane.send_key", { key = "ctrl+shift+-" })
rex.bind("ctrl+8", "pane.send_key", { key = "backspace" })
rex.bind("ctrl+-", "pane.send_key", { key = "ctrl+shift+-" })
