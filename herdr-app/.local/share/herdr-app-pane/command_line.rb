require "json"
require "open3"

module HerdrAppPane
  # Raised when herdr-app or hc refuses; the CLI turns it into one stderr line and exit 1.
  class Refusal < StandardError; end

  # Runs one herdr-app or hc command as an argument list, never a shell string, and answers its JSON.
  # HERDR_APP_BIN and HC_BIN name the executables, so a test can stub them; else they come from PATH.
  class CommandLine
    EXECUTABLES = { "herdr-app" => "HERDR_APP_BIN", "hc" => "HC_BIN" }.freeze

    #: (*String command) -> untyped
    def json(*command)
      stdout, stderr, status = Open3.capture3(executable(command.first), *command.drop(1))
      answer = parse(stdout)
      refuse(command, error_of(answer) || stderr.lines.first&.strip) if error_of(answer) || !status.success?
      refuse(command, "answered no JSON") if answer.nil?

      answer
    rescue SystemCallError => error
      refuse(command, "could not start: #{error.message}")
    end

    private

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

    #: (untyped answer) -> String?
    def error_of(answer)
      answer["error"] if answer.is_a?(Hash)
    end

    # The first three words name the call; a pane.split request holds a whole prompt.
    #: (Array[String] command, String? reason) -> bot
    def refuse(command, reason)
      raise Refusal, "#{command.first(3).join(' ')}: #{reason}"
    end
  end
end
