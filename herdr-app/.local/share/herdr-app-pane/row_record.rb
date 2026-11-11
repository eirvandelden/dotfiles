require "fileutils"
require "open3"
require_relative "command_line"

module HerdrAppPane
  # <git-common-dir>/herdr-app/stage-panes-<row>: the hc terminals of one row's stage panes, one per line,
  # in the order they opened. The intent skill writes the intent terminal to intent-pane-<row> beside it.
  class RowRecord
    # The git common dir of the current directory, where every worktree of a repository finds the same record.
    #: -> String
    def self.common_dir
      stdout, status = Open3.capture2("git", "rev-parse", "--path-format=absolute", "--git-common-dir", err: File::NULL)
      raise Refusal, "not inside a git repository: the row record lives in its git directory" unless status.success?

      stdout.strip
    end

    #: (String common_dir, String row) -> void
    def initialize(common_dir, row)
      directory = File.join(common_dir, "herdr-app")
      @path = File.join(directory, "stage-panes-#{row}")
      @intent_path = File.join(directory, "intent-pane-#{row}")
    end

    #: -> bool
    def exist?
      File.exist?(@path)
    end

    #: -> Array[String]
    def terminals
      exist? ? lines(@path) : []
    end

    # The terminal the intent skill recorded for this row, if any.
    #: -> String?
    def intent
      File.exist?(@intent_path) ? lines(@intent_path).first : nil
    end

    #: (String terminal) -> void
    def append(terminal)
      FileUtils.mkdir_p(File.dirname(@path))
      File.write(@path, "#{terminal}\n", mode: "a")
    end

    #: (String terminal) -> void
    def drop(terminal)
      kept = terminals - [ terminal ]
      File.write(@path, kept.map { |line| "#{line}\n" }.join) if exist?
    end

    #: -> void
    def delete
      FileUtils.rm_f(@path)
    end

    private

    #: (String path) -> Array[String]
    def lines(path)
      File.readlines(path, chomp: true).map(&:strip).reject(&:empty?)
    end
  end
end
