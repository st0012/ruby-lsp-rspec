# frozen_string_literal: true

require_relative "../../lib/ruby_lsp/ruby_lsp_rspec/rspec_formatter"

RSpec.configure do |config|
  config.formatter = "RubyLsp::RSpec::RSpecFormatter"
end

RSpec.describe "ChainedExceptionExample" do
  it "fails with a chained error" do
    raise "secondary error"
  rescue
    raise "primary error"
  end
end
