# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLsp::RSpec::TestDiscovery do
  include RubyLsp::TestHelper

  let(:uri) { URI("file:///fake_spec.rb") }

  describe "test discovery" do
    it "discovers RSpec examples" do
      source = <<~RUBY
        RSpec.describe "Sample test" do
          it "first test" do
            expect(true).to be(true)
          end

          it "second test" do
            expect(true).to be(true)
          end
        end
      RUBY

      with_server(source, uri) do |server, uri|
        server.process_message(
          {
            id: 1,
            method: "rubyLsp/discoverTests",
            params: {
              textDocument: { uri: uri },
            },
          },
        )

        items = pop_result(server).response

        expect(items.length).to eq(1)

        test_group = items.first
        expect(test_group[:label]).to eq("Sample test")
        expect(test_group[:children].length).to eq(2)

        test_labels = test_group[:children].map { |i| i[:label] }
        expect(test_labels).to include("first test")
        expect(test_labels).to include("second test")
      end
    end

    it "discovers nested example groups" do
      source = <<~RUBY
        RSpec.describe "Outer group" do
          describe "Inner group" do
            it "nested test" do
              expect(true).to be(true)
            end
          end

          context "Another group" do
            it "another test" do
              expect(true).to be(true)
            end
          end
        end
      RUBY

      with_server(source, uri) do |server, uri|
        server.process_message(
          {
            id: 1,
            method: "rubyLsp/discoverTests",
            params: {
              textDocument: { uri: uri },
            },
          },
        )

        items = pop_result(server).response

        expect(items.length).to eq(1)

        outer_group = items.first
        expect(outer_group[:label]).to eq("Outer group")
        expect(outer_group[:children].length).to eq(2)

        inner_groups = outer_group[:children]
        expect(inner_groups[0][:label]).to eq("Inner group")
        expect(inner_groups[1][:label]).to eq("Another group")

        expect(inner_groups[0][:children].length).to eq(1)
        expect(inner_groups[0][:children][0][:label]).to eq("nested test")

        expect(inner_groups[1][:children].length).to eq(1)
        expect(inner_groups[1][:children][0][:label]).to eq("another test")
      end
    end

    it "handles anonymous examples" do
      source = <<~RUBY
        RSpec.describe "Test group" do
          it do
            expect(true).to be(true)
          end

          specify do
            expect(true).to be(true)
          end

          example do
            expect(true).to be(true)
          end
        end
      RUBY

      with_server(source, uri) do |server, uri|
        server.process_message(
          {
            id: 1,
            method: "rubyLsp/discoverTests",
            params: {
              textDocument: { uri: uri },
            },
          },
        )

        items = pop_result(server).response

        expect(items.length).to eq(1)

        test_group = items.first
        expect(test_group[:label]).to eq("Test group")
        expect(test_group[:children].length).to eq(3)

        test_group[:children].each do |example|
          expect(example[:label]).to match(/\(anonymous example \d+\)/)
        end
      end
    end
  end

  describe "test command resolution" do
    let(:items) do
      [
        {
          id: "Test case example",
          label: "Test case example",
          range: { start: { line: 10 }, end: { line: 12 } },
          tags: ["test_case", "framework:rspec"],
          source_file: "spec/example_spec.rb",
        },
      ]
    end

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
                  source_file: "spec/example_spec.rb",
                },
              ],
            },
          },
        )

        response = pop_result(server).response
        expect(response[:commands]).to include(%r{rspec spec/example_spec\.rb:11})
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
                  source_file: "spec/example_spec.rb",
                  children: [],
                },
              ],
            },
          },
        )

        response = pop_result(server).response
        expect(response[:commands]).to include(%r{rspec spec/example_spec\.rb$})
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
                  source_file: "spec/example_spec.rb",
                  children: [],
                },
              ],
            },
          },
        )

        response = pop_result(server).response
        expect(response[:commands]).to include(%r{rspec spec/example_spec\.rb$})
      end
    end
  end
end
