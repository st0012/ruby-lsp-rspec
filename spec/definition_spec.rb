# typed: false
# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe RubyLsp::RSpec do
  include RubyLsp::TestHelper

  describe "definition" do
    it "finds the subject declaration" do
      source = <<~RUBY
        RSpec.describe Foo do
          subject { 1 }

          it "does something" do
            subject
            foo(subject)
          end
        end
      RUBY

      tempfile = Tempfile.new(["", "_fake_spec.rb"])
      tempfile.write(source)
      tempfile.close
      uri = URI(tempfile.path)

      with_server(source, uri) do |server, uri|
        index = server.instance_variable_get(:@global_state).index
        index.index_single(RubyIndexer::IndexablePath.new(nil, tempfile.path))
        server.process_message(
          {
            id: 1,
            method: "textDocument/definition",
            params: {
              textDocument: { uri: uri },
              position: { line: 4, character: 4 },
            },
          },
        )

        response = server.pop_response.response

        expect(response.count).to eq(1)
        expect(response[0].target_uri).to eq(URI::Generic.from_path(path: tempfile.path).to_s)
        range = response[0].target_range.attributes
        range_hash = { start: range[:start].to_hash, end: range[:end].to_hash }
        expect(range_hash).to eq(
          start: { line: 1, character: 10 },
          end: { line: 1, character: 15 },
        )

        server.process_message(
          {
            id: 2,
            method: "textDocument/definition",
            params: {
              textDocument: { uri: uri },
              position: { line: 5, character: 9 },
            },
          },
        )

        response = server.pop_response.response

        expect(response.count).to eq(1)
        expect(response[0].target_uri).to eq(URI::Generic.from_path(path: tempfile.path).to_s)
        range = response[0].target_range.attributes
        range_hash = { start: range[:start].to_hash, end: range[:end].to_hash }
        expect(range_hash).to eq(
          start: { line: 1, character: 10 },
          end: { line: 1, character: 15 },
        )
      end
    ensure
      tempfile&.unlink
    end

    it "finds named subject declaration" do
      source = <<~RUBY
        RSpec.describe Foo do
          subject(:variable) { 1 }

          it "does something" do
            subject
            foo(variable)
          end
        end
      RUBY

      tempfile = Tempfile.new(["", "_fake_spec.rb"])
      tempfile.write(source)
      tempfile.close
      uri = URI(tempfile.path)

      with_server(source, uri) do |server, uri|
        index = server.instance_variable_get(:@global_state).index
        index.index_single(RubyIndexer::IndexablePath.new(nil, tempfile.path))
        server.process_message(
          {
            id: 1,
            method: "textDocument/definition",
            params: {
              textDocument: { uri: uri },
              position: { line: 4, character: 4 },
            },
          },
        )

        response = server.pop_response.response

        expect(response.count).to eq(0)

        server.process_message(
          {
            id: 2,
            method: "textDocument/definition",
            params: {
              textDocument: { uri: uri },
              position: { line: 5, character: 9 },
            },
          },
        )

        response = server.pop_response.response

        expect(response.count).to eq(1)
        expect(response[0].target_uri).to eq(URI::Generic.from_path(path: tempfile.path).to_s)
        range = response[0].target_range.attributes
        range_hash = { start: range[:start].to_hash, end: range[:end].to_hash }
        expect(range_hash).to eq(
          start: { line: 1, character: 21 },
          end: { line: 1, character: 26 },
        )
      end
    ensure
      tempfile&.unlink
    end

    it "finds the let declaration" do
      source = <<~RUBY
        RSpec.describe Foo do
          let(:variable) { 1 }

          it "does something" do
            variable
            foo(variable)
          end
        end
      RUBY

      tempfile = Tempfile.new(["", "_fake_spec.rb"])
      tempfile.write(source)
      tempfile.close
      uri = URI(tempfile.path)

      with_server(source, uri) do |server, uri|
        index = server.instance_variable_get(:@global_state).index
        index.index_single(RubyIndexer::IndexablePath.new(nil, tempfile.path))
        server.process_message(
          {
            id: 1,
            method: "textDocument/definition",
            params: {
              textDocument: { uri: uri },
              position: { line: 4, character: 4 },
            },
          },
        )

        response = server.pop_response.response

        expect(response.count).to eq(1)
        expect(response[0].target_uri).to eq(URI::Generic.from_path(path: tempfile.path).to_s)
        range = response[0].target_range.attributes
        range_hash = { start: range[:start].to_hash, end: range[:end].to_hash }
        expect(range_hash).to eq(
          start: { line: 1, character: 17 },
          end: { line: 1, character: 22 },
        )

        server.process_message(
          {
            id: 2,
            method: "textDocument/definition",
            params: {
              textDocument: { uri: uri },
              position: { line: 5, character: 9 },
            },
          },
        )

        response = server.pop_response.response

        expect(response.count).to eq(1)
        expect(response[0].target_uri).to eq(URI::Generic.from_path(path: tempfile.path).to_s)
        range = response[0].target_range.attributes
        range_hash = { start: range[:start].to_hash, end: range[:end].to_hash }
        expect(range_hash).to eq(
          start: { line: 1, character: 17 },
          end: { line: 1, character: 22 },
        )
      end
    ensure
      tempfile&.unlink
    end

    context "when the file is not a test file" do
      let(:uri) { URI("file:///not_spec_file.rb") }

      it "ignores file" do
        source = <<~RUBY
          class FooBar
            def bar
              foo
            end

            def foo; end
          end
        RUBY

        with_server(source, uri) do |server, uri|
          server.process_message(
            {
              id: 1,
              method: "textDocument/definition",
              params: {
                textDocument: { uri: uri },
                position: { character: 4, line: 2 },
              },
            },
          )

          response = server.pop_response.response

          expect(response.count).to eq(1)
        end
      end
    end
  end
end
