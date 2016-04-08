module Utils

  def self.number2Buffer(num)
    8.times.map{|i| (num >> (56 - 8 * i)) & 255}
  end

  def self.pack_trim(str)
    str.gsub(/\x00/, '')
  end

end