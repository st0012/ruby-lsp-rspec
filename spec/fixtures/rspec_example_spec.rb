# frozen_string_literal: true

# TODO: Ideally, these should be done in rspec_formatter_spec.rb's popen3 call
# but for some reason the `-r` option doesn't correctly load the formatter
require_relative "../../lib/ruby_lsp/ruby_lsp_rspec/rspec_formatter"

RSpec.configure do |config|
  config.formatter = "RubyLsp::RSpec::RSpecFormatter"
end

RSpec.describe "RSpecExample" do
  describe "A sample test group" do
    it "passes" do
      expect(1).to eq(1)
    end

    it "fails" do
      expect(2).to eq(1)
    end

    it "is pending" do
      pending
      expect(true).to be(false)
    end

    it do
      expect(1).to eq(1)
    end

    it "raises an error" do
      raise "oops"
    end
    it "is pending but fixed" do
      pending
      expect { raise "error" }.to raise_error
    end
  end
end
