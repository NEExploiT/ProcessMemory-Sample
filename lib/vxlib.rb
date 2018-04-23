require 'ProcessMemory.rb'
include ProcessMemory
# 省略記法を許すためのお約束
include ProcessMemoryUtil

# 基本情報の取得
# 万能クラスの気があるのでリファクタリングできるならしたい
class RGSS
  RGSSDll = Struct.new(:name, :version, :base_addr, :info) do
    def initialize(modules)
      base, n = modules.detect{|_, n| /^RGSS\d+[EJ]?.dll$/ =~ n }
      v = n.gsub('.dll', '')
      i = RGSS.const_get v
      super(n.freeze, v.freeze, base, i)
    end

    def symbol_tbl_addr
      @symbol_tbl_addr ||= info.symbol_tbl + base_addr
    end

    def gvar_tbl_addr
      @gvar_tbl_addr ||= info.gvar_tbl + base_addr
    end

    def ace?
      @ace ||= info.vx_ace
    end
  end
  # RGSS基本情報
  RGSSSet = Struct.new(:symbol_tbl, :gvar_tbl, :vx_ace) do
    def initialize(st, gt, ace = false)
      super
    end
  end

  attr_reader :rgss_dll

  def initialize(mem)
    @mem = mem || ProcessMemory::ProcessMemoryEx.latest
    RGSS.current = self
    make_keys
  end

  class << self
    attr_accessor :current
  end

  def tables
    return @rgss_dll if @rgss_dll
    @rgss_dll = RGSSDll.new @mem.modules
  end

  attr_reader :key_to_name, :name_to_key

  def make_keys
    @key_to_name = {}
    @name_to_key = {}
    symbols.each{|_h, k, v|
      s = ace? ? RGSSString.new(k, ace?, @mem) : @mem.strdup(k)
      @key_to_name[v] = s
      @name_to_key[s] = v
    }
  end

  def symbol_key(name)
    @name_to_key.fetch name
  end

  def symbol_name(key)
    @key_to_name.fetch key
  end

  def ace?
    return @is_ace unless @is_ace.nil?
    @is_ace = tables.ace?
  end

  def globals
    @globals ||= RGSSInternalHash.new(@mem.ptr(tables.gvar_tbl_addr), ace?, @mem).each.map{|_h, k, v|
      [key_to_name[k], v]
    }.to_h
  end

  private def symbols
    RGSSInternalHash.new @mem.ptr(tables.symbol_tbl_addr), ace?, @mem
  end
  #                      symbol_table, global_vars
  RGSS103J = RGSSSet.new 0x144514, 0x1452F0
  #RGSS103J = RGSSSet.new 0x144534, 0x145310 
  def RGSS103J.symbol_tbl
    # [:(MName::RGSS103J.dll)+0x003BB6:]+0x019C30
    ptr(MName('RGSS103J.dll') + 0x003BB6) + 0x019C30
  end
  def RGSS103J.gvar_tbl
    # [:(MName::RGSS103J.dll)+0x003BB6:]+0x018E54
    ptr(MName('RGSS103J.dll') + 0x003BB6) + 0x018E54
  end
  RGSS104J = RGSSSet.new 0x1836BC, 0x184498
  RGSS200J = RGSSSet.new 0x18A23C, 0x18B018
  RGSS202J = RGSS200J
  RGSS300  = RGSSSet.new 0x25a2ac, 0x2ac044, true
  RGSS301  = RGSS300
end
# Ruby Stringを取り込む
# VXAce対応
class RGSSString < String
  def rgss3_string(mem, addr)
    if (mem.ptr(addr) & (1 << 13)).nonzero?
      mem.strdup(mem.ptr(addr + 12))
    else
      mem.strdup(addr + 8)
    end
  end

  def initialize(addr, vxace = false, mem = nil)
    mem ||= ProcessMemory::ProcessMemoryEx.latest
    super(
      if vxace
        rgss3_string(mem, addr)
      else
        mem.strdup(mem.ptr(addr + 12))
      end
    )
  end
end

# Ruby EngineのHashTableを外部から検索・列挙する
# VXAce対応？
class RGSSInternalHash
  def initialize(addr, vxace = false, mem = nil)
    @mem = mem || ProcessMemory::ProcessMemoryEx.latest
    @hash = addr
    @vxace = vxace
    raise 'sry packed entry is not supported' if vxace && @mem.ptr(addr + 8).odd?
  end

  def num_bins
    @num_bins ||= @mem.ptr(@hash + 4)
  end

  def num_ents
    @num_ents ||= @mem.ptr(@hash + 8)
  end

  def [](hash)
    bins = @mem.ptr_fmt(@mem.ptr(@hash + 12), num_bins * 4, 'V*')
    it = bins[hash % num_bins]
    while it.nonzero?
      break @mem.ptr(it + 8) if @mem.ptr_fmt(it, 4, 'V') == hash
      it = @mem.ptr(it + 12)
    end
  end

  def to_h
    each.with_object({}) do |(_h, k, v), memo|
      memo[k] = v
    end
  end

  def each(&blk)
    if block_given?
      _each_entries(&blk)
    else
      Enumerator.new(num_ents) do |y|
        _each_entries{|hash, key, val|
          y << [hash, key, val]
        }
      end
    end
  end

  private def _each_entries
    bins = @mem.ptr_fmt(@mem.ptr(@hash + 12), num_bins * 4, 'V*')
    bins.each do |entry|
      it = entry
      while it.nonzero?
        hashed_key = @mem.ptr(it)
        raw_key = @mem.ptr(it + 4)
        record = @mem.ptr(it + 8)
        yield(hashed_key, raw_key, record)
        it = @mem.ptr(it + 12)
      end
    end
  end
end

class RGSS2Object
  def initialize(addr, rgss = RGSS.current, mem = ProcessMemory::ProcessMemoryEx.latest)
    @mem = mem
    @rgss = rgss
    @addr = addr
    @basic = @basic = [ptr(addr), ptr(addr + 4)]
  end

  def instance_tbl
    @instance_tbl ||= RGSSInternalHash.new(ptr(@addr + 8)).to_h.map{|k, v|
      [@rgss.key_to_name[k], v]
    }.to_h
  end

  def [](name)
    instance_tbl[name]
  end
  private def ptr(addr)
    @mem.ptr addr
  end
end

class RGSS3Object
  def initialize(addr, rgss = RGSS.current, mem = ProcessMemory::ProcessMemoryEx.latest)
    @mem = mem
    @rgss = rgss
    @addr = addr
    @basic = [ptr(addr), ptr(addr + 4)]
    raise 'unsupported OBJECT' if (@basic[0] & 1 << 13) != 0
    @ivptr = ptr addr + 12
  end

  def instance_values
    @instance_values ||= RGSSInternalHash.new(ptr(@addr + 16)).to_h.map do |(k, v)|
      [@rgss.key_to_name[k], v]
    end.to_h
  end

  def [](name)
    ptr @ivptr + 4 * instance_values[name]
  end

  private def ptr(addr)
    @mem.ptr addr
  end
end

RGSS.new memoryutil_startup
# writer = RGSSGWriter.new
# writer.environment.pry

# puts eval(ERB.new(File.read('vx.erb'), nil, '%-').src, writer.environment, 'vx.erb', 0).encode(Encoding::CP932)
