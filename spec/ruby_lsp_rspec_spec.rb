# typed: false
# frozen_string_literal: true

RSpec.describe RubyLsp::RSpec do
  include RubyLsp::TestHelper

  let(:uri) { URI("file:///fake_spec.rb") }

  describe "document symbol" do
    it "generates correct document symbols" do
      source = <<~RUBY
        RSpec.describe Foo do
          context "when something" do
            it "does something" do
            end
          end

          describe Foo::Bar do
            it "does something else" do
            end

            context "when something else" do
              it "does something something" do
              end
            end
          end

          it variable do
          end

          class Baz
            def test_baz; end
          end

          # unname test is ignored
          it { }
        end
      RUBY

      with_server(source, uri) do |server, uri|
        server.process_message(
          {
            id: 2,
            method: "textDocument/documentSymbol",
            params: {
              textDocument: { uri: uri },
            },
          },
        )

        result = server.pop_response
        expect(result).to be_a(RubyLsp::Result)
        response = result.response

        expect(response.count).to eq(1)
        foo = response[0]
        expect(foo.name).to eq("Foo")
        expect(foo.kind).to eq(LanguageServer::Protocol::Constant::SymbolKind::MODULE)
        expect(foo.children.count).to eq(4)

        expect(foo.children[0].name).to eq("\"when something\"")
        expect(foo.children[0].kind).to eq(LanguageServer::Protocol::Constant::SymbolKind::MODULE)
        expect(foo.children[0].children.count).to eq(1)
        expect(foo.children[0].children[0].name).to eq("\"does something\"")
        expect(foo.children[0].children[0].kind).to eq(LanguageServer::Protocol::Constant::SymbolKind::METHOD)

        foo_bar = foo.children[1]
        expect(foo_bar.name).to eq("Foo::Bar")
        expect(foo_bar.children.count).to eq(2)
        expect(foo_bar.children[0].name).to eq("\"does something else\"")
        expect(foo_bar.children[1].name).to eq("\"when something else\"")
        expect(foo_bar.children[1].children.count).to eq(1)
        expect(foo_bar.children[1].children[0].name).to eq("\"does something something\"")

        expect(foo.children[2].name).to eq("<variable>")

        expect(foo.children[3].name).to eq("Baz")
        expect(foo.children[3].children.count).to eq(1)
        expect(foo.children[3].children[0].name).to eq("test_baz")
      end
    end
  end

  describe "code lens" do
    it "generates code lens for basic tests" do
      source = <<~RUBY
        RSpec.describe Foo do
          context "when something" do
            it "does something" do
            end
          end
        end
      RUBY

      with_server(source, uri) do |server, uri|
        server.process_message(
          {
            id: 1,
            method: "textDocument/codeLens",
            params: {
              textDocument: { uri: uri },
              position: { line: 0, character: 0 },
            },
          },
        )

        response = server.pop_response.response

        expect(response.count).to eq(9)

        expect(response[0].data).to eq({ type: "test", kind: :group, group_id: nil, id: 1 })
        expect(response[1].data).to eq({ type: "test_in_terminal", kind: :group, group_id: nil, id: 1 })
        expect(response[2].data).to eq({ type: "debug", kind: :group, group_id: nil, id: 1 })

        0.upto(2) do |i|
          expect(response[i].command.arguments).to eq([
            "/fake_spec.rb",
            "Foo",
            "bundle exec rspec /fake_spec.rb:1",
            { start_line: 0, start_column: 0, end_line: 5, end_column: 3 },
          ])
        end

        expect(response[3].data).to eq({ type: "test", kind: :group, group_id: 1, id: 2 })
        expect(response[4].data).to eq({ type: "test_in_terminal", kind: :group, group_id: 1, id: 2 })
        expect(response[5].data).to eq({ type: "debug", kind: :group, group_id: 1, id: 2 })

        3.upto(5) do |i|
          expect(response[i].command.arguments).to eq([
            "/fake_spec.rb",
            "when something",
            "bundle exec rspec /fake_spec.rb:2",
            { start_line: 1, start_column: 2, end_line: 4, end_column: 5 },
          ])
        end

        expect(response[6].data).to eq({ type: "test", kind: :example, group_id: 2 })
        expect(response[7].data).to eq({ type: "test_in_terminal", kind: :example, group_id: 2 })
        expect(response[8].data).to eq({ type: "debug", kind: :example, group_id: 2 })

        6.upto(8) do |i|
          expect(response[i].command.arguments).to eq([
            "/fake_spec.rb",
            "does something",
            "bundle exec rspec /fake_spec.rb:3",
            { start_line: 2, start_column: 4, end_line: 3, end_column: 7 },
          ])
        end
      end
    end

    it "recognizes different example, it, and specify declarations" do
      source = <<~RUBY
        RSpec.describe Foo do
          it { do_something }
          it var1 do
            do_something
          end
          specify { do_something }
          example var2 do
            do_something
          end
        end
      RUBY

      with_server(source, uri) do |server, uri|
        server.process_message(
          {
            id: 1,
            method: "textDocument/codeLens",
            params: {
              textDocument: { uri: uri },
              position: { line: 0, character: 0 },
            },
          },
        )

        response = server.pop_response.response

        expect(response.count).to eq(15)

        expect(response[3].command.arguments[1]).to eq("<unnamed>")
        expect(response[6].command.arguments[1]).to eq("<var1>")
        expect(response[9].command.arguments[1]).to eq("<unnamed>")
        expect(response[12].command.arguments[1]).to eq("<var2>")
      end
    end

    it "recognizes different context and describe declarations" do
      source = <<~RUBY
        RSpec.describe(Foo::Bar) do
        end

        RSpec.describe Foo::Bar do
        end

        context(Foo) do
        end

        describe Foo do
        end

        context "Foo" do
        end

        describe var do
        end

        # these should bot be recognized
        context
        describe
        context("foo")
      RUBY

      with_server(source, uri) do |server, uri|
        server.process_message(
          {
            id: 1,
            method: "textDocument/codeLens",
            params: {
              textDocument: { uri: uri },
              position: { line: 0, character: 0 },
            },
          },
        )

        response = server.pop_response.response

        expect(response.count).to eq(18)

        expect(response[11].command.arguments[1]).to eq("Foo")
        expect(response[13].command.arguments[1]).to eq("Foo")
        expect(response[15].command.arguments[1]).to eq("<var>")
      end
    end

    context "when the file is not a test file" do
      let(:uri) { URI("file:///not_spec_file.rb") }

      it "ignores file" do
        source = <<~RUBY
          class FooBar
            context "when something" do
            end
          end
        RUBY

        with_server(source, uri) do |server, uri|
          server.process_message(
            {
              id: 1,
              method: "textDocument/codeLens",
              params: {
                textDocument: { uri: uri },
                position: { line: 0, character: 0 },
              },
            },
          )

          response = server.pop_response.response

          expect(response.count).to eq(0)
        end
      end
    end

    context "when there's a binstub" do
      let(:binstub_path) { File.expand_path("../bin/rspec", __dir__) }

      before do
        File.write(binstub_path, <<~RUBY)
          #!/usr/bin/env ruby
          puts "binstub is called"
        RUBY
      end

      after do
        FileUtils.rm(binstub_path) if File.exist?(binstub_path)
      end

      it "uses the binstub" do
        source = <<~RUBY
          RSpec.describe(Foo::Bar) do
          end
        RUBY

        with_server(source, uri) do |server, uri|
          server.process_message(
            {
              id: 1,
              method: "textDocument/codeLens",
              params: {
                textDocument: { uri: uri },
                position: { line: 0, character: 0 },
              },
            },
          )

          response = server.pop_response.response

          expect(response.count).to eq(3)
          expect(response[0].command.arguments[2]).to eq("bundle exec bin/rspec /fake_spec.rb:1")
        end
      end
    end
  end
end
