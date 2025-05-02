# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLsp::RSpec::Addon do
  include RubyLsp::TestHelper

  let(:uri) { URI("file:///fake_spec.rb") }

  describe "test command resolution" do
    it "resolves commands for individual test cases" do
      with_server("", uri) do |server, uri|
        server.process_message(
          {
            id: 1,
            method: "rubyLsp/resolveTestCommands",
            params: {
              items: [
                {
                  id: "Test group::test case",
                  label: "test case",
                  range: { start: { line: 10 }, end: { line: 12 } },
                  tags: ["test_case", "framework:rspec"],
                  uri: uri,
                  children: [],
                },
              ],
            },
          },
        )

        response = pop_result(server).response
        expect(response[:commands]).to include(%r{bundle exec rspec /fake_spec\.rb:11})
      end
    end

    it "resolves commands for test groups" do
      with_server("", uri) do |server, uri|
        server.process_message(
          {
            id: 1,
            method: "rubyLsp/resolveTestCommands",
            params: {
              items: [
                {
                  id: "Test group",
                  label: "Test group",
                  range: { start: { line: 5 }, end: { line: 20 } },
                  tags: ["test_group", "framework:rspec"],
                  uri: uri,
                  children: [],
                },
              ],
            },
          },
        )

        response = pop_result(server).response
        expect(response[:commands]).to include(%r{bundle exec rspec /fake_spec\.rb:6$})
      end
    end

    it "resolves commands for test files" do
      with_server("", uri) do |server, uri|
        server.process_message(
          {
            id: 1,
            method: "rubyLsp/resolveTestCommands",
            params: {
              items: [
                {
                  id: "spec/example_spec.rb",
                  label: "example_spec.rb",
                  tags: ["test_file", "framework:rspec"],
                  uri: uri,
                  children: [],
                },
              ],
            },
          },
        )

        response = pop_result(server).response
        expect(response[:commands]).to include(%r{bundle exec rspec /fake_spec\.rb$})
      end
    end
  end
end
