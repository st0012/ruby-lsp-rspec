# typed: strict
# frozen_string_literal: true

module RubyLsp
  module RSpec
    class DocumentSymbol
      extend T::Sig

      include ::RubyLsp::Requests::Support::Common

      sig do
        params(
          response_builder: ResponseBuilders::DocumentSymbol,
          dispatcher: Prism::Dispatcher,
        ).void
      end
      def initialize(response_builder, dispatcher)
        @response_builder = response_builder

        dispatcher.register(self, :on_call_node_enter, :on_call_node_leave)
      end

      sig { params(node: Prism::CallNode).void }
      def on_call_node_enter(node)
        case node.message
        when "example", "it", "specify"
          name = generate_name(node)

          return unless name

          @response_builder.last.children << RubyLsp::Interface::DocumentSymbol.new(
            name: name,
            kind: LanguageServer::Protocol::Constant::SymbolKind::METHOD,
            selection_range: range_from_node(node),
            range: range_from_node(node),
          )
        when "context", "describe", "shared_examples", "shared_context", "shared_examples_for"
          return if node.receiver && node.receiver&.slice != "RSpec"

          name = generate_name(node)

          return unless name

          symbol = RubyLsp::Interface::DocumentSymbol.new(
            name: name,
            kind: LanguageServer::Protocol::Constant::SymbolKind::MODULE,
            selection_range: range_from_node(node),
            range: range_from_node(node),
            children: [],
          )

          @response_builder.last.children << symbol
          @response_builder.push(symbol)
        end
      end

      sig { params(node: Prism::CallNode).void }
      def on_call_node_leave(node)
        case node.message
        when "context", "describe", "shared_examples", "shared_context", "shared_examples_for"
          return if node.receiver && node.receiver&.slice != "RSpec"

          @response_builder.pop
        end
      end

      sig { params(node: Prism::CallNode).returns(T.nilable(String)) }
      def generate_name(node)
        arguments = node.arguments&.arguments

        return unless arguments

        argument = arguments.first

        case argument
        when Prism::StringNode
          argument.unescaped
        when Prism::CallNode
          "<#{argument.name}>"
        when nil
          nil
        else
          argument.slice
        end
      end
    end
  end
end
