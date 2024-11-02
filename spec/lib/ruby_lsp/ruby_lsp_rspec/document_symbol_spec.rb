# typed: false
# frozen_string_literal: true

require_relative "../../../spec_helper"

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

        result = server.pop_response
        expect(result).to be_a(RubyLsp::Result)
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
  end
end
