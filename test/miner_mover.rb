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

  describe "MinerMover.mine_ore" do
    before do
      @kwargs = { perform_work: false,
                  random_difficulty: false,
                  random_reward: false, }
    end

    it "mines to a depth, unsigned int" do
      expect(MinerMover.mine_ore(1, **@kwargs)).must_equal 1
    end
  end
end
