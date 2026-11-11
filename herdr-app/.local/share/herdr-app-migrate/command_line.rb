require "json"
require "open3"

module HerdrAppMigration
  # Raised for every refusal, so the executable can turn one into a single stderr line.
  class Refusal < StandardError; end

  # Runs one herdr, herdr-app or hc command as an argument list, never a shell string.
  class CommandLine
    #: (*String command) -> Hash[String, untyped]
    def json(*command)
      stdout, stderr, status = Open3.capture3(*command)
      raise Refusal, "#{command.join(' ')} failed: #{stderr.strip}" unless status.success?

      parse(command, stdout)
    rescue SystemCallError => error
      raise Refusal, "#{command.join(' ')} could not start: #{error.message}"
    end

    private

    def parse(command, stdout)
      answer = JSON.parse(stdout)
      raise Refusal, "#{command.join(' ')} answered an error: #{answer['error']}" if answer.is_a?(Hash) && answer["error"]

      answer
    rescue JSON::ParserError
      raise Refusal, "#{command.join(' ')} answered no JSON"
    end
  end
end
