module LefthookBinary
  RV_GLOB = File.join(
    Dir.home, ".local/share/rv/rubies/*/lib/ruby/gems/*/gems/lefthook-*/libexec/lefthook-darwin-arm64/lefthook"
  )
  MISSING_MESSAGE =
    "lefthook not found: not on PATH (checked LEFTHOOK_BIN and `which lefthook`) " \
    "and no rv install matched #{RV_GLOB}"

  def self.locate
    from_env || from_path || Dir.glob(RV_GLOB).find { |f| File.executable?(f) }
  end

  def self.from_env
    ENV["LEFTHOOK_BIN"] if ENV["LEFTHOOK_BIN"] && File.executable?(ENV["LEFTHOOK_BIN"])
  end

  def self.from_path
    found = `which lefthook 2>/dev/null`.strip
    found unless found.empty?
  end
end
