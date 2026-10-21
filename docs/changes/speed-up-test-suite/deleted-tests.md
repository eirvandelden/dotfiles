# Deleted and merged tests: speed up the dotfiles test suite

Every former test in the six hook test files, 94 in all, with the test that holds its assertions today.

## Deleted tests

Each row names the covering tests. Every `master` clause of the guard keeps a test; the covering column shows which.

| File | Deleted test | Covering test |
| --- | --- | --- |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_allows_a_merge_commit_on_master` | `test_a_lefthook_local_extending_the_guard_lets_merges_through_on_main_and_refuses_a_squash` |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_allows_concluding_a_conflicted_merge_on_master` | `test_a_lefthook_local_extending_the_guard_lets_merges_through_on_main_and_refuses_a_squash` + `test_a_lefthook_local_extending_the_guard_on_master_refuses_commits_and_pushes` |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_allows_concluding_a_conflicted_merge_on_master_in_a_linked_worktree` | `test_a_lefthook_local_extending_the_guard_lets_merges_through_on_main_in_a_linked_worktree` + `test_a_lefthook_local_extending_the_guard_on_master_refuses_commits_and_pushes` |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_refuses_an_amend_that_stages_a_change_on_master` | `test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work` + `test_a_lefthook_local_extending_the_guard_on_master_refuses_commits_and_pushes` |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_refuses_an_amend_that_stages_no_change_on_master` | `test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work` + `test_a_lefthook_local_extending_the_guard_on_master_refuses_commits_and_pushes` |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_refuses_a_squash_merge_commit_on_master` | `test_a_lefthook_local_extending_the_guard_lets_merges_through_on_main_and_refuses_a_squash` + `test_a_lefthook_local_extending_the_guard_on_master_refuses_commits_and_pushes` |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_refuses_a_push_deleting_master` | `test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work` |
| `test/branch_guard_test.rb` | `test_the_fallback_config_refuses_an_empty_commit_on_master` | `test_the_fallback_config_on_main_refuses_commits_and_pushes_and_allows_other_pushes` + `test_a_lefthook_local_extending_the_guard_on_master_refuses_commits_and_pushes` + `test_the_fallback_config_duplicates_the_guard_commands_exactly` |
| `test/branch_guard_test.rb` | `test_the_fallback_config_refuses_a_push_of_a_feature_branch_to_master` | `test_the_fallback_config_on_main_refuses_commits_and_pushes_and_allows_other_pushes` + `test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work` + `test_the_fallback_config_duplicates_the_guard_commands_exactly` |
| `test/branch_guard_test.rb` | `test_the_fallback_config_refuses_a_push_deleting_master` | `test_the_fallback_config_on_main_refuses_commits_and_pushes_and_allows_other_pushes` + `test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work` + `test_the_fallback_config_duplicates_the_guard_commands_exactly` |
| `test/lefthook_pull_hooks_test.rb` | `test_pull_on_non_main_branch_still_fires_hooks` | `test_pulling_migrations_runs_db_migrate_and_a_hostile_migration_name_runs_nothing` |

`test_the_fallback_config_duplicates_the_guard_commands_exactly` stays unchanged in `test/branch_guard_test.rb`. It guards that the fallback config and the guard file hold the same commands, so a deleted `f:`/`master` test relies on it.

`test_pull_on_non_main_branch_still_fires_hooks` had a body identical to `test_new_migration_file_triggers_db_migrate`, and it pulled on the same branch. The migrations test covers it.

## Coverage matrix

`merged` means the former test is now a step in the covering test. `unchanged` means the test was not touched. `deleted` is listed above.

| File | Former test | Now held by | Kind |
| --- | --- | --- | --- |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_refuses_a_commit_on_main` | `test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work` | merged |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_refuses_a_commit_on_master` | `test_a_lefthook_local_extending_the_guard_on_master_refuses_commits_and_pushes` | merged |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_refuses_a_push_on_main` | `test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work` | merged |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_refuses_a_push_on_master` | `test_a_lefthook_local_extending_the_guard_on_master_refuses_commits_and_pushes` | merged |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_allows_a_feature_branch_commit_and_push` | `test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work` | merged |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_keeps_the_extending_repos_own_pre_push_commands` | `test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work` | merged |
| `test/branch_guard_test.rb` | `test_a_change_to_the_guard_file_reaches_a_repo_that_extends_it` | `test_a_change_to_the_guard_file_reaches_a_repo_that_extends_it` | unchanged |
| `test/branch_guard_test.rb` | `test_no_verify_lets_an_empty_commit_through_on_main_with_the_extending_guard` | `test_no_verify_lets_an_empty_commit_and_a_no_change_amend_through_on_main_with_the_extending_guard` | merged |
| `test/branch_guard_test.rb` | `test_no_verify_lets_an_amend_that_stages_no_change_through_on_main_with_the_extending_guard` | `test_no_verify_lets_an_empty_commit_and_a_no_change_amend_through_on_main_with_the_extending_guard` | merged |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_allows_pushing_a_branch_named_main_fix` | `test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work` | merged |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_allows_pushing_a_branch_named_mainline` | `test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work` | merged |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_allows_pushing_a_tag` | `test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work` | merged |
| `test/branch_guard_test.rb` | `test_the_fallback_config_allows_pushing_a_branch_named_main_fix` | `test_the_fallback_config_on_main_refuses_commits_and_pushes_and_allows_other_pushes` | merged |
| `test/branch_guard_test.rb` | `test_the_fallback_config_allows_pushing_a_branch_named_mainline` | `test_the_fallback_config_on_main_refuses_commits_and_pushes_and_allows_other_pushes` | merged |
| `test/branch_guard_test.rb` | `test_the_fallback_config_allows_pushing_a_tag` | `test_the_fallback_config_on_main_refuses_commits_and_pushes_and_allows_other_pushes` | merged |
| `test/branch_guard_test.rb` | `test_the_guard_file_defines_only_the_guard_commands` | `test_the_guard_file_defines_only_the_guard_commands` | unchanged |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_refuses_an_empty_commit_on_main` | `test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work` | merged |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_refuses_an_empty_commit_on_master` | `test_a_lefthook_local_extending_the_guard_on_master_refuses_commits_and_pushes` | merged |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_allows_an_empty_commit_on_a_feature_branch` | `test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work` | merged |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_lets_the_first_empty_commit_on_an_unborn_main_through` | `test_a_lefthook_local_extending_the_guard_lets_the_first_empty_commit_on_an_unborn_main_through` | unchanged |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_allows_a_merge_commit_on_main` | `test_a_lefthook_local_extending_the_guard_lets_merges_through_on_main_and_refuses_a_squash` | merged |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_allows_a_merge_commit_on_master` | `test_a_lefthook_local_extending_the_guard_lets_merges_through_on_main_and_refuses_a_squash` | deleted |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_allows_a_merge_commit_on_main_that_changes_no_files` | `test_a_lefthook_local_extending_the_guard_lets_merges_through_on_main_and_refuses_a_squash` | merged |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_allows_a_merge_commit_on_main_in_a_linked_worktree` | `test_a_lefthook_local_extending_the_guard_lets_merges_through_on_main_in_a_linked_worktree` | merged |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_allows_a_merge_commit_on_main_in_a_linked_worktree_that_changes_no_files` | `test_a_lefthook_local_extending_the_guard_lets_merges_through_on_main_in_a_linked_worktree` | merged |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_allows_concluding_a_conflicted_merge_on_main` | `test_a_lefthook_local_extending_the_guard_lets_merges_through_on_main_and_refuses_a_squash` | merged |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_allows_concluding_a_conflicted_merge_on_master` | `test_a_lefthook_local_extending_the_guard_lets_merges_through_on_main_and_refuses_a_squash` + `test_a_lefthook_local_extending_the_guard_on_master_refuses_commits_and_pushes` | deleted |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_allows_concluding_a_conflicted_merge_on_main_in_a_linked_worktree` | `test_a_lefthook_local_extending_the_guard_lets_merges_through_on_main_in_a_linked_worktree` | merged |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_allows_concluding_a_conflicted_merge_on_master_in_a_linked_worktree` | `test_a_lefthook_local_extending_the_guard_lets_merges_through_on_main_in_a_linked_worktree` + `test_a_lefthook_local_extending_the_guard_on_master_refuses_commits_and_pushes` | deleted |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_refuses_an_amend_that_stages_a_change_on_main` | `test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work` | merged |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_refuses_an_amend_that_stages_a_change_on_master` | `test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work` + `test_a_lefthook_local_extending_the_guard_on_master_refuses_commits_and_pushes` | deleted |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_refuses_an_amend_that_stages_no_change_on_main` | `test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work` | merged |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_refuses_an_amend_that_stages_no_change_on_master` | `test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work` + `test_a_lefthook_local_extending_the_guard_on_master_refuses_commits_and_pushes` | deleted |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_refuses_a_squash_merge_commit_on_main` | `test_a_lefthook_local_extending_the_guard_lets_merges_through_on_main_and_refuses_a_squash` | merged |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_refuses_a_squash_merge_commit_on_master` | `test_a_lefthook_local_extending_the_guard_lets_merges_through_on_main_and_refuses_a_squash` + `test_a_lefthook_local_extending_the_guard_on_master_refuses_commits_and_pushes` | deleted |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_refuses_a_push_of_a_feature_branch_to_main` | `test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work` | merged |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_refuses_a_push_of_a_feature_branch_to_master` | `test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work` | merged |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_refuses_a_push_of_head_to_main` | `test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work` | merged |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_refuses_a_push_deleting_main` | `test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work` | merged |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_refuses_a_push_deleting_master` | `test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work` | deleted |
| `test/branch_guard_test.rb` | `test_a_lefthook_local_extending_the_guard_refuses_a_push_that_updates_main_among_other_refs` | `test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work` | merged |
| `test/branch_guard_test.rb` | `test_the_fallback_config_duplicates_the_guard_commands_exactly` | `test_the_fallback_config_duplicates_the_guard_commands_exactly` | unchanged |
| `test/branch_guard_test.rb` | `test_the_fallback_config_refuses_an_empty_commit_on_main` | `test_the_fallback_config_on_main_refuses_commits_and_pushes_and_allows_other_pushes` | merged |
| `test/branch_guard_test.rb` | `test_the_fallback_config_refuses_an_empty_commit_on_master` | `test_the_fallback_config_on_main_refuses_commits_and_pushes_and_allows_other_pushes` + `test_a_lefthook_local_extending_the_guard_on_master_refuses_commits_and_pushes` + `test_the_fallback_config_duplicates_the_guard_commands_exactly` | deleted |
| `test/branch_guard_test.rb` | `test_the_fallback_config_allows_a_merge_commit_on_main` | `test_the_fallback_config_lets_merges_through_on_main` | merged |
| `test/branch_guard_test.rb` | `test_the_fallback_config_allows_concluding_a_conflicted_merge_on_main` | `test_the_fallback_config_lets_merges_through_on_main` | merged |
| `test/branch_guard_test.rb` | `test_the_fallback_config_refuses_an_amend_that_stages_a_change_on_main` | `test_the_fallback_config_on_main_refuses_commits_and_pushes_and_allows_other_pushes` | merged |
| `test/branch_guard_test.rb` | `test_the_fallback_config_refuses_a_push_of_a_feature_branch_to_main` | `test_the_fallback_config_on_main_refuses_commits_and_pushes_and_allows_other_pushes` | merged |
| `test/branch_guard_test.rb` | `test_the_fallback_config_refuses_a_push_of_a_feature_branch_to_master` | `test_the_fallback_config_on_main_refuses_commits_and_pushes_and_allows_other_pushes` + `test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work` + `test_the_fallback_config_duplicates_the_guard_commands_exactly` | deleted |
| `test/branch_guard_test.rb` | `test_the_fallback_config_refuses_a_push_deleting_main` | `test_the_fallback_config_on_main_refuses_commits_and_pushes_and_allows_other_pushes` | merged |
| `test/branch_guard_test.rb` | `test_the_fallback_config_refuses_a_push_deleting_master` | `test_the_fallback_config_on_main_refuses_commits_and_pushes_and_allows_other_pushes` + `test_a_lefthook_local_extending_the_guard_on_main_refuses_commits_and_pushes_and_allows_feature_work` + `test_the_fallback_config_duplicates_the_guard_commands_exactly` | deleted |
| `test/branch_guard_test.rb` | `test_the_fallback_config_refuses_a_push_that_updates_main_among_other_refs` | `test_the_fallback_config_on_main_refuses_commits_and_pushes_and_allows_other_pushes` | merged |
| `test/lefthook_pull_hooks_test.rb` | `test_new_migration_file_triggers_db_migrate` | `test_pulling_migrations_runs_db_migrate_and_a_hostile_migration_name_runs_nothing` | merged |
| `test/lefthook_pull_hooks_test.rb` | `test_changed_schema_triggers_db_migrate` | `test_pulling_migrations_runs_db_migrate_and_a_hostile_migration_name_runs_nothing` | merged |
| `test/lefthook_pull_hooks_test.rb` | `test_changed_gemfile_lock_installs_through_bi` | `test_pulling_gemfiles_installs_through_bi_and_ignores_deleted_nested_and_hostile_gemfiles` | merged |
| `test/lefthook_pull_hooks_test.rb` | `test_changed_yarn_lock_triggers_yarn_install` | `test_pulling_in_a_yarn_repository_installs_with_yarn_only_beside_a_yarn_lock` | merged |
| `test/lefthook_pull_hooks_test.rb` | `test_changed_package_lock_json_triggers_npm_install` | `test_pulling_in_an_npm_repository_installs_with_npm_only` | merged |
| `test/lefthook_pull_hooks_test.rb` | `test_changed_package_json_beside_package_lock_triggers_npm_install` | `test_pulling_in_an_npm_repository_installs_with_npm_only` | merged |
| `test/lefthook_pull_hooks_test.rb` | `test_changed_package_json_beside_yarn_lock_triggers_yarn_install` | `test_pulling_in_a_yarn_repository_installs_with_yarn_only_beside_a_yarn_lock` | merged |
| `test/lefthook_pull_hooks_test.rb` | `test_changed_package_json_without_lockfile_installs_nothing` | `test_pulling_in_a_yarn_repository_installs_with_yarn_only_beside_a_yarn_lock` | merged |
| `test/lefthook_pull_hooks_test.rb` | `test_pull_on_non_main_branch_still_fires_hooks` | `test_pulling_migrations_runs_db_migrate_and_a_hostile_migration_name_runs_nothing` | deleted |
| `test/lefthook_pull_hooks_test.rb` | `test_pull_with_local_commit_uses_rebase_path_and_migrates` | `test_pull_with_local_commit_uses_rebase_path_and_migrates` | unchanged |
| `test/lefthook_pull_hooks_test.rb` | `test_repo_with_own_lefthook_config_ignores_global_defaults` | `test_repo_with_own_lefthook_config_ignores_global_defaults` | unchanged |
| `test/lefthook_pull_hooks_test.rb` | `test_pull_touching_only_readme_runs_no_migrations` | `test_pull_touching_only_readme_runs_no_migrations` | unchanged |
| `test/lefthook_pull_hooks_test.rb` | `test_pull_touching_only_nested_gemfile_does_not_bundle` | `test_pulling_gemfiles_installs_through_bi_and_ignores_deleted_nested_and_hostile_gemfiles` | merged |
| `test/lefthook_pull_hooks_test.rb` | `test_pulled_gemfile_name_with_a_command_on_a_new_line_does_not_run_it` | `test_pulling_gemfiles_installs_through_bi_and_ignores_deleted_nested_and_hostile_gemfiles` | merged |
| `test/lefthook_pull_hooks_test.rb` | `test_pulled_migration_name_with_a_command_on_a_new_line_does_not_run_it` | `test_pulling_migrations_runs_db_migrate_and_a_hostile_migration_name_runs_nothing` | merged |
| `test/lefthook_pull_hooks_test.rb` | `test_pull_deleting_root_gemfile_does_not_bundle_install` | `test_pulling_gemfiles_installs_through_bi_and_ignores_deleted_nested_and_hostile_gemfiles` | merged |
| `test/lefthook_local_hooks_test.rb` | `test_pre_commit_uses_global_fallback_and_rejects_conflict_markers` | `test_pre_commit_uses_global_fallback_and_rejects_conflict_markers` | unchanged |
| `test/lefthook_local_hooks_test.rb` | `test_pre_commit_calls_lefthook_with_no_auto_install` | `test_hooks_call_lefthook_with_no_auto_install` | merged |
| `test/lefthook_local_hooks_test.rb` | `test_pre_push_uses_global_fallback_and_rejects_a_pushed_fixme` | `test_pre_push_uses_global_fallback_and_rejects_a_pushed_fixme` | unchanged |
| `test/lefthook_local_hooks_test.rb` | `test_pre_push_calls_lefthook_with_no_auto_install` | `test_hooks_call_lefthook_with_no_auto_install` | merged |
| `test/lefthook_local_hooks_test.rb` | `test_pre_commit_reaches_the_logging_stub_when_lefthook_bin_is_set` | `test_pre_commit_reaches_the_logging_stub_when_lefthook_bin_is_set` | unchanged |
| `test/lefthook_local_hooks_test.rb` | `test_pre_push_reaches_the_logging_stub_when_lefthook_bin_is_set` | `test_pre_push_reaches_the_logging_stub_when_lefthook_bin_is_set` | unchanged |
| `test/lefthook_local_hooks_test.rb` | `test_pre_commit_uses_global_fallback_and_commits_an_unknown_word` | `test_pre_commit_uses_global_fallback_and_commits_an_unknown_word` | unchanged |
| `test/lefthook_local_hooks_test.rb` | `test_pre_commit_still_commits_a_binary_only_change` | `test_pre_commit_still_commits_a_binary_only_change` | unchanged |
| `test/lefthook_local_hooks_test.rb` | `test_pre_commit_warns_about_a_wrapped_paragraph_and_still_commits` | `test_pre_commit_warns_about_wrapped_paragraphs_in_markdown_files_and_still_commits` | merged |
| `test/lefthook_local_hooks_test.rb` | `test_pre_commit_warns_about_a_wrapped_paragraph_in_a_markdown_extension_file` | `test_pre_commit_warns_about_wrapped_paragraphs_in_markdown_files_and_still_commits` | merged |
| `test/lefthook_local_hooks_test.rb` | `test_pre_commit_prints_no_hardwrap_warning_for_one_line_paragraphs` | `test_pre_commit_warns_about_wrapped_paragraphs_in_markdown_files_and_still_commits` | merged |
| `test/lefthook_local_hooks_test.rb` | `test_pre_commit_skips_the_hardwrap_check_without_markdownlint` | `test_pre_commit_skips_the_hardwrap_check_without_markdownlint` | unchanged |
| `test/lefthook_local_hooks_test.rb` | `test_pre_commit_skips_the_hardwrap_check_when_the_markdownlint_package_is_not_stowed` | `test_pre_commit_skips_the_hardwrap_check_when_the_markdownlint_package_is_not_stowed` | unchanged |
| `test/lefthook_local_hooks_test.rb` | `test_pre_commit_stylelint_runs_through_npx_no` | `test_pre_commit_runs_stylelint_and_eslint_through_npx_no` | merged |
| `test/lefthook_local_hooks_test.rb` | `test_pre_commit_eslint_runs_through_npx_no` | `test_pre_commit_runs_stylelint_and_eslint_through_npx_no` | merged |
| `test/lefthook_posix_sh_test.rb` | `test_pre_push_rejects_a_push_from_main_when_sh_is_dash` | `test_the_guard_rejects_commits_and_pushes_to_main_when_sh_is_dash` | merged |
| `test/lefthook_posix_sh_test.rb` | `test_pre_push_rejects_a_push_of_a_feature_branch_to_main_when_sh_is_dash` | `test_the_guard_rejects_commits_and_pushes_to_main_when_sh_is_dash` | merged |
| `test/lefthook_posix_sh_test.rb` | `test_commit_msg_rejects_an_empty_commit_on_main_when_sh_is_dash` | `test_the_guard_rejects_commits_and_pushes_to_main_when_sh_is_dash` | merged |
| `test/lefthook_rubocop_git_gem_test.rb` | `test_committing_a_clean_ruby_file_passes_after_rubocop_inspects_it` | `test_committing_passes_clean_and_fixable_files_and_blocks_an_unfixable_offense` | merged |
| `test/lefthook_rubocop_git_gem_test.rb` | `test_committing_a_fixable_offense_commits_the_fixed_file_with_nothing_unstaged` | `test_committing_passes_clean_and_fixable_files_and_blocks_an_unfixable_offense` | merged |
| `test/lefthook_rubocop_git_gem_test.rb` | `test_pushing_a_clean_ruby_file_passes_after_rubocop_inspects_it` | `test_pushing_passes_a_clean_file_and_blocks_an_unfixable_offense` | merged |
| `test/lefthook_rubocop_git_gem_test.rb` | `test_an_unfixable_offense_blocks_the_commit` | `test_committing_passes_clean_and_fixable_files_and_blocks_an_unfixable_offense` | merged |
| `test/lefthook_rubocop_git_gem_test.rb` | `test_an_unfixable_offense_blocks_the_push` | `test_pushing_passes_a_clean_file_and_blocks_an_unfixable_offense` | merged |
| `test/lefthook_rubocop_git_gem_test.rb` | `test_the_fixture_reproduces_the_bug_when_git_dir_leaks` | `test_the_fixture_reproduces_the_bug_when_git_dir_leaks` | unchanged |
| `test/review_push_hook_test.rb` | `test_a_push_with_a_change_folder_and_no_pull_request_succeeds_without_a_fresh_review` | `test_a_push_with_a_change_folder_needs_a_fresh_review_only_while_a_pull_request_is_open` | merged |
| `test/review_push_hook_test.rb` | `test_a_push_with_a_change_folder_and_an_open_pull_request_needs_a_fresh_review` | `test_a_push_with_a_change_folder_needs_a_fresh_review_only_while_a_pull_request_is_open` | merged |

## Mutation check

A mutation changes the hook configuration or a stub on a scratch copy of the repository, never on a tracked file. The scratch copy runs the former test files (commit e5cc5e70) and the new ones. The rule: if a mutation fails a former test, a covering test must fail in the new files. Chained tests stop at their first failing step, so a later step is only proved to fail when its chain fails.

Result: no mutation failed a former test without failing a covering test.

A row marked `old kills 0, new kills 0` is not evidence for any merged step, and review round 1 asked for better ones. This is what each such row turned out to be:

- `p6-bi-unfiltered` and `p8-deps-unfiltered` change only the no-op `: {files}` prefix, which lefthook's glob already covers. They are equivalent mutations: no test can fail them.
- `p9-bundle-glob-lock-only`: no former test changes a `Gemfile` without a `Gemfile.lock`. No former test saw it, so no coverage was lost.
- `p1-swap-npm-yarn` swaps the check order, and no test has both lockfiles. The stronger mutations `p1a-npm-ci` and `p1b-yarn-add` break each branch. They fail the former npm and yarn tests and the new `test_pulling_in_an_npm_repository_installs_with_npm_only` and `test_pulling_in_a_yarn_repository_installs_with_yarn_only_beside_a_yarn_lock`.
- `l1-merge-conflict-regex` changed one of three alternatives, and the `=======` line still matched. The stronger `l1b-conflict-regex-dead` kills the former conflict-marker test.
- `l10-binary-grep` and the unknown-word step: no mutation of the hook configuration fails the binary-only or unknown-word commit, because no hook reads binary content. By the plan's rule these two former tests stay separate, and so does the conflict-marker test they were chained with.
- `l6-fixme-push` and the stronger `l6b-fixme-push-pattern` fail no test in either version. The unchanged `test_pre_push_uses_global_fallback_and_rejects_a_pushed_fixme` passes for another reason than the fixme check. This was true before the change and is not fixed here.

| Mutation | Former kills | New kills |
| --- | --- | --- |
| `p1a-npm-ci` | 2 | 1 |
| `p1b-yarn-add` | 2 | 1 |
| `l1b-conflict-regex-dead` | 1 | 1 |
| `l6b-fixme-push-pattern` | 0 | 0 |

The `g:` prefix mutates `lefthook-branch-guard.yml` (the extending repository). The `f:` prefix mutates `lefthook.yml` (the fallback config). Without a prefix, the mutation targets `lefthook.yml` or a hook script, or the own-check stub in the test file for `t1-own-check`.

```text
g:b1-precommit-master                    old kills  4, new kills  2  OK
f:b1-precommit-master                    old kills  1, new kills  1  OK
g:b2-commitmsg-master                    old kills  3, new kills  2  OK
f:b2-commitmsg-master                    old kills  2, new kills  1  OK
g:b3-prepush-branch-master               old kills  1, new kills  1  OK
f:b3-prepush-branch-master               old kills  1, new kills  1  OK
g:b4-drop-master-arm                     old kills  3, new kills  2  OK
f:b4-drop-master-arm                     old kills  3, new kills  1  OK
g:b5-widen-main-arm                      old kills  3, new kills  2  OK
f:b5-widen-main-arm                      old kills  3, new kills  2  OK
g:b6-precommit-merge-head                old kills  5, new kills  3  OK
f:b6-precommit-merge-head                old kills  2, new kills  2  OK
g:b7-commitmsg-merge-head                old kills  3, new kills  3  OK
f:b7-commitmsg-merge-head                old kills  1, new kills  1  OK
g:b8-drop-unborn-check                   old kills  1, new kills  1  OK
f:b8-drop-unborn-check                   old kills  1, new kills  1  OK
g:b9-drop-empty-diff-check               old kills  1, new kills  1  OK
f:b9-drop-empty-diff-check               old kills  1, new kills  1  OK
g:b10-commitmsg-never-refuses            old kills  5, new kills  3  OK
f:b10-commitmsg-never-refuses            old kills  4, new kills  3  OK
g:b11-precommit-never-refuses            old kills  8, new kills  5  OK
f:b11-precommit-never-refuses            old kills  2, new kills  2  OK
g:b12-prepush-no-stdin                   old kills  7, new kills  2  OK
f:b12-prepush-no-stdin                   old kills  7, new kills  3  OK
g:b13-prepush-branch-never-refuses       old kills  3, new kills  3  OK
f:b13-prepush-branch-never-refuses       old kills  1, new kills  1  OK
g:b14-prepush-arm-never-refuses          old kills  6, new kills  2  OK
f:b14-prepush-arm-never-refuses          old kills  5, new kills  2  OK
t1-own-check                             old kills  1, new kills  1  OK
p1-swap-npm-yarn                         old kills  0, new kills  0  OK
p2-drop-package-json-glob                old kills  2, new kills  2  OK
p3-drop-schema-glob                      old kills  1, new kills  1  OK
p4-drop-migrate-glob                     old kills  3, new kills  2  OK
p5-bundle-install                        old kills  2, new kills  1  OK
p6-bi-unfiltered                         old kills  0, new kills  0  OK
p7-migrate-unfiltered                    old kills  1, new kills  1  OK
p8-deps-unfiltered                       old kills  0, new kills  0  OK
p9-bundle-glob-lock-only                 old kills  0, new kills  0  OK
p10-no-nul-split                         old kills  5, new kills  3  OK
l1-merge-conflict-regex                  old kills  0, new kills  0  OK
l2-hardwrap-missing-message              old kills  1, new kills  1  OK
l3-hardwrap-unstowed-message             old kills  1, new kills  1  OK
l4-stylelint-no-npx-no                   old kills  1, new kills  1  OK
l5-eslint-no-npx-no                      old kills  1, new kills  1  OK
l6-fixme-push                            old kills  0, new kills  0  OK
l7-shim-no-auto-install                  old kills  4, new kills  3  OK
l8-markdown-glob                         old kills  1, new kills  1  OK
l9-hardwrap-blocks                       old kills  2, new kills  1  OK
l10-binary-grep                          old kills  0, new kills  0  OK
r1-precommit-keeps-git-dir               old kills  3, new kills  1  OK
r2-prepush-keeps-git-dir                 old kills  2, new kills  1  OK
r3-no-stage-fixed                        old kills  1, new kills  1  OK
r4-no-autocorrect                        old kills  1, new kills  1  OK
r5-prepush-rubocop-noop                  old kills  2, new kills  1  OK
v1-review-without-skip                   old kills  1, new kills  1  OK

NO PROBLEMS
```
