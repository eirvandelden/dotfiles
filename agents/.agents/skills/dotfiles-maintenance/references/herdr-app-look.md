# herdr-app look: Solunized themes, the right sidebar, and a color per core

The `cores` layout puts the sidebar on the right. Panes are cards on a frame, as in the herdr TUI. A personal space shows a blue accent. A work space shows an orange accent.

## The themes

The package holds four themes in `herdr-app/.config/herdr-app/themes/`: `solunized-light-blue`, `solunized-dark-blue`, `solunized-light-orange` and `solunized-dark-orange`. Each file is a byte-for-byte copy of a Dist theme. The solunized repository generates the Dist themes with `ruby generate_themes.rb`. Blue and orange differ only in `colors.accent`.

Copy the Dist themes after each change in the solunized repository. Run the loop from the root of the dotfiles repository:

```sh
for name in light-blue light-orange dark-blue dark-orange; do
  cp ~/Developer/solunized/dist/herdr-app/solunized-$name.json herdr-app/.config/herdr-app/themes/
done
```

Then run `bin/test test/herdr_app_look_test.rb`. `test_the_themes_match_the_solunized_dist` compares each copy with its Dist theme. Set `SOLUNIZED_DIR` to read another solunized checkout. The test skips when the checkout has no `dist/herdr-app`.

`settings.json` holds no `colors`. A settings `colors.accent` overrides the accent of every theme, so work spaces would stay blue.

## The theme pair per core

The root of `layouts/cores.json` names the personal pair as its theme. A fresh machine starts with it.

The `core-look` mod sits in a 0 px block at the end of the `work` column. Its props name the personal pair and the work pair. The root theme and the `personal` prop must stay equal; a test checks it. On each render the mod reads the focused space. A space with a `machine` is a work space and gets the work pair. A space without a machine is a personal space and gets the personal pair. The mod runs `app.theme` for each half that differs. `app.theme` writes the untracked `layouts/.state/cores.json`, never the layout file.

The decision is `themePick` in `mods/core-look/main.js`. The tests run it with `node` through a mod copy, which stubs the host modules `herdr` and `gpui-kit`.

## The hand-pick rule

A hand pick is a theme that is not one of the four Solunized themes, picked in the theme menu or with `app.theme`. The mod never replaces a hand pick, in either half. To go back to the color per core, pick a Solunized theme in both halves. The next render then sets the pair of the focused core.

## The work mark

`mods/spaces-cores/main.js` draws every work space avatar in one fixed color, `WORK_MARK` `#ea8347`, in light and dark. Orange belongs to work only, so `MARK.ansi3` is Solunized yellow `#d9b02a`. The shipped `picker` mod keeps its own colors, so it shows a work space's stored color, not the work mark.

## The tabs bar

`mods/tabs-cores/` is a clone of the shipped `tabs` mod. It has one change: its traffic-light padding drops the sidebar-width term, because the sidebar is not left of the tabs bar. The clone gets no herdr-app updates. When `test_the_cloned_tabs_mod_differs_from_tabs_only_in_the_padding` fails, clone `tabs` again in a sandbox home with `herdr-app do mod.clone '{"name":"tabs","as":"tabs-cores"}'`. Copy `main.js`, `mod.json` and the `.svg` files into the package. Do not copy `jsconfig.json` or the `.d.ts` files. Then remove ` - (sidebar?.hidden ? 0 : sidebar?.size?.px ?? 0)` from the padding line.

## Check a mod

Run `herdr-app check <mod folder>` with `HERDR_APP_HOME` set to a short scratch folder under `/tmp`. Never use `~/.config/herdr-app` for a check.

## Check the look in a sandbox

Never send a command or a keystroke to Etienne's own herdr-app window. Never start, stop or restart the `default` or `work` cores.

1. Make a short home path, or the socket path is too long: `ln -sfn <scratch>/hac4-home /tmp/hac4h`. Copy the package's `layouts/cores.json`, `mods/core-look/`, `mods/spaces-cores/`, `mods/tabs-cores/`, `themes/` and `settings.json` into it.
2. Start the sandbox: `HERDR_APP_HOME=/tmp/hac4h HC_SESSION=hac4 /Applications/Herdr.app/Contents/MacOS/Herdr &`. Note the pid. `HC_SESSION=hac4` keeps the sandbox off the real cores.
3. A work space needs a second machine. Register a scratch core as a machine of `hac4` only, for example `hac4w`, with `HC_SESSION=hac4 hc machine add`. Never register the real `work` core.
4. Run `export HERDR_APP_HOME=/tmp/hac4h`, then `herdr-app do layout.switch --name cores`. `herdr-app status` must show no errors.
5. herdr-app renders only a visible window. Before each `herdr-app shot` or `.state` read, run `herdr-app do window.maximize` twice.
6. Look at the shots. The sidebar is on the right. The first tab is clear of the traffic lights, with the sidebar shown and hidden (`herdr-app do layout.toggle --id sidebar`). The cards stand out from the frame.
7. Focus a personal space with `herdr-app do space.select --id <id>`. The focus border is blue, and `.state/cores.json` holds the personal pair. Focus a work space. The border is orange, `.state/cores.json` holds the work pair, and every work space avatar shows the work mark.
8. Run `herdr-app do app.theme --name graphite`, then focus a work space. Graphite stays.
9. Stop the sandbox window by its pid. Stop a scratch core only with `HC_SESSION=<name> hc server stop`.
