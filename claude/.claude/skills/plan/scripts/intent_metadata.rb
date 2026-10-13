# Reads the metadata paragraph of an intent.md. Shared by auto-accept and start-delivery, so both
# agree on what "accepted" and "Delivery: autonomous" mean.
#
# The paragraph is the lines straight after the "# Intent: <title>" line. Only Author, Status,
# Type and Delivery fields at column zero belong to it, so a Markdown example further down never
# grants autonomy. Fields may share a line, separated by ". ". Conflicting values refuse.
module IntentMetadata
  FIELD = /\A(Author|Status|Type|Delivery): (.*)\z/
  SEPARATOR = /\. (?=(?:Author|Status|Type|Delivery): )/
  ACCEPTED = /\Aaccepted(?: \(\d{4}-\d{2}-\d{2}\))?\z/

  module_function

  def accepted?(text)
    statuses = values(fields(header(text)), "Status")
    statuses.one? && statuses.first.match?(ACCEPTED)
  end

  def autonomous?(text)
    values(fields(header(text)), "Delivery") == [ "autonomous" ]
  end

  def header(text)
    return "" unless text.lines.first&.match?(/\A# Intent: \S/)

    metadata = text.lines.drop(1).drop_while { |line| line.strip.empty? }
    metadata.take_while { |line| line.match?(/\A(?:Author|Status|Type|Delivery): /) }.join
  end

  def fields(header)
    parts = header.lines.flat_map { |line| line.chomp.split(SEPARATOR) }
    parts.filter_map { |part| part.match(FIELD)&.captures }
  end

  def values(fields, name)
    fields.filter_map { |key, value| value.delete_suffix(".") if key == name }.uniq
  end
end
