require "test_helper"

class SocialConstructTest < ActiveSupport::TestCase
  test("it has a version number") do
    assert SocialConstruct::VERSION
  end
end
