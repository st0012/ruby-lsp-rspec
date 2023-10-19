# frozen_string_literal: true

require_relative "lib/ruby_lsp_rspec/version"

Gem::Specification.new do |spec|
  spec.name = "ruby-lsp-rspec"
  spec.version = RubyLsp::RSpec::VERSION
  spec.authors = ["Stan Lo"]
  spec.email = ["stan001212@gmail.com"]

  spec.summary = "RSpec addon for ruby-lsp"
  spec.description = "RSpec addon for ruby-lsp"
  spec.homepage = "https://github.com/st0012/ruby-lsp-rspec"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/st0012/ruby-lsp-rspec"
  spec.metadata["changelog_uri"] = "https://github.com/st0012/ruby-lsp-rspec/releases"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    %x(git ls-files -z).split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(
          "bin/",
          "test/",
          "spec/",
          "features/",
          ".git",
          ".circleci",
          "appveyor",
          "Gemfile",
          "misc/",
          "sorbet/",
        )
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "ruby-lsp", "~> 0.12.0"
end
