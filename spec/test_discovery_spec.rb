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
        expect(first_group[:id]).to eq("Sample test")
        expect(first_group[:label]).to eq("Sample test")
        expect(first_group[:children].length).to eq(2)

        test_ids = first_group[:children].map { |i| i[:id] }
        expect(test_ids).to include("Sample test::first test")
        expect(test_ids).to include("Sample test::second test")

        test_labels = first_group[:children].map { |i| i[:label] }
        expect(test_labels).to include("first test")

        expect(test_labels).to include("second test")

        second_group = items[1]
        expect(second_group[:id]).to eq("Foo")
        expect(second_group[:label]).to eq("Foo")
        expect(second_group[:children].length).to eq(1)

        test_ids = second_group[:children].map { |i| i[:id] }
        expect(test_ids).to include("Foo::third test")

        third_group = items[2]
        expect(third_group[:id]).to eq("Foo::Bar")
        expect(third_group[:label]).to eq("Foo::Bar")
        expect(third_group[:children].length).to eq(1)

        test_ids = third_group[:children].map { |i| i[:id] }
        expect(test_ids).to include("Foo::Bar::fourth test")
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
end
