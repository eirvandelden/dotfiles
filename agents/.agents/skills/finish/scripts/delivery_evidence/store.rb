require "fileutils"
require "json"

# One JSON file per change in the shared git directory: it survives worktree
# removal and `finish`. It holds commands, statuses, revisions and written
# summaries, never command output.
class Store
  EMPTY = { "entries" => [], "delivered" => nil, "limitations" => [] }.freeze

  attr_reader :path #: String

  #: (String common_dir, String slug) -> void
  def initialize(common_dir, slug)
    @dir = File.join(common_dir, "herdr")
    @path = File.join(@dir, "deliver-#{slug}-evidence.json")
    @slug = slug
  end

  #: -> String
  def handover_path
    File.join(@dir, "deliver-#{@slug}-handover.md")
  end

  #: -> Hash[String, untyped]
  def data
    @data ||= File.exist?(path) ? JSON.parse(File.read(path)) : EMPTY.merge("entries" => [], "limitations" => [])
  end

  #: (Hash[String, untyped] entry) -> void
  def add(entry)
    data["entries"] << entry
    save
  end

  # The newest entry per name is the current one, in order of first appearance.
  #: -> Array[Hash[String, untyped]]
  def current
    data["entries"].group_by { |entry| entry["name"] }.values.map(&:last)
  end

  #: -> void
  def save
    FileUtils.mkdir_p(@dir)
    temporary = "#{path}.#{Process.pid}.tmp"
    File.write(temporary, JSON.pretty_generate(data))
    File.rename(temporary, path)
  end
end
