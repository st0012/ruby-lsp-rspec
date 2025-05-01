# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLsp::RSpec::Addon do
  subject { described_class.new }

  describe "#resolve_test_commands" do
    before do
      allow(subject).to receive(:rspec_command).and_return("rspec")
      subject.activate(RubyLsp::GlobalState.new, Thread::Queue.new)
    end

    context "with individual test cases" do
      it "generates commands to run specific tests using line numbers" do
        items = [
          {
            id: "FooTest::My test group::should do something",
            label: "should do something",
            range: { start: { line: 10 }, end: { line: 12 } },
            tags: ["test_case"],
            source_file: "spec/foo_spec.rb",
          },
        ]

        commands = subject.resolve_test_commands(items)
        expect(commands).to eq(["rspec spec/foo_spec.rb:11"])
      end

      it "handles multiple test cases in the same file" do
        items = [
          {
            id: "FooTest::Group 1::test 1",
            label: "test 1",
            range: { start: { line: 10 }, end: { line: 12 } },
            tags: ["test_case"],
            source_file: "spec/foo_spec.rb",
          },
          {
            id: "FooTest::Group 1::test 2",
            label: "test 2",
            range: { start: { line: 15 }, end: { line: 17 } },
            tags: ["test_case"],
            source_file: "spec/foo_spec.rb",
          },
        ]

        commands = subject.resolve_test_commands(items)
        expect(commands).to contain_exactly(
          "rspec spec/foo_spec.rb:11",
          "rspec spec/foo_spec.rb:16",
        )
      end

      it "handles test cases across different files" do
        items = [
          {
            id: "FooTest::test 1",
            label: "test 1",
            range: { start: { line: 10 }, end: { line: 12 } },
            tags: ["test_case"],
            source_file: "spec/foo_spec.rb",
          },
          {
            id: "BarTest::test 1",
            label: "test 1",
            range: { start: { line: 5 }, end: { line: 7 } },
            tags: ["test_case"],
            source_file: "spec/bar_spec.rb",
          },
        ]

        commands = subject.resolve_test_commands(items)
        expect(commands).to contain_exactly(
          "rspec spec/foo_spec.rb:11",
          "rspec spec/bar_spec.rb:6",
        )
      end
    end

    context "with test groups" do
      it "generates commands to run entire files when a group without children is selected" do
        items = [
          {
            id: "FooTest::My test group",
            label: "My test group",
            range: { start: { line: 5 }, end: { line: 20 } },
            tags: ["test_group"],
            source_file: "spec/foo_spec.rb",
            children: [],
          },
        ]

        commands = subject.resolve_test_commands(items)
        expect(commands).to eq(["rspec spec/foo_spec.rb"])
      end

      it "expands groups with children to individual test commands" do
        items = [
          {
            id: "FooTest::My test group",
            label: "My test group",
            range: { start: { line: 5 }, end: { line: 20 } },
            tags: ["test_group"],
            source_file: "spec/foo_spec.rb",
            children: [
              {
                id: "FooTest::My test group::test 1",
                label: "test 1",
                range: { start: { line: 10 }, end: { line: 12 } },
                tags: ["test_case"],
                source_file: "spec/foo_spec.rb",
              },
              {
                id: "FooTest::My test group::test 2",
                label: "test 2",
                range: { start: { line: 15 }, end: { line: 17 } },
                tags: ["test_case"],
                source_file: "spec/foo_spec.rb",
              },
            ],
          },
        ]

        commands = subject.resolve_test_commands(items)
        expect(commands).to contain_exactly(
          "rspec spec/foo_spec.rb:11",
          "rspec spec/foo_spec.rb:16",
        )
      end
    end

    context "with test classes" do
      it "generates commands to run entire files when a class is selected" do
        items = [
          {
            id: "FooTest",
            label: "FooTest",
            range: { start: { line: 0 }, end: { line: 30 } },
            tags: ["test_class"],
            source_file: "spec/foo_spec.rb",
            children: [],
          },
        ]

        commands = subject.resolve_test_commands(items)
        expect(commands).to eq(["rspec spec/foo_spec.rb"])
      end
    end

    context "with custom rspec command" do
      it "uses the configured rspec command" do
        subject.instance_variable_set(:@rspec_command, "bundle exec rspec --format doc")

        items = [
          {
            id: "FooTest::test 1",
            label: "test 1",
            range: { start: { line: 10 }, end: { line: 12 } },
            tags: ["test_case"],
            source_file: "spec/foo_spec.rb",
          },
        ]

        commands = subject.resolve_test_commands(items)
        expect(commands).to eq(["bundle exec rspec --format doc spec/foo_spec.rb:11"])
      end
    end
  end
end
