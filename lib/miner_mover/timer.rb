class MinerMover
  class Timer
    SECS_PER_MIN = 60
    MINS_PER_HOUR = 60
    SECS_PER_HOUR = SECS_PER_MIN * MINS_PER_HOUR

    # YYYY-MM-DD HH::MM::SS.mmm
    def self.timestamp(t)
      t.strftime "%Y-%m-%d %H:%M:%S.%L"
    end

    # HH::MM::SS.mmm.uuuuuuuu
    def self.elapsed_display(elapsed_ms, show_us: false)
      elapsed_s, ms = elapsed_ms.divmod 1000
      ms_only, ms_fraction = ms.round(8).divmod 1

      h = elapsed_s / SECS_PER_HOUR
      elapsed_s -= h * SECS_PER_HOUR
      m, s = elapsed_s.divmod SECS_PER_MIN

      hmsms = [[h, m, s].map { |i| i.to_s.rjust(2, '0') }.join(':'),
               ms_only.to_s.rjust(3, '0')]
      hmsms << (ms_fraction * 10 ** 8).round.to_s.ljust(8, '0') if show_us
      hmsms.join('.')
    end

    def restart(t = Time.now)
      @start = t
      self
    end
    alias_method :initialize, :restart

    def timestamp(t = Time.now)
      self.class.timestamp t
    end

    def timestamp!(t = Time.now)
      puts '-' * 70, timestamp(t), '-' * 70
    end

    def elapsed(t = Time.now)
      t - @start
    end

    def elapsed_ms(t = Time.now)
      elapsed(t) * 1000
    end

    def elapsed_display(t = Time.now)
      self.class.elapsed_display(elapsed_ms(t))
    end
    alias_method :to_s, :elapsed_display
    alias_method :inspect, :elapsed_display

    def stamp(msg = '', t = Time.now)
      format("%s %s", elapsed_display(t), msg)
    end

    def stamp!(msg = '', t = Time.now)
      puts stamp(msg, t)
    end
  end
end
