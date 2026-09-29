require "chess"

RSpec.describe Chess do
  it "has a version number" do
    expect(Chess::VERSION).not_to be nil
  end
end
