require "open3"

# Private key material that git could stage in one working tree. The consent guard asks it before a
# staging command; no test file and no script holds a private key header, they build one at run time.
module KeyMaterial
  PRIVATE_KEY_LINE = /^-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----\r?$/
  CREDENTIALS_KEY = %r{(?:\A|/)config/credentials/[^/]+\.key\z}
  MAX_BYTES = 65_536

  # Paths, relative to the top level, of unignored untracked, modified or already staged files
  # that hold key material and that no global or system agent.keyMaterialExempt value names.
  # Empty outside a git repository.
  #: (String directory) -> Array[String]
  def self.stageable_in(directory)
    top = top_level(directory)
    return [] unless top

    exempt = exemptions(top)
    candidates(top).reject { |path| exempt.include?(path) }.select { |path| key_material?(File.join(top, path)) }
  end

  # True for a master.key or config/credentials/*.key path, or a file of at most MAX_BYTES
  # with a private key line.
  #: (String path) -> bool
  def self.key_material?(path)
    return true if File.basename(path) == "master.key" || path.match?(CREDENTIALS_KEY)

    File.file?(path) && File.size(path) <= MAX_BYTES && File.binread(path).match?(PRIVATE_KEY_LINE)
  rescue SystemCallError
    false
  end

  #: (String directory) -> String?
  def self.top_level(directory)
    output, status = Open3.capture2e("git", "-C", directory, "rev-parse", "--show-toplevel")
    status.success? ? output.strip : nil
  rescue SystemCallError
    nil
  end
  private_class_method :top_level

  # The key exemptions of one working tree: global and system values only.
  #: (String top) -> Array[String]
  def self.exemptions(top)
    output, = Open3.capture2("git", "-C", top, "config", "--show-scope", "--get-all", "agent.keyMaterialExempt")
    output.lines.filter_map { |line| line.chomp.split(/\s+/, 2).last if line.start_with?("global", "system") }
  end
  private_class_method :exemptions

  #: (String top) -> Array[String]
  def self.candidates(top)
    unstaged, = Open3.capture2("git", "-C", top, "ls-files", "-z", "--modified", "--others", "--exclude-standard")
    staged, = Open3.capture2("git", "-C", top, "diff", "--cached", "-z", "--name-only", "--diff-filter=ACM")
    (unstaged.split("\0") + staged.split("\0")).uniq
  end
  private_class_method :candidates
end
