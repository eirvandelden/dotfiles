require_relative "command_line"

module HerdrAppAgents
  # One `ps -A -ww -o pid=,ppid=,args=` snapshot, taken on first use so a caller that never asks costs no ps call.
  class ProcessTable
    HOOK_RUNNERS = %w[sh bash zsh dash env ruby rv].freeze

    #: (?command_line: CommandLine) -> ProcessTable
    def self.snapshot(command_line: CommandLine.new)
      new(command_line: command_line)
    end

    #: (?Array[[Integer, Integer, Array[String]]]? rows, ?command_line: CommandLine?) -> void
    def initialize(rows = nil, command_line: nil)
      @rows = rows
      @command_line = command_line
    end

    # True when agent_pid is an ancestor of pid and every process between them is a hook runner.
    #: (Integer pid, Integer agent_pid) -> bool
    def spawned_by?(pid, agent_pid)
      visited = [ pid ]
      loop do
        parent = parents[visited.last]
        return false if parent.nil? || visited.include?(parent)
        return true if parent == agent_pid
        return false unless hook_runner?(parent)

        visited << parent
      end
    end

    # True when a live process carries session_id as one of its arguments. A secondary guard: a session
    # opened without its id in argv is caught by touched_since? through its own new record.
    #: (String session_id) -> bool
    def running?(session_id)
      rows.any? { |_pid, _ppid, argv| argv.include?(session_id) }
    end

    private

    #: -> Hash[Integer, Integer]
    def parents
      @parents ||= rows.to_h { |pid, ppid, _argv| [ pid, ppid ] }
    end

    #: (Integer pid) -> bool
    def hook_runner?(pid)
      row = rows.find { |candidate| candidate.first == pid }
      !row.nil? && HOOK_RUNNERS.include?(File.basename(row.last.first.to_s).delete_prefix("-"))
    end

    #: -> Array[[Integer, Integer, Array[String]]]
    def rows
      @rows ||= @command_line.text("ps", "-A", "-ww", "-o", "pid=,ppid=,args=").each_line.filter_map { |line| row(line) }
    end

    #: (String line) -> [Integer, Integer, Array[String]]?
    def row(line)
      pid, ppid, *argv = line.split
      [ Integer(pid), Integer(ppid), argv ] if ppid
    rescue ArgumentError, TypeError
      nil
    end
  end
end
