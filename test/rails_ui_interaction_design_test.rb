#!/usr/bin/env ruby
require "minitest/autorun"
require "yaml"

# The rails-ui interaction-design reference is first-party guidance an agent acts on: where the action row
# goes, where Delete lives and how a table fits the page (docs/changes/rails-ui-action-row-and-tables/plan.md).
class RailsUiInteractionDesignTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  SKILL_DIR = File.join(REPO_ROOT, "claude/.claude/skills/rails-ui")

  def test_edit_page_puts_delete_far_left_and_cancel_then_save_on_the_right
    section = section(reference, "### Edit pages and sheets")
    assert_match(/save sheet/i, section)
    assert_match(/`Delete…`/, section)
    assert_match(/red/i, section)
    assert_match(/far left/i, section)
    assert_match(/apart/i, section)
    assert_match(/`Cancel` and `Save`[^.]*together[^.]*right/i, section)
    assert_match(/`Save`[^.]*rightmost[^.]*default/i, section)
  end

  def test_confirmation_dialog_puts_cancel_directly_left_of_red_delete_and_return_triggers_cancel
    section = section(reference, "### Confirmation dialogs")
    assert_match(/red `Delete`[^.]*rightmost/i, section)
    assert_match(/`Cancel`[^.]*directly left of (it|the red)/i, section)
    assert_match(/autofocus/, section)
    assert_match(/`Return`[^.]*`Cancel`/, section)
    assert_match(/far-left rule[^.]*never applies/i, section)
    assert_match(/`Cancel`[^.]*closes the dialog/i, section)
    assert_match(/command="close"/, section)
    assert_match(/method="dialog"/, section)
  end

  def test_far_left_rule_is_scoped_to_edit_pages_and_save_sheets
    shared = section(reference, "## Action rows").split(/^### /).first
    refute_match(/far left/i, shared.gsub(/^.*edit pages? and (save )?sheets?.*$/i, ""))
    assert_match(/Edit pages and sheets/, shared)
    assert_match(/Confirmation dialogs/, shared)
  end

  def test_shared_action_rows_point_to_the_show_page_exception
    shared = section(reference, "## Action rows").split(/^### /).first
    assert_match(/Where Delete lives/, shared)
  end

  def test_delete_opens_a_dialog_outside_the_edit_form
    text = section(reference, "### Edit pages and sheets") + section(reference, "### Confirmation dialogs")
    assert_match(/<dialog>/, text)
    assert_match(/commandfor/, text)
    assert_match(/nested forms?/i, text)
    assert_match(/data-turbo-confirm/, text)
    assert_match(/never[^.]*data-turbo-confirm|not[^.]*data-turbo-confirm|no `?data-turbo-confirm/i, text)
  end

  def test_delete_lives_only_on_the_edit_page
    section = section(reference, "### Where Delete lives")
    assert_match(/editable fields/i, section)
    assert_match(/only on the edit page/i, section)
    assert_match(/never in an index table row/i, section)
    assert_match(/never on[^.]*show page/i, section)
    assert_match(/never between other buttons/i, section)
  end

  def test_record_without_editable_fields_puts_delete_on_its_show_page_outside_menus
    section = section(reference, "### Where Delete lives")
    assert_match(/no editable fields/i, section)
    assert_match(/show page/i, section)
    assert_match(/visible red `Delete…`/, section)
    assert_match(/never[^.]*(menu|pull-down)/i, section)
  end

  def test_no_rule_puts_a_third_button_left_of_cancel_or_delete_in_a_row
    refute_match(/third[^.\n]*(button)?[^.\n]*left of `Cancel`/i, reference)
    refute_match(/third dismissal button/i, reference)
    reference.each_line do |line|
      next unless line =~ /table row|index row|each row/i && line =~ /delete/i

      assert_match(/never|no |not |without/i, line, "a line allows Delete in a row: #{line}")
    end
  end

  def test_default_button_is_save_on_edit_pages_and_cancel_in_destructive_confirmations
    section = section(reference, "## Default button")
    assert_match(/safest forward action/i, section)
    assert_match(/`Save`/, section)
    assert_match(/`Cancel`/, section)
    assert_match(/never[^.]*`Delete`[^.]*default|`Delete`[^.]*never[^.]*default/i, section)
  end

  def test_tables_never_exceed_the_content_area_and_stack_with_data_labels
    width = section(reference, "### Width")
    assert_match(/content area/i, width)
    assert_match(/sidebar/i, width)
    assert_match(/never scrolls sideways/i, width)
    assert_match(/max-inline-size: 100%/, width)
    assert_match(/overflow-wrap: anywhere/, width)
    assert_match(/not the fix[^.]*overflow-x|overflow-x[^.]*not the fix/i, width)

    responsive = section(reference, "### Responsive tables")
    assert_match(/data-label/, responsive)
    assert_match(/attr\(data-label\)/, responsive)
    assert_match(/t\(/, responsive)
    assert_match(/@container/, responsive)
    %w[table thead tbody tr th td].each { |element| assert_match(/`#{element}`/, responsive) }
    assert_match(/layout CSS[^.]*container-type|container-type[^.]*layout CSS/i, responsive)
    assert_match(/table CSS never declares/i, responsive)
    assert_match(/breakpoint[^.]*(measure|narrow)|(measure|narrow)[^.]*breakpoint/i, responsive)
    assert_includes(responsive, "https://css-tricks.com/responsive-data-tables/")
    assert_includes(responsive, "https://css-tricks.com/making-tables-responsive-with-minimal-css/")
  end

  def test_stacked_tables_keep_headers_for_screen_readers_and_add_table_roles
    section = section(reference, "### Screen readers")
    assert_match(/scope="col"/, section)
    assert_match(/<caption>|aria-labelledby/, section)
    assert_match(/visually hidden|visually-hidden/i, section)
    assert_match(/below the breakpoint[^.]*hide the header row/i, section)
    assert_match(/above the breakpoint[^.]*header row stays visible/i, section)
    assert_includes(section, 'content: attr(data-label) / ""')
    assert_match(/never[^.]*display: none/i, section)
    %w[table row columnheader cell].each { |role| assert_includes(section, %(role="#{role}")) }
    assert_match(/VoiceOver|accessibility tree/i, section)
    assert_includes(section, "https://www.w3.org/WAI/ARIA/apg/patterns/table/")
  end

  def test_existing_rules_survive
    actions = section(reference, "## Action rows")
    assert_match(/`Esc`[^.]*`Cancel`/, actions)
    assert_match(/verbs?/i, actions)
    assert_match(/`OK`, `Yes`,? and `No`/, actions)
    assert_match(/<a>/, actions)
    assert_match(/<button type="button">/, actions)

    colors = section(reference, "## Color semantics")
    assert_match(/red/i, colors)
    assert_match(/orange/i, colors)
    assert_match(/primary/i, colors)

    assert_includes(reference, "https://www.tempel.org/DialogButtonPlacement")
    [ "## Forgiveness and reversibility", "## Progressive disclosure",
      "## Minimize modes", "## Immediate feedback" ].each { |heading| section(reference, heading) }
  end

  def test_codex_metadata_names_the_skill
    interface = YAML.load_file(File.join(SKILL_DIR, "agents/openai.yaml")).fetch("interface")
    assert_equal("Rails UI", interface.fetch("display_name"))
    assert_kind_of(String, interface.fetch("short_description"))
    refute_empty(interface.fetch("short_description").strip)
  end

  def test_skill_pointer_names_the_action_row_delete_and_table_rules
    body = File.read(File.join(SKILL_DIR, "SKILL.md")).split(/^## UI interaction and dialog rules\n/, 2).fetch(1)
    paragraph = body.split(/\n\n/).map(&:strip).reject(&:empty?).first
    refute_includes(paragraph, "\n", "the pointer paragraph is hard-wrapped")
    assert_includes(paragraph, "references/interaction-design.md")
    assert_match(/Delete/, paragraph)
    assert_match(/tables?/i, paragraph)
  end

  private

  def reference
    @reference ||= File.read(File.join(SKILL_DIR, "references/interaction-design.md"))
  end

  # The lines after a heading, up to the next heading of the same or a higher level.
  def section(text, heading)
    level = heading[/\A#+/].length
    lines = text.lines.map(&:chomp)
    start = lines.index(heading)
    flunk("missing heading: #{heading}") unless start

    stop = lines[(start + 1)..].index { |line| line.match?(/\A\#{1,#{level}} /) }
    body = stop ? lines[(start + 1)...(start + 1 + stop)] : lines[(start + 1)..]
    body.join("\n")
  end
end
