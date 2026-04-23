# frozen_string_literal: true

RSpec.describe RubyLsp::Listeners::SpecStyle do
  describe "spec_style_patch" do
    it "disables initialization" do
      RubyLsp::Listeners::SpecStyle.new(double("response_builder"), double("global_state"), double("dispatcher"), double("uri"))
    end
  end
end

RSpec.describe RubyLsp::Requests::Support::TestItem do
  describe "#add_tag" do
    it "appends a tag to the item's tags" do
      item = described_class.new(
        "some_id",
        "some label",
        URI("file:///fake_spec.rb"),
        RubyLsp::Interface::Range.new(
          start: RubyLsp::Interface::Position.new(line: 0, character: 0),
          end: RubyLsp::Interface::Position.new(line: 0, character: 0),
        ),
        framework: :rspec,
      )

      expect(item.to_hash[:tags]).to eq(["framework:rspec"])

      item.add_tag("test_case")
      expect(item.to_hash[:tags]).to eq(["framework:rspec", "test_case"])

      item.add_tag("test_group")
      expect(item.to_hash[:tags]).to eq(["framework:rspec", "test_case", "test_group"])
    end
  end
end
