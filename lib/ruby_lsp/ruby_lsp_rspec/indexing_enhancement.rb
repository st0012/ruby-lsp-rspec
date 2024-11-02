# typed: strict
# frozen_string_literal: true

module RubyLsp
  module RSpec
    class IndexingEnhancement < RubyIndexer::Enhancement
      extend T::Sig

      sig do
        override.params(
          owner: T.nilable(RubyIndexer::Entry::Namespace),
          node: Prism::CallNode,
          file_path: String,
          code_units_cache: T.any(
            T.proc.params(arg0: Integer).returns(Integer),
            Prism::CodeUnitsCache,
          ),
        ).void
      end
      def on_call_node_enter(owner, node, file_path, code_units_cache)
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

          @index.add(RubyIndexer::Entry::Method.new(
            method_name,
            file_path,
            RubyIndexer::Location.from_prism_location(block_node.location, code_units_cache),
            RubyIndexer::Location.from_prism_location(block_node.location, code_units_cache),
            nil,
            [RubyIndexer::Entry::Signature.new([])],
            RubyIndexer::Entry::Visibility::PUBLIC,
            owner,
          ))
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

          @index.add(RubyIndexer::Entry::Method.new(
            method_name,
            file_path,
            RubyIndexer::Location.from_prism_location(block_node.location, code_units_cache),
            RubyIndexer::Location.from_prism_location(block_node.location, code_units_cache),
            nil,
            [RubyIndexer::Entry::Signature.new([])],
            RubyIndexer::Entry::Visibility::PUBLIC,
            owner,
          ))
        end
      end
    end
  end
end
