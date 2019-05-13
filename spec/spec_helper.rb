$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "eventboss"

class FixedTimer
  def at(time)
    @time = Time.at(time)
  end

  def now
    @time
  end
end
