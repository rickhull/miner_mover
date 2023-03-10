require 'minitest/autorun'
require 'miner_mover/worker'

describe MinerMover do
  describe "MinerMover.work" do
    it "rejects invalid work types" do
      expect { MinerMover.work(2, :invalid) }.must_raise
    end

    it "sleeps for a duration to simulate waiting on an IO response" do
      n = 0.1
      expect(MinerMover.work(n, :wait)).must_equal n
    end

    it "performs fibonacci to simulate CPU work" do
      expect(MinerMover.work(0.1, :cpu)).must_be(:<, 0.5)
    end

    it "returns instantly" do
      expect(MinerMover.work(5, :instant)).must_equal 0
    end
  end

  describe "MinerMover.mine_ore" do
    before do
      @miner = MinerMover::Miner.new(variance: 0, partial_reward: false)
    end

    it "mines to a depth, unsigned int" do
      expect(@miner.mine_ore(1)).must_equal 0
    end
  end
end
