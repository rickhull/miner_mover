module MinerMover
  LINE_SEP = $/.freeze

  # $/ is the default line separator: "\n"
  def self.puts(str, io = $stdout, separator = LINE_SEP)
    self.write_nonblock(io, str + separator)
  end

  def self.write_nonblock(io, str)
    begin
      # nonblocking write attempt; ensure the full string is written
      size = str.bytesize
      num_bytes = io.write_nonblock(str)
      # blocking write if nonblocking write comes up short
      io.write str.byteslice(num_bytes, size - num_bytes) if num_bytes < size
    rescue IO::WaitWritable, Errno::EINTR
      IO.select([], [io]) # wait until writable
      retry
    end
  end

  def self.log_fmt(timer, id, msg)
    format("%s %s %s", timer.elapsed_display, id, msg)
  end

  def self.log(timer, id, msg)
    self.puts self.log_fmt(timer, id, msg)
  end

  # i +- 50% at squeeze 0
  # i +- 25% at squeeze 1, 12.5% at squeeze 2, etc.
  def self.randomize(i, squeeze = 0)
    r, base = rand, 0.5
    # every squeeze, increase the base closer to 1 and cut the rand in half
    squeeze.times { |s|
      r *= 0.5
      base += 0.5 ** (s+2)
    }
    i * (base + r)
  end

  # ore is handled in blocks of 1M
  module Ore
    BLOCK = 1_000_000
    WORD_LENGTH = 4
    WORD_MAX = 256 ** WORD_LENGTH

    # return 4 bytes, unsigned 32 bit integer, network order
    def self.encode(ore)
      raise "WORD_MAX overflow: #{self.block(ore)}M ore" if ore > WORD_MAX
      [ore].pack('N')
    end

    # return an integer from the first 4 bytes
    def self.decode(binary)
      raise "unexpected size: #{binary.bytesize}" unless binary.bytesize == 4
      binary.unpack('N').first
    end

    # raw ore in, blocks out
    def self.block(ore, size = BLOCK)
      ore.to_f / size
    end

    # mostly used for display purposes
    def self.units(ore)
      if ore % BLOCK == 0 or ore > BLOCK * 100
        format("%iM", self.block(ore).round)
      elsif ore > BLOCK
        format("%.2fM", self.block(ore))
      elsif ore > 10_000
        format("%iK", self.block(ore, 1_000).round)
      else
        format("%i", ore)
      end
    end

    # entirely used for display purposes
    def self.display(ore)
      format("%s ore", self.units(ore))
    end
  end
end
