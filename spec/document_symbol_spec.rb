# typed: false
# frozen_string_literal: true

require_relative "spec_helper"

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

          context "日本語テスト" do
            it "何かのテスト" do
            end
          end
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

        result = pop_result(server)
        response = result.response

        expect(response.count).to eq(1)
        foo = response[0]
        expect(foo.name).to eq("Foo")
        expect(foo.kind).to eq(LanguageServer::Protocol::Constant::SymbolKind::MODULE)
        expect(foo.children.count).to eq(5)

        expect(foo.children[0].name).to eq("when something")
        expect(foo.children[0].kind).to eq(LanguageServer::Protocol::Constant::SymbolKind::MODULE)
        expect(foo.children[0].children.count).to eq(1)
        expect(foo.children[0].children[0].name).to eq("does something")
        expect(foo.children[0].children[0].kind).to eq(LanguageServer::Protocol::Constant::SymbolKind::METHOD)

        foo_bar = foo.children[1]
        expect(foo_bar.name).to eq("Foo::Bar")
        expect(foo_bar.children.count).to eq(2)
        expect(foo_bar.children[0].name).to eq("does something else")
        expect(foo_bar.children[1].name).to eq("when something else")
        expect(foo_bar.children[1].children.count).to eq(1)
        expect(foo_bar.children[1].children[0].name).to eq("does something something")

        expect(foo.children[2].name).to eq("<variable>")

        expect(foo.children[3].name).to eq("Baz")
        expect(foo.children[3].children.count).to eq(1)
        expect(foo.children[3].children[0].name).to eq("test_baz")

        expect(foo.children[4].name).to eq("日本語テスト")
        expect(foo.children[4].children[0].name).to eq("何かのテスト")
      end
    end

    it "simple shared_examples" do
      source = <<~RUBY
        RSpec.shared_examples 'simple shared examples' do
          it 'does something' do
          end
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

        response = pop_result(server).response

        expect(response.count).to eq(1)
        shared = response[0]
        expect(shared.name).to eq("simple shared examples")
        expect(shared.kind).to eq(LanguageServer::Protocol::Constant::SymbolKind::MODULE)
        expect(shared.children.count).to eq(1)

        example = shared.children[0]
        expect(example.name).to eq("does something")
        expect(example.kind).to eq(LanguageServer::Protocol::Constant::SymbolKind::METHOD)
      end
    end

    it "symbol shared_examples" do
      source = <<~RUBY
        RSpec.shared_examples :symbol_shared_examples do
          it 'does something in symbol' do
          end
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

        response = pop_result(server).response

        expect(response.count).to eq(1)
        shared = response[0]
        expect(shared.name).to eq(":symbol_shared_examples")
        expect(shared.kind).to eq(LanguageServer::Protocol::Constant::SymbolKind::MODULE)
        expect(shared.children.count).to eq(1)

        child = shared.children[0]
        expect(child.name).to eq("does something in symbol")
        expect(child.kind).to eq(LanguageServer::Protocol::Constant::SymbolKind::METHOD)
      end
    end

    it "shared_examples with parameter" do
      source = <<~RUBY
        RSpec.shared_examples "shared example with parameter" do |parameter|
          let(:something) { parameter }
          it "uses the given parameter" do
            expect(something).to eq(parameter)
          end
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

        response = pop_result(server).response

        expect(response.count).to eq(1)
        shared = response[0]
        expect(shared.name).to eq("shared example with parameter")
        expect(shared.kind).to eq(LanguageServer::Protocol::Constant::SymbolKind::MODULE)
        expect(shared.children.count).to eq(1)

        child1 = shared.children[0]
        expect(child1.name).to eq("uses the given parameter")
        expect(child1.kind).to eq(LanguageServer::Protocol::Constant::SymbolKind::METHOD)
      end
    end

    it "simple shared_context" do
      source = <<~RUBY
        RSpec.shared_context "simple shared_context" do
          before { @some_var = :some_value }
          def shared_method
            "it works"
          end
          let(:shared_let) { {'arbitrary' => 'object'} }
          subject do
            'this is the subject'
          end
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

        response = pop_result(server).response

        expect(response.count).to eq(1)
        expect(response[0].name).to eq("simple shared_context")
        expect(response[0].kind).to eq(LanguageServer::Protocol::Constant::SymbolKind::MODULE)
        expect(response[0].children.count).to eq(2)
      end
    end

    it "symbol shared_context" do
      source = <<~RUBY
        RSpec.shared_context :symbol_shared_context do
          before { @some_var = :some_value }
          def shared_method
            "it works"
          end
          let(:shared_let) { {'arbitrary' => 'object'} }
          subject do
            'this is the subject'
          end
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

        response = pop_result(server).response

        expect(response.count).to eq(1)
        expect(response[0].name).to eq(":symbol_shared_context")
        expect(response[0].kind).to eq(LanguageServer::Protocol::Constant::SymbolKind::MODULE)
        expect(response[0].children.count).to eq(2)
      end
    end

    it "simple shared_examples_for" do
      source = <<~RUBY
        RSpec.shared_examples_for "simple shared_examples_for" do
          before { @some_var = :some_value }
          def shared_method
            "it works"
          end
          let(:shared_let) { {'arbitrary' => 'object'} }
          subject do
            'this is the subject'
          end
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

        response = pop_result(server).response

        expect(response.count).to eq(1)
        expect(response[0].name).to eq("simple shared_examples_for")
        expect(response[0].kind).to eq(LanguageServer::Protocol::Constant::SymbolKind::MODULE)
        expect(response[0].children.count).to eq(2)
      end
    end

    it "symbol shared_examples_for" do
      source = <<~RUBY
        RSpec.shared_examples_for :symbol_shared_examples_for do
          before { @some_var = :some_value }
          def shared_method
            "it works"
          end
          let(:shared_let) { {'arbitrary' => 'object'} }
          subject do
            'this is the subject'
          end
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

        response = pop_result(server).response

        expect(response.count).to eq(1)
        expect(response[0].name).to eq(":symbol_shared_examples_for")
        expect(response[0].kind).to eq(LanguageServer::Protocol::Constant::SymbolKind::MODULE)
        expect(response[0].children.count).to eq(2)
      end
    end

    it "on_call_node_leave for shared examples" do
      source = <<~RUBY
        RSpec.shared_examples "shared examples" do
        end

        describe "something" do
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

        response = pop_result(server).response

        expect(response.count).to eq(2)
        expect(response[0].name).to eq("shared examples")
        expect(response[0].kind).to eq(LanguageServer::Protocol::Constant::SymbolKind::MODULE)

        expect(response[1].name).to eq("something")
        expect(response[1].kind).to eq(LanguageServer::Protocol::Constant::SymbolKind::MODULE)
      end
    end

    it "on_call_node_leave for shared_context" do
      source = <<~RUBY
        RSpec.shared_context "shared context" do
        end

        describe "something" do
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

        response = pop_result(server).response

        expect(response.count).to eq(2)
        expect(response[0].name).to eq("shared context")
        expect(response[0].kind).to eq(LanguageServer::Protocol::Constant::SymbolKind::MODULE)

        expect(response[1].name).to eq("something")
        expect(response[1].kind).to eq(LanguageServer::Protocol::Constant::SymbolKind::MODULE)
      end
    end

    it "on_call_node_leave for shared_examples_for" do
      source = <<~RUBY
        RSpec.shared_examples_for "shared examples for" do
        end

        describe "something" do
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

        response = pop_result(server).response

        expect(response.count).to eq(2)
        expect(response[0].name).to eq("shared examples for")
        expect(response[0].kind).to eq(LanguageServer::Protocol::Constant::SymbolKind::MODULE)

        expect(response[1].name).to eq("something")
        expect(response[1].kind).to eq(LanguageServer::Protocol::Constant::SymbolKind::MODULE)
      end
    end
  end
end
