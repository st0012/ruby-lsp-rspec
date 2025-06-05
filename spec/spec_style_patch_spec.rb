# frozen_string_literal: true

RSpec.describe RubyLsp::Listeners::SpecStyle do
  describe "spec_style_patch" do
    it "disables initialization" do
      RubyLsp::Listeners::SpecStyle.new(double("response_builder"), double("global_state"), double("dispatcher"), double("uri"))
    end
  end
end
