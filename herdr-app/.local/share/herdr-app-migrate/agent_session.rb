require_relative "command_line"

module HerdrAppMigration
  # One running Claude or Codex conversation, as `herdr agent list` reports it.
  class AgentSession < Data.define(
    :kind,  #: String
    :id,    #: String
    :cwd    #: String
  )
    # Folder and agent arrive as positional parameters, so no TUI data is ever part of a shell string.
    RESUME = <<~'SH'.tr("\n", " ").freeze
      cd "$1" || exit 1; shift;
      AGENT_THEN_SHELL='"$@" || printf "herdr-app-migrate: %s exited %s\n" "$1" "$?"; exec "${SHELL:-/bin/sh}" -l';
      exec "${SHELL:-/bin/sh}" -l -i -c "$AGENT_THEN_SHELL" sh "$@"
    SH

    #: -> Array[String]
    def resume_argv
      [ "sh", "-c", RESUME, "sh", cwd, *command ]
    end

    private

    def command
      case kind
      when "claude" then [ "claude", "--resume", id ]
      when "codex" then [ "codex", "resume", id ]
      else raise Refusal, "no way to resume a #{kind} agent"
      end
    end
  end
end
