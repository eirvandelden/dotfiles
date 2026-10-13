require "digest"

# A digest of the content a check depends on: committed and uncommitted
# content count alike, so an edit makes proof stale and a later commit of
# exactly the verified content keeps it fresh. The change folder is left out,
# so review and plan commits never force a rerun.
class Fingerprint
  def initialize(repo, folder)
    @repo = repo
    @folder = folder
  end

  def of(pathspecs)
    paths = listed(pathspecs)
    blobs = blob_ids(paths.select { |path| regular?(path) })
    lines = paths.map { |path| "#{path}\0#{marker(path, blobs)}" }
    Digest::SHA256.hexdigest(lines.sort.join("\n"))
  end

  private

  def listed(pathspecs)
    out = @repo.capture("ls-files", "-z", "--cached", "--others", "--exclude-standard", "--", *pathspecs)
    out.split("\0").uniq.reject { |path| path.start_with?("#{@folder}/") }
  end

  def full(path)
    File.join(@repo.toplevel, path)
  end

  def regular?(path)
    stat = File.lstat(full(path))
    stat.file?
  rescue SystemCallError
    false
  end

  # Typed markers keep a rename, a chmod, a deletion and a submodule move distinct.
  def marker(path, blobs)
    stat = File.lstat(full(path))
    return "link #{File.readlink(full(path))}" if stat.symlink?
    return submodule_marker(path) if stat.directory?

    mode = stat.mode.anybits?(0o111) ? "100755" : "100644"
    "file #{mode} #{blobs.fetch(path)}"
  rescue Errno::ENOENT
    "deleted"
  end

  def submodule_marker(path)
    return "submodule uninitialized" unless File.exist?(File.join(full(path), ".git"))

    stdout, _stderr, status = @repo.try("-C", path, "rev-parse", "HEAD")
    "submodule #{status.success? ? stdout.strip : 'unknown'}"
  end

  # hash-object reads newline-separated paths; a path holding a newline is hashed alone.
  def blob_ids(paths)
    plain, odd = paths.partition { |path| !path.include?("\n") }
    ids = plain.empty? ? [] : @repo.capture("hash-object", "--stdin-paths", stdin: plain.join("\n")).split("\n")
    plain.zip(ids).to_h.merge(odd.to_h { |path| [ path, @repo.capture("hash-object", "--", path).strip ] })
  end
end
