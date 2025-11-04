# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLsp::RSpec::TestDiscovery do
  include RubyLsp::TestHelper

  let(:uri) { URI("file://#{File.expand_path("fake_spec.rb", __dir__)}") }

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

        RSpec.describe Foo do
          it "third test" do
            expect(true).to be(true)
          end
        end

        RSpec.describe Foo::Bar do
          it "fourth test" do
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

        expect(items.length).to eq(3)

        first_group = items.first
        expect(first_group[:id]).to eq("./spec/fake_spec.rb:1")
        expect(first_group[:label]).to eq("Sample test")
        expect(first_group[:children].length).to eq(2)

        test_ids = first_group[:children].map { |i| i[:id] }
        expect(test_ids).to include("./spec/fake_spec.rb:1::./spec/fake_spec.rb:2")
        expect(test_ids).to include("./spec/fake_spec.rb:1::./spec/fake_spec.rb:6")

        test_labels = first_group[:children].map { |i| i[:label] }
        expect(test_labels).to include("first test")

        expect(test_labels).to include("second test")

        second_group = items[1]
        expect(second_group[:id]).to eq("./spec/fake_spec.rb:11")
        expect(second_group[:label]).to eq("Foo")
        expect(second_group[:children].length).to eq(1)

        test_ids = second_group[:children].map { |i| i[:id] }
        expect(test_ids).to include("./spec/fake_spec.rb:11::./spec/fake_spec.rb:12")

        third_group = items[2]
        expect(third_group[:id]).to eq("./spec/fake_spec.rb:17")
        expect(third_group[:label]).to eq("Foo::Bar")
        expect(third_group[:children].length).to eq(1)

        test_ids = third_group[:children].map { |i| i[:id] }
        expect(test_ids).to include("./spec/fake_spec.rb:17::./spec/fake_spec.rb:18")
      end
    end

    # Tests capybara feature/scenario syntax
    # see https://github.com/teamcapybara/capybara
    it "discovers Capybara examples" do
      source = <<~RUBY
        feature "Sample test" do
          scenario "first test" do
            expect(true).to be(true)
          end

          # Test a mixed syntax
          it "second test" do
            expect(true).to be(true)
          end
        end

        RSpec.describe Foo do
          it "third test" do
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

        expect(items.length).to eq(2)

        first_group = items.first
        expect(first_group[:id]).to eq("./spec/fake_spec.rb:1")
        expect(first_group[:label]).to eq("Sample test")
        expect(first_group[:children].length).to eq(2)

        test_ids = first_group[:children].map { |i| i[:id] }
        expect(test_ids).to include("./spec/fake_spec.rb:1::./spec/fake_spec.rb:2")

        test_labels = first_group[:children].map { |i| i[:label] }
        expect(test_labels).to include("first test")

        expect(test_labels).to include("second test")

        second_group = items[1]
        expect(second_group[:label]).to eq("Foo")
        expect(second_group[:children].length).to eq(1)
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

        first_example = test_group[:children].first
        expect(first_example[:id]).to eq("./spec/fake_spec.rb:1::./spec/fake_spec.rb:2")
        expect(first_example[:label]).to eq("example at ./spec/fake_spec.rb:2")

        second_example = test_group[:children][1]
        expect(second_example[:id]).to eq("./spec/fake_spec.rb:1::./spec/fake_spec.rb:6")
        expect(second_example[:label]).to eq("example at ./spec/fake_spec.rb:6")

        third_example = test_group[:children][2]
        expect(third_example[:id]).to eq("./spec/fake_spec.rb:1::./spec/fake_spec.rb:10")
        expect(third_example[:label]).to eq("example at ./spec/fake_spec.rb:10")
      end
    end

    it "ignores describe and context calls without blocks" do
      source = <<~RUBY
        RSpec.describe "Valid group with block" do
          it "test in valid group" do
            expect(true).to be(true)
          end
        end

        # These should be ignored because they don't have blocks
        RSpec.describe "Invalid group without block"
        RSpec.context "Another invalid group"

        # This should also work with non-RSpec receivers
        describe "Valid group without RSpec prefix" do
          it "test in valid group" do
            expect(true).to be(true)
          end
        end

        # Invalid without block, even without RSpec prefix
        describe "Invalid without block"
        context "Invalid context without block"
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

        # Should only find 2 valid groups (the ones with blocks)
        expect(items.length).to eq(2)

        first_group = items.first
        expect(first_group[:label]).to eq("Valid group with block")
        expect(first_group[:children].length).to eq(1)
        expect(first_group[:children][0][:label]).to eq("test in valid group")

        second_group = items[1]
        expect(second_group[:label]).to eq("Valid group without RSpec prefix")
        expect(second_group[:children].length).to eq(1)
        expect(second_group[:children][0][:label]).to eq("test in valid group")
      end
    end

    it "handles nested groups where some lack blocks" do
      source = <<~RUBY
        RSpec.describe "Outer group with block" do
          # Valid nested group
          describe "Valid nested group" do
            it "nested test" do
              expect(true).to be(true)
            end
          end

          # Invalid nested group (no block) - should be ignored
          describe "Invalid nested group"

          # Another valid nested group
          context "Valid context" do
            it "context test" do
              expect(true).to be(true)
            end
          end

          # Invalid context (no block) - should be ignored
          context "Invalid context"
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
        expect(outer_group[:label]).to eq("Outer group with block")
        # Should only have 2 children (the valid nested groups)
        expect(outer_group[:children].length).to eq(2)

        nested_groups = outer_group[:children]
        expect(nested_groups[0][:label]).to eq("Valid nested group")
        expect(nested_groups[0][:children].length).to eq(1)
        expect(nested_groups[0][:children][0][:label]).to eq("nested test")

        expect(nested_groups[1][:label]).to eq("Valid context")
        expect(nested_groups[1][:children].length).to eq(1)
        expect(nested_groups[1][:children][0][:label]).to eq("context test")
      end
    end
  end
end
