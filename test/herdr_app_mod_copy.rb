require "fileutils"
require "json"
require "tmpdir"

# Makes a herdr-app mod's main.js importable by node. herdr-app gives a mod the host modules `herdr` and
# `gpui-kit` at run time; node cannot resolve them, so a mod copy holds one module stub per host module.
module HerdrAppModCopy
  MODS = File.expand_path("../herdr-app/.config/herdr-app/mods", __dir__)
  # The names each module stub exports. A mod that imports a name not listed here fails in node with
  # "does not provide an export named <name>".
  HOST_EXPORTS = { "herdr" => %w[exec focused layout panes props run spaces], "gpui-kit" => %w[View div] }.freeze

  # Yields the file URL of a mod copy of <mod>/main.js; removes the copy afterwards.
  #: (String) { (String) -> untyped } -> untyped
  def with_mod_copy(mod)
    Dir.mktmpdir("herdr-app-mod") do |directory|
      HOST_EXPORTS.each { |name, exports| write_module_stub(directory, name, exports) }
      copy = File.join(directory, "main.mjs")
      FileUtils.cp(File.join(MODS, mod, "main.js"), copy)
      yield "file://#{copy}"
    end
  end

  private

  def write_module_stub(directory, name, exports)
    folder = File.join(directory, "node_modules", name)
    FileUtils.mkdir_p(folder)
    File.write(File.join(folder, "package.json"), JSON.generate(name: name, exports: "./index.mjs"))
    File.write(File.join(folder, "index.mjs"), exports.map { |export| stub_export(name, export) }.join("\n"))
  end

  def stub_export(module_name, export)
    return "export class View {}" if export == "View"

    %(export function #{export}() { throw new Error("host module #{module_name}.#{export} called in a node test"); })
  end
end
