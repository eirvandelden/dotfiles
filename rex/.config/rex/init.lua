require("switcher")

rex.bind("cmd+k", "com.superlogical.terminal.clear")
rex.bind("shift+cmd+k", "session.switch")

rex.bind("ctrl+s>ctrl+s", "pane.send_key", { key = "ctrl+s" })
rex.bind("ctrl+s>space", "agent_switcher")
rex.bind("ctrl+s>left", "pane.focus", { direction = "left" })
rex.bind("ctrl+s>down", "pane.focus", { direction = "down" })
rex.bind("ctrl+s>up", "pane.focus", { direction = "up" })
rex.bind("ctrl+s>right", "pane.focus", { direction = "right" })

-- Herdr's prefix keys. A key sequence cannot name "|", so shift+\ stands in for it.
rex.bind("ctrl+s>shift+\\", "pane.split.right")
rex.bind("ctrl+s>v", "pane.split.down")
rex.bind("ctrl+s>w", "pane.close")
rex.bind("ctrl+s>z", "pane.zoom")
rex.bind("ctrl+s>=", "pane.balance")

rex.bind("ctrl+s>t", "client.tab.new")
rex.bind("ctrl+s>shift+t", "client.tab.close")
rex.bind("ctrl+s>n", "client.tab.next")
rex.bind("ctrl+s>p", "client.tab.previous")
rex.bind("ctrl+s>r", "client.tab.rename")
for index = 1, 9 do
  rex.bind("ctrl+s>" .. index, "client.tab.goto", { index = index })
end

rex.bind("ctrl+s>shift+n", "session.new")

rex.bind("ctrl+3", "pane.send_key", { key = "esc" })
rex.bind("ctrl+4", "pane.send_key", { key = "ctrl+\\" })
rex.bind("ctrl+5", "pane.send_key", { key = "ctrl+]" })
rex.bind("ctrl+6", "pane.send_key", { key = "ctrl+shift+6" })
rex.bind("ctrl+7", "pane.send_key", { key = "ctrl+shift+-" })
rex.bind("ctrl+8", "pane.send_key", { key = "backspace" })
rex.bind("ctrl+-", "pane.send_key", { key = "ctrl+shift+-" })
