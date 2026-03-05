# ruby-lsp-rspec

An RSpec addon for ruby-lsp providing code lens, document symbols, go-to-definition, and test discovery.

## Development

- **Type checking**: Sorbet with `typed: strict` for lib files, using RBS inline comments (`#:` syntax)
- **Linting**: RuboCop with rubocop-shopify style guide
- **Testing**: `bundle exec rspec`
- **Typecheck**: `bundle exec srb tc`

## Dependency Updates

After `bundle update`, always:
1. `bundle exec tapioca gems` — regenerate RBI files
2. `bundle exec srb tc` — typecheck
3. `bundle exec rspec` — run tests

## Releasing

1. Bump version in `lib/ruby_lsp_rspec/version.rb`
2. Run `bundle install` to update Gemfile.lock
3. Commit and push: `git commit -am "Bump version to vX.Y.Z" && git push`
4. Tag and push: `git tag vX.Y.Z && git push --tags`
5. The `push_gem.yml` workflow automatically publishes to rubygems.org and creates a GitHub release

## Architecture

- `lib/ruby_lsp/ruby_lsp_rspec/addon.rb` — LSP addon entry point
- `lib/ruby_lsp/ruby_lsp_rspec/code_lens.rb` — Run/debug test buttons in editor
- `lib/ruby_lsp/ruby_lsp_rspec/test_discovery.rb` — Full test discovery for Test Explorer
- `lib/ruby_lsp/ruby_lsp_rspec/rspec_formatter.rb` — Custom RSpec formatter for LSP event reporting
- `lib/ruby_lsp/ruby_lsp_rspec/definition.rb` — Go-to-definition for `let`/`subject`
- `lib/ruby_lsp/ruby_lsp_rspec/document_symbol.rb` — Document symbols for test outline

## Testing Patterns

- Integration tests for the formatter run rspec in a subprocess via `Open3` against fixture files in `spec/fixtures/`
- Fixture specs configure the formatter directly via `RSpec.configure` (the `-r` flag doesn't work in subprocess)
- Other tests use the ruby-lsp test helpers to set up the addon and assert on LSP responses
