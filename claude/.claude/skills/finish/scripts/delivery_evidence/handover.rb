require_relative "review_summary"

# The PR body source: what was delivered, what actually ran, how review closed
# and what stays limited. Built only from recorded entries, never from the plan.
class Handover
  def initialize(data, entries, review_markdown)
    @data = data
    @entries = entries
    @review = review_markdown
  end

  def to_markdown
    <<~MARKDOWN
      # Handover

      ## Delivered behaviour

      #{@data['delivered']}

      ## Verification

      #{verification}

      ## Review

      #{review}

      ## Limitations

      #{limitations}
    MARKDOWN
  end

  private

  def verification
    return "No checks recorded." if @entries.empty?

    @entries.map { |entry| item(entry) }.join("\n")
  end

  def item(entry)
    "- #{entry['status']}, #{entry['kind']}, #{entry['name']}: #{subject(entry)} → #{outcome(entry)}; " \
      "revision #{entry['head'][0, 8]}#{' plus uncommitted changes' if entry['dirty']}#{limits(entry)}."
  end

  def subject(entry)
    entry["command"] ? "`#{entry['command']}`" : entry["scenario"]
  end

  def outcome(entry)
    return entry["result"] unless entry["command"]

    [ "exit #{entry['exit_status']}", entry["summary"] ].compact.join(", ")
  end

  def limits(entry)
    entry["limits"] ? ". Limits: #{entry['limits']}" : ""
  end

  def review
    @review ? ReviewSummary.new(@review).to_markdown : "No review.md found."
  end

  def limitations
    items = @data["limitations"] + @entries.filter_map { |entry| "#{entry['name']}: #{entry['limits']}" if entry["limits"] }
    items.empty? ? "None recorded." : items.map { |text| "- #{text}" }.join("\n")
  end
end
