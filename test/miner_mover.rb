require 'minitest/autorun'
require 'miner_mover'

describe MinerMover do
  describe "MinerMover.perform_io" do
    it "sleeps for a duration to simulate waiting on an IO response" do
      expect(MinerMover.perform_io(0.1)).must_equal 0
    end
  end

  describe "MinerMover.perform_work" do
    it "performs fibonacci to simulate CPU work" do
      expect(MinerMover.perform_work(0.2)).must_be(:<, 0.5)
    end
  end
end
