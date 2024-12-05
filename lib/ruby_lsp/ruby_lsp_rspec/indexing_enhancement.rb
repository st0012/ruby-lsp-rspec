# typed: strict
# frozen_string_literal: true

module RubyLsp
  module RSpec
    class IndexingEnhancement < RubyIndexer::Enhancement
      extend T::Sig

      sig { override.params(node: Prism::CallNode).void }
      def on_call_node_enter(node)
        return if node.receiver

        name = node.name

        case name
        when :let, :let!
          block_node = node.block
          return unless block_node

          arguments = node.arguments
          return unless arguments

          return if arguments.arguments.count != 1

          method_name_node = T.must(arguments.arguments.first)

          method_name = case method_name_node
          when Prism::StringNode
            method_name_node.slice
          when Prism::SymbolNode
            method_name_node.unescaped
          end

          return unless method_name

          @listener.add_method(method_name, block_node.location, [RubyIndexer::Entry::Signature.new([])])
        when :subject, :subject!
          block_node = node.block
          return unless block_node

          arguments = node.arguments

          if arguments && arguments.arguments.count == 1
            method_name_node = T.must(arguments.arguments.first)
          end

          method_name = if method_name_node
            case method_name_node
            when Prism::StringNode
              method_name_node.slice
            when Prism::SymbolNode
              method_name_node.unescaped
            end
          else
            "subject"
          end

          return unless method_name

          @listener.add_method(method_name, block_node.location, [RubyIndexer::Entry::Signature.new([])])
        end
      end
    end
  end
end
