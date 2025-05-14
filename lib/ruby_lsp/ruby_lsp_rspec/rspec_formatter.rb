# typed: true
# frozen_string_literal: true

require "rspec/core/formatters"
require "ruby_lsp/test_reporters/lsp_reporter"

module RubyLsp
  module RSpec
    class RSpecFormatter
      ::RSpec::Core::Formatters.register(
        self,
        :example_passed,
        :example_pending,
        :example_failed,
        :example_started,
        :stop,
      )

      def initialize(output)
        @output = output
      end

      def example_started(notification)
        example = notification.example
        uri = uri_for(example)
        id = generate_id(example)
        line = example.location.split(":").last
        RubyLsp::LspReporter.instance.start_test(id: id, uri: uri, line: line)
      end

      def example_passed(notification)
        example = notification.example
        uri = uri_for(example)
        id = generate_id(example)
        RubyLsp::LspReporter.instance.record_pass(id: id, uri: uri)
      end

      def example_failed(notification)
        example = notification.example
        uri = uri_for(example)
        id = generate_id(example)
        RubyLsp::LspReporter.instance.record_fail(id: id, message: notification.exception.message, uri: uri)
      end

      def example_pending(notification)
        example = notification.example
        uri = uri_for(example)
        id = generate_id(example)
        RubyLsp::LspReporter.instance.record_skip(id: id, uri: uri)
      end

      def stop(notification)
        RubyLsp::LspReporter.instance.shutdown
      end

      def uri_for(example)
        absolute_path = File.expand_path(example.file_path)
        URI::Generic.from_path(path: absolute_path)
      end

      def generate_id(example)
        [example, *example.example_group.parent_groups].reverse.map(&:location).join("::")
      end
    end
  end
end
