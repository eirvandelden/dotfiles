require "json"
require "open3"

module HerdrAppAgents
  # Raised when a check fails or hc/ps refuses; the executable turns it into one line.
  class Refusal < StandardError; end

  # Runs one hc or ps command as an argument list, never a shell string. HC_BIN and PS_BIN name test stubs.
  class CommandLine
    EXECUTABLES = { "hc" => "HC_BIN", "ps" => "PS_BIN" }.freeze

    #: (?core: String?) -> void
    def initialize(core: nil)
      @core = core
    end

    # Parsed JSON; Refusal on a non-zero exit, an "error" key or no JSON.
    #: (*String command) -> untyped
    def json(*command)
      answer = parse(text(*command))
      refuse(command, "answered no JSON") if answer.nil?
      refuse(command, answer["error"]) if answer.is_a?(Hash) && answer["error"]

      answer
    end

    # Stdout; Refusal on a non-zero exit.
    #: (*String command) -> String
    def text(*command)
      stdout, stderr, status = Open3.capture3(environment, executable(command.first), *command.drop(1))
      refuse(command, stderr.lines.first&.strip || "exit #{status.exitstatus}") unless status.success?

      stdout
    rescue SystemCallError => error
      refuse(command, "could not start: #{error.message}")
    end

    private

    #: -> Hash[String, String]
    def environment
      @core ? { "HC_SESSION" => @core } : {}
    end

    #: (String tool) -> String
    def executable(tool)
      override = ENV.fetch(EXECUTABLES.fetch(tool, ""), "")
      override.empty? ? tool : override
    end

    #: (String stdout) -> untyped
    def parse(stdout)
      JSON.parse(stdout)
    rescue JSON::ParserError
      nil
    end

    #: (Array[String] command, untyped reason) -> bot
    def refuse(command, reason)
      raise Refusal, "#{command.first(2).join(' ')}: #{reason}"
    end
  end
end
