include ProcessMemory
# 省略記法on
extend ProcessMemoryUtil

USER_DATABASE_BASE = 0x789D80
VAR_DATABASE_BASE  = 0x78B6F4
SYS_DATABASE_BASE  = 0x789DF0
GAME_INFO = 0x0078B880
VAR_BASE = 0x78B5F4
SVAR_BASE = 0x78B604
# ウディタ文字列
class WditString
  def self.proccess=(prc)
    @@wditor = prc
  end

  def initialize(addr)
    @buf = @@wditor.ptr_fmt(addr, 16 + 4 * 3, 'A16l<l<V')
  end

  def read
    return '' if @buf[1].zero?
    return @@wditor.ptr_buf(@buf[0].unpack('V')[0], @buf[1]) if @buf[2] > 15
    @buf[0][0, @buf[1]]
  end

  def to_s
    @str ||= read.force_encoding('CP932').encode
  end

  def size
    @buf[2]
  end
end

# ウディタの配列って一般化できそうだけどいい方法を思いつかない

class WditNumberArray
  def initialize(addr)
    @base = ProcessMemoryEx.ptr(addr) + 4
    @addr_end = ProcessMemoryEx.ptr(addr + 4)
    @raw_size = @addr_end - @base
  end

  def size
    @size ||= @raw_size / 4
  end

  def [](num)
    to_a[num]
  end

  def to_a
    @ary ||= __to_a
  end

  def __to_a
    ProcessMemoryEx.ptr_fmt(@base, @raw_size, 'V*')
  end
end

class DataBase_Info
  SIZEOF = 0xA8
  def initialize(addr)
    @addr = addr
    addr += 0x10
    @base = ProcessMemoryEx.ptr(addr) + 4
    @addr_end = ProcessMemoryEx.ptr(addr + 4)
    @raw_size = @addr_end - @base
  end

  def size
    @size ||= @raw_size / SIZEOF
  end

  def [](num)
    DataBase_Type.new addr, num
  end

  def keys
    @ary ||= __to_a
  end

  def __to_a
    (0..size).map{|x| @base + x * SIZEOF }.map{|addr| WditString.new(addr).to_s }
  end
end

class WditStringArray
  def initialize(addr)
    @base = ProcessMemoryEx.ptr(addr) + 4
    @addr_end = ProcessMemoryEx.ptr(addr + 4)
  end

  def [](num)
    return @ary[num] if @ary
    WditString.new(addr + 0x1C * num).to_s if num < size
  end

  def size
    @size ||= (@addr_end - @base) / 0x1C
  end

  def __to_a
    (0..size).map do |ix|
      WditString.new(@base + 0x1C * ix).to_s
    end
  end

  def to_a
    @to_a ||= __to_a
  end
end

# ・ユーザーデータベース
# 　　セクションからのアドレス	[:[:[:0x73E07C:]+0x4:]+0x18:]=[:0x789D80:]
# 	タイプの名称		[:0x789D80+0x10:]+0x04+(タイプのID)*0xA8
# 	タイプのメモ		[:0x789D80+0x10:]+0x20+(タイプのID)*0xA8
# 	データの名称		[:[:0x789D80+0x10:]+0x3C+(タイプのID)*0xA8:]+0x4+(データのID)*0x1C
# 	項目の名称	  	[:[:0x789D80+0x10:]+0x4C+(タイプのID)*0xA8:]+0x4+(項目のID)*0x1C
#
# 	項目の値		    [:[:[:0x789D80:]+0x14+(タイプのID)*0x28:]+0x04+(データのID)*0x20:]+(項目の値の順番数)*0x04
# 	項目の文字列		[:[:[:0x789D80:]+0x14+(タイプのID)*0x28:]+0x14+(データのID)*0x20:]+0x4+(項目の文字列の順番数)*0x1C
#
# 	可変データベース
# 	項目の値					[:[:[:0x78B6F4:]+0x14+(タイプのID)*0x28:]+0x04+(データのID)*0x20:]+(項目の値の順番数)*0x04
# 	項目の場所					[:[:0x78B6F4:]+0x04+(タイプのID)*0x28:]+(項目のID)*4
class DataBase_Col
  # 0 = 不明, 1 = 数値, 2 = 文字列
  LOCATION = [nil, 4, 0x14].freeze
  SIZEOF_EXPR = [nil, 4, '0x1c+4'].freeze
  SIZEOF      = [nil, 4, 0x1c].freeze
  def initialize(addr, type, id, col)
    extend ProcessMemoryUtil
    @addr = addr
    @type = type
    @id   = id
    @col  = col
    @name = WditString.new ptr(ptr(addr + 0x10) + 0x4C + type * 0xA8) + 4 + col * 0x1C
    @info = ptr(ptr(ptr(@addr) + type * 0x28 + 4) + col * 4).divmod 1000
  end

  def addr(h = { :< => '[:', :> => ':]' })
    h[:<] * 3 + "0x#{@addr.to_s 16}#{h[:>]}+0x14+#{@type}*0x28#{h[:>]}+#{LOCATION[@info[0]]}+#{@id}*0x20#{h[:>]}" \
      "+#{@info[1]}*#{SIZEOF_EXPR[@info[0]]}"
  end

  def value
    addr = ptr(ptr(ptr(@addr) + 0x14 + @type * 0x28) + LOCATION[@info[0]] + @id * 0x20) + @info[1] * SIZEOF[@info[0]] + (@info[0] == 2 ? 4 : 0)
    case @info[0]
    when 1 then ProcessMemoryEx.ptr_fmt(addr, 4, 'l<')
    when 2 then WditString.new(addr).to_s
    else
      raise "ERR: vdb_base:0x#{addr.to_s 16} type:#{@type} id:#{@id} col:#{@col} unknown value_type"
    end
  end

  def data_type
    case @info[0]
    when 0 then nil
    when 1 then :Number
    when 2 then :String
    end
  end
end
class DataBase_Id
  def initialize(addr, type, id)
    extend ProcessMemoryUtil
    @addr = addr
    @type = type
    @id   = id
    @name = WditString.new ptr(ptr(addr + 0x10) + 0x3C + type * 0xA8) + 4 + id * 0x1C
  end

  def [](col)
    DataBase_Col.new @addr, @type, @id, col
  end

  def keys_get(_addr)
    WditStringArray.new(ptr(@addr + 0x10) + 0x4C + @type * 0xA8).to_a
  end

  def keys
    @keys ||= keys_get @addr
  end
end
class DataBase_Type
  def initialize(addr, type)
    extend ProcessMemoryUtil
    @addr = addr
    @type = type
    @name = WditString.new ptr(addr + 0x10) + 4 + type * 0xA8
  end

  def [](id)
    DataBase_Id.new(@addr, @type, id)
  end

  def keys_get
    WditStringArray.new(ptr(@addr + 0x10) + 0x3C + @type * 0xA8).to_a
  end

  def keys
    @keys ||= keys_get
  end
end
