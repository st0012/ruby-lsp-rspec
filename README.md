# Ruby LSP RSpec

[![Gem Version](https://badge.fury.io/rb/ruby-lsp-rspec.svg)](https://badge.fury.io/rb/ruby-lsp-rspec)

Ruby LSP RSpec is a [Ruby LSP](https://github.com/Shopify/ruby-lsp) addon for displaying CodeLens for RSpec tests.

## Installation

To install, add the following line to your application's Gemfile:

```ruby
# Gemfile
group :development do
  gem "ruby-lsp-rspec", require: false
end
```

After running `bundle install`, restart Ruby LSP and you should start seeing CodeLens in your RSpec test files.

## Features

### CodeLens

1. When clicking `Run`, the test(s) will be executed via the Test Explorer
    - However, deeply nested tests may not be displayed correctly at the moment
2. When clicking `Run In Terminal`, a test command will be generated in the terminal
3. When clicking `Debug`, the test(s) will be executed with VS Code debugger enabled (requires the [`debug`](https://github.com/ruby/debug) gem)
    - [Learn how to set breakpoints in VS Code](https://code.visualstudio.com/docs/editor/debugging#_breakpoints)

<img src="misc/code-lens.gif" alt="CodeLens" width="75%">

### Document Symbols

Document Symbols can be triggered by:

- Typing `@` in VS Code's command palette
- Pressing `Cmd+Shift+O`

<img src="misc/document-symbol.gif" alt="Document Symbols" width="75%">

### Go to definition

`ruby-lsp-rspec` supports go-to-definition on methods defined through `let` and `subject` DSLs in spec files.

In VS Code this feature can be triggered by one of the following methods:

- `Right click` on the target, and then select `Go to Definition`
- Placing the cursor on the target, and then hit `F12`
- `Command + click` the target

> [!Note]
> This feature requires indexing your spec files so they can't be excluded from Ruby LSP's indexing.

<img src="misc/go-to-definition.gif" alt="Go to definition" width="75%">

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/st0012/ruby-lsp-rspec. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/st0012/ruby-lsp-rspec/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Ruby::Lsp::Rspec project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/st0012/ruby-lsp-rspec/blob/main/CODE_OF_CONDUCT.md).
