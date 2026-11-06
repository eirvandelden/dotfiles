# The Rex tests run on DeliveryHarness, which stubs gh and herdr. This adds the stub for `rex` (keyed by
# its subcommand, the `-b` anchor of a split, and the method of a block call), the Rex environment and
# the log they need, so the harness itself holds no Rex code. It goes with the Rex tests.
#
# Answers come from stub_response keys: "rex split blkA" (the -b anchor), then "rex split"; "rex block ls";
# "rex block close"; a block method call (`rex api call block.method {"block_id":..,"method":..}`) answers to
# "rex <method> <block id>", then "rex <method>", for example "rex program_status blkA".
module RexHarnessCompat
  REX_SCRIPTS = File.join(File.expand_path("..", __dir__), "rex/.config/rex/scripts")
  REX_OPEN_PR_DASH = File.join(REX_SCRIPTS, "open-pr-dash.sh")
  OWN_BLOCK = "blkOwn".freeze
  SESSION = "S1".freeze

  REX_KEYS = <<~'RUBY'.freeze
    if name == "rex"
      words = ARGV.reject { |word| word == "-s" || word == "S1" }
      anchor = ARGV.each_cons(2).find { |flag, _| flag == "-b" }&.last
      keys = [ "rex #{words[0..1].join(' ')}" ]
      keys.unshift("rex #{words[0]} #{anchor}") if anchor
      keys << "rex #{words[0]}"
      if ARGV.include?("block.method")
        request = JSON.parse(ARGV[ARGV.index("block.method") + 1])
        keys = [ "rex #{request['method']} #{request['block_id']}", "rex #{request['method']}" ]
      end
    end
  RUBY

  def run_script(script, *arguments, rex: false, env: {}, **options)
    rex_environment = rex ? { "REX_SESSION" => SESSION, "REX_BLOCK" => OWN_BLOCK } : {}
    super(script, *arguments, env: rex_environment.merge(env), **options)
  end

  def default_responses
    super
    stub_response("rex *", { "stdout" => "{}" })
  end

  def rex_calls
    log_lines("rex")
  end

  private

  def install_stubs
    super
    path = File.join(@stub_bin, "rex")
    File.write(path, DeliveryHarness::STUB_SOURCE.sub('keys.unshift("gh pr checks', "#{REX_KEYS}keys.unshift(\"gh pr checks"))
    FileUtils.chmod(0o755, path)
  end
end

DeliveryHarness.prepend(RexHarnessCompat)
