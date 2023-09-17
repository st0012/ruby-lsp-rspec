# Ruby LSP RSpec

Ruby LSP RSpec is a [Ruby LSP](https://github.com/Shopify/ruby-lsp) extension for displaying code-lenses for RSpec tests.

![Screenshot of the code lenses](/misc/example.png)

## Installation

To install, add the following line to your application's Gemfile:

```ruby
# Gemfile
group :development do
  gem "ruby-lsp-rspec"
end
```

After running `bundle install`, restart Ruby LSP and you should start seeing code-lenses in your RSpec test files.

## Usages (with VS Code)

1. When clicking `Run`, the test(s) will be executed via the Test Explorer.
    - However, deeply nested tests may not be displayed correctly at the moment.
2. When clicking `Run In Terminal`, a test command will be generated in the terminal.
3. When clicking `Debug`, the test(s) will be executed with VS Code debugger enabled (requires the [`debug`](https://github.com/ruby/debug) gem).
    - [Learn how to set breakpoints in VS Code](https://code.visualstudio.com/docs/editor/debugging#_breakpoints).


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/st0012/ruby-lsp-rspec. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/st0012/ruby-lsp-rspec/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Ruby::Lsp::Rspec project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/st0012/ruby-lsp-rspec/blob/main/CODE_OF_CONDUCT.md).
