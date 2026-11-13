require "fileutils"
require "json"
require "shellwords"
require "tempfile"
require "time"
require_relative "command_line"
require_relative "core"

module HerdrAppAgents
  # Which agent session last started in which terminal of which core.
  class AgentRecord < Data.define(
    :core,                  #: String
    :terminal,              #: String
    :kind,                  #: String
    :session_id,            #: String
    :cwd,                   #: String
    :transcript_path,       #: String
    :flags,                 #: Array[String]
    :recorded_at,           #: Time
    :resumed_at,            #: Time?
    :transcript_written_at  #: Time?
  )
    KINDS = %w[claude codex].freeze
    SESSION_ID = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/
    TERMINAL = /\A[A-Za-z0-9][A-Za-z0-9_-]{0,63}\z/
    CLAUDE_MODES = %w[acceptEdits auto bypassPermissions dontAsk manual plan].freeze
    CODEX_SANDBOXES = %w[read-only workspace-write danger-full-access].freeze
    CODEX_APPROVALS = %w[untrusted on-failure on-request never].freeze
    # Flag name => the values it accepts, or nil for a flag without a value.
    FLAGS = {
      "claude" => { "--dangerously-skip-permissions" => nil, "--allow-dangerously-skip-permissions" => nil,
                   "--permission-mode" => CLAUDE_MODES },
      "codex" => { "--dangerously-bypass-approvals-and-sandbox" => nil, "--approve-for-me" => nil,
                   "-s" => CODEX_SANDBOXES, "--sandbox" => CODEX_SANDBOXES,
                   "-a" => CODEX_APPROVALS, "--ask-for-approval" => CODEX_APPROVALS }
    }.freeze
    FIELDS = %w[core terminal kind session_id cwd transcript_path flags recorded_at resumed_at].freeze

    # The whitelisted permission flags in a foreground argv; everything else is dropped.
    #: (String kind, Array[String] argv) -> Array[String]
    def self.flags_of(kind, argv)
      allowed = FLAGS.fetch(kind, {})
      argv.each_with_index.flat_map do |word, index|
        name, inline = word.split("=", 2)
        next [] unless allowed.key?(name)

        flag_words(name, allowed[name], inline || argv[index + 1])
      end
    end

    #: (String name, Array[String]? values, String? value) -> Array[String]
    def self.flag_words(name, values, value)
      return [ name ] if values.nil?

      values.include?(value) ? [ name, value ] : []
    end
    private_class_method :flag_words

    # Refusal on any field outside its rule: kind claude|codex, SESSION_ID, Core::NAME, TERMINAL,
    # absolute cwd and transcript_path, flags that flags_of(kind, flags) keeps unchanged, ISO 8601 times.
    # transcript_written_at is not stored: the caller passes the mtime it observed once at load (nil when gone).
    #: (String json, ?transcript_written_at: Time?) -> AgentRecord
    def self.parse(json, transcript_written_at: nil)
      fields = JSON.parse(json)
      raise Refusal, "record is not an object" unless fields.is_a?(Hash) && fields.keys.sort == FIELDS.sort

      build(fields, transcript_written_at)
    rescue JSON::ParserError, ArgumentError, TypeError => error
      raise Refusal, "unreadable record: #{error.message}"
    end

    #: (Hash[String, untyped] fields, Time? transcript_written_at) -> AgentRecord
    def self.build(fields, transcript_written_at)
      check(fields)
      new(**fields.except("recorded_at", "resumed_at").transform_keys(&:to_sym), recorded_at: Time.iso8601(fields["recorded_at"]),
          resumed_at: fields["resumed_at"] && Time.iso8601(fields["resumed_at"]), transcript_written_at: transcript_written_at)
    end
    private_class_method :build

    #: (Hash[String, untyped] fields) -> void
    def self.check(fields)
      rules = { "kind" => KINDS.include?(fields["kind"]), "session_id" => SESSION_ID.match?(fields["session_id"].to_s),
                "core" => Core::NAME.match?(fields["core"].to_s), "terminal" => TERMINAL.match?(fields["terminal"].to_s),
                "cwd" => path?(fields["cwd"]), "transcript_path" => path?(fields["transcript_path"]),
                "flags" => fields["flags"].is_a?(Array) && flags_of(fields["kind"], fields["flags"]) == fields["flags"] }
      bad = rules.reject { |_field, valid| valid }.keys
      raise Refusal, "record field #{bad.first} is not valid" unless bad.empty?
    end
    private_class_method :check

    #: (untyped value) -> bool
    def self.path?(value)
      value.is_a?(String) && value.start_with?("/") && !value.match?(/[[:cntrl:]]/)
    end

    # One record per session id: the newest recorded_at; a tie keeps none.
    #: (Array[AgentRecord] records) -> Array[AgentRecord]
    def self.distinct(records)
      records.group_by(&:session_id).filter_map do |_id, group|
        newest, runner_up = group.sort_by { |record| -record.recorded_at.to_f }
        newest unless runner_up && runner_up.recorded_at == newest.recorded_at
      end
    end

    # Every field except transcript_written_at.
    #: -> String
    def to_json(*)
      JSON.generate(to_h.except(:transcript_written_at).transform_values { |value| value.is_a?(Time) ? value.utc.iso8601(3) : value })
    end

    # True when recorded_at, resumed_at or transcript_written_at is at or after started_at.
    #: (Time started_at) -> bool
    def touched_since?(started_at)
      [ recorded_at, resumed_at, transcript_written_at ].compact.any? { |time| time >= started_at }
    end

    #: (Time at) -> AgentRecord
    def resumed(at)
      with(resumed_at: at)
    end

    # Shellwords-quoted: cd <cwd> && claude --resume <id> <flags> | cd <cwd> && codex resume <id> <flags>.
    #: -> String
    def resume_line
      command = kind == "claude" ? [ "claude", "--resume", session_id ] : [ "codex", "resume", session_id ]
      "cd #{Shellwords.escape(cwd)} && #{Shellwords.join(command + flags)}"
    end
  end

  # The agent records under <state>/herdr-app/agents/<core>/<terminal>.json.
  class RecordStore
    #: -> String
    def self.default_root
      state = ENV.fetch("XDG_STATE_HOME", "")
      File.join(state.empty? ? File.expand_path("~/.local/state") : state, "herdr-app/agents")
    end

    #: (?root: String) -> void
    def initialize(root: self.class.default_root)
      @root = root
    end

    # Atomic: a temporary file in the same folder, mode 0600, then rename.
    #: (AgentRecord record) -> void
    def write(record)
      folder = File.join(@root, record.core)
      FileUtils.mkdir_p(folder)
      Tempfile.create([ ".#{record.terminal}", ".tmp" ], folder) do |file|
        file.chmod(0o600)
        file.write(record.to_json)
        file.close
        File.rename(file.path, File.join(folder, "#{record.terminal}.json"))
      end
    end

    # Each file AgentRecord.parse accepts, with its transcript mtime read once; any other file warns and is skipped.
    #: -> Array[AgentRecord]
    def records
      Dir.glob(File.join(@root, "*", "*.json")).sort.filter_map { |path| load(path) }
    end

    # Runs the block under a non-blocking flock on restore.lock; Refusal when another restore holds it.
    #: [T] () { () -> T } -> T
    def exclusively(&)
      FileUtils.mkdir_p(@root)
      File.open(File.join(@root, "restore.lock"), File::CREAT | File::RDWR, 0o600) do |lock|
        raise Refusal, "another restore is running" unless lock.flock(File::LOCK_EX | File::LOCK_NB)

        yield
      end
    end

    # Appends one timestamped line to recorder.log.
    #: (String reason) -> void
    def note(reason)
      FileUtils.mkdir_p(@root)
      File.open(File.join(@root, "recorder.log"), "a") { |log| log.puts("#{Time.now.utc.iso8601} #{reason.to_s.lines.first&.strip}") }
    end

    private

    #: (String path) -> AgentRecord?
    def load(path)
      record = AgentRecord.parse(File.read(path), transcript_written_at: written_at(path))
      return record if File.join(@root, record.core, "#{record.terminal}.json") == path

      warn("herdr-app-agents: #{path} does not match its own record")
    rescue Refusal, SystemCallError => error
      warn("herdr-app-agents: skipped #{path}: #{error.message}")
    end

    # The transcript's mtime, read from the record's own file once; nil when the transcript is gone.
    #: (String path) -> Time?
    def written_at(path)
      transcript = JSON.parse(File.read(path))["transcript_path"]
      File.mtime(transcript) if AgentRecord.path?(transcript)
    rescue JSON::ParserError, SystemCallError
      nil
    end
  end
end
