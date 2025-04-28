# typed: strict
# frozen_string_literal: true

module URI
  class Generic
    sig { returns(T.nilable(String)) }
    def to_standardized_path; end
  end
end
