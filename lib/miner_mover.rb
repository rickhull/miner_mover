module MinerMover
  LINE_SEP = $/.freeze

  # $/ is the default line separator: "\n"
  def self.puts(str, io = $stdout, separator = LINE_SEP)
    self.write(io, str + separator)
  end

  def self.write(io, str)
    # nonblocking write attempt; ensure the full string is written
    begin
      num_bytes = io.write_nonblock(str)
    rescue IO::WaitWritable, Errno::EINTR
      IO.select([], [io]) # wait until writable
      retry
    end
    # blocking write if nonblocking write comes up short
    if num_bytes < str.bytesize
      io.write str.byteslice(num_bytes, str.bytesize - num_bytes)
    end
    nil
  end

  def self.log_fmt(timer, id, msg)
    format("%s %s %s", timer, id, msg)
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
    BLOCK = 1_000_000  # between fib(30) and fib(31)
    WORD_LENGTH = 4    # bytes
    WORD_MAX = 256 ** WORD_LENGTH      # up to 4.3B ore
    HEX_UNPACK = "H#{WORD_LENGTH * 2}" # 4 bytes is 8 hex digits

    # return 4 bytes, unsigned 32 bit integer, network order
    def self.encode(ore)
      raise "WORD_MAX overflow: #{self.block(ore)}M ore" if ore > WORD_MAX
      [ore].pack('N')
    end

    # return an integer from the first 4 bytes
    def self.decode(word)
      raise "unexpected size: #{word.bytesize}" unless word.bytesize == 4
      word.unpack('N').first
    end

    # return "0x01020304" for "\x01\x02\x03\x04"
    def self.hex(word)
      raise "unexpected size: #{word.bytesize}" unless word.bytesize == 4
      "0x" + word.unpack(HEX_UNPACK).first
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
