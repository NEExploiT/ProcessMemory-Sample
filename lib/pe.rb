require 'ProcessMemory'
include ProcessMemory

# メモリ上のPEフォーマットを扱う
class PELib
  # コンストラクタ
  # @param [ProcessMemoryEx] mem 入力元
  def initialize(mem)
    @mem = mem
    @base_addr = mem.base_addr
    @base_name = mem.modules[@base_addr]

    # ヘッダ解析
    @nt_header = @base_addr + ptr_i32(@base_addr + 0x3C)
    @file_header = analyze_fileheader @nt_header + 4
    optiheader = @file_header[:optionalheader]
    @optional_header = analyze_optiheader optiheader, @file_header
    @data_directories = analyze_datadirs @optional_header[:PtrOfDataDirectory]

    # セクション解析
    sec_offset = @file_header[:optionalheader] + @file_header[:optional_size]
    @sections = read_sections(sec_offset, @file_header[:number_sections])
  end

  attr_reader :base_name, :base_addr

  def offset_of(addr)
    rva = addr - @base_addr
    secs = @sections.select{|(va, size), (_ix, _sec)|
      va <= rva && rva < va + size
    }
    case secs.size
    when 0 then [nil, nil]
    when 1 then secs.first[1]
    else raise format '%08X cant found', addr
    end
  end

  # Get Int32 Value from addr
  # @param [Integer] addr
  # @return [Integer] Value
  def ptr_i32(addr)
    @mem.ptr_fmt(addr, 4, 'V')
  end

  private

  def analyze_fileheader(fileheader)
    flag, optional_size = ptr_i32(fileheader + 0x10).divmod(0x1_0000)
    {
      fileheader: fileheader,
      optionalheader: fileheader + 20, # IMAGE_SIZEOF_FILE_HEADER = 20
      number_sections: ptr_i32(fileheader + 2) & 0xFFFF,
      flag: flag,
      relocs_stripped: flag & 1 == 1,
      optional_size: optional_size
    }
  end

  def analyze_optiheader(opti, _fh)
    magic = @mem.ptr_fmt(opti, 2, 'v')
    raise "err: unknown optinalmagic (0x#{magic.to_s 16})" unless 0x10b == magic || 0x20b == magic
    {
      Magic: magic,
      MajorLinkVersion: @mem.ptr_fmt(opti + 2, 1, 'C'),
      MinerLinkVersion: @mem.ptr_fmt(opti + 3, 1, 'C'),
      SizeOfCode: ptr_i32(opti + 4),
      SizeOfInitialData: ptr_i32(opti + 8),
      SizeOfUnInitialData: ptr_i32(opti + 12),
      AddressOfEntryPoint: ptr_i32(opti + 0x10),
      BaseOfCode: ptr_i32(opti + 0x14),
      BaseOfData: ptr_i32(opti + 0x18),
      ImageBase: ptr_i32(opti + 0x1C),
      SectionAlignment: ptr_i32(opti + 0x20),
      FileAlignment: ptr_i32(opti + 0x24),
      MajorOperatingSystemVersion: @mem.ptr_fmt(opti + 0x28, 2, 'v'),
      MinorOperatingSystemVersion: @mem.ptr_fmt(opti + 0x2A, 2, 'v'),
      MajorImageVersion: @mem.ptr_fmt(opti + 0x2C, 2, 'v'),
      MinorImageVersion: @mem.ptr_fmt(opti + 0x2E, 2, 'v'),
      MajorSubSystemVersion: @mem.ptr_fmt(opti + 0x30, 2, 'v'),
      MinorSubSystemVersion: @mem.ptr_fmt(opti + 0x32, 2, 'v'),
      Win32VersionValue: ptr_i32(opti + 0x34),
      SizeOfImage: ptr_i32(opti + 0x38),
      SizeOfHeaders: ptr_i32(opti + 0x3C),
      CheckSum: ptr_i32(opti + 0x40),
      Subsystem: @mem.ptr_fmt(opti + 0x44, 2, 'v'),
      DllCharacteristics: @mem.ptr_fmt(opti + 0x46, 2, 'v'),
      SizeOfStackReserve: ptr_i32(opti + 0x48),
      SizeOfStackCommit: ptr_i32(opti + 0x4C),
      SizeOfHeapReserve: ptr_i32(opti + 0x50),
      SizeOfHeapCommit: ptr_i32(opti + 0x54),
      LoaderFlags: ptr_i32(opti + 0x58),
      NumberOfRvaAndSizes: ptr_i32(opti + 0x5C),
      PtrOfDataDirectory: opti + 0x60
    }
  end

  # @return [Hash] Analyzed DataDirectories
  def analyze_datadirs(offset)
    keys = %i[Export Import Resource Exception
              Certificate BaseRelocation DebugInfo Architecture
              GPtr TLS LoadCfg BoundImport
              IAT DelayImport CLRHeader _Reserve]
    @mem.ptr_fmt(offset, 8 * 16, 'V*').each_slice(2)
        .with_index.with_object({}) do |(data, ix), memo|
      memo[keys[ix]] = data
    end
  end

  # PE Headers
  module PEFormat
    extend Fiddle::Importer
    dlload # これがないと以下2行でエラーが出る
    # include Fiddle::BasicTypes
    include Fiddle::Win32Types
    ImageSectionHeader = struct(
      %w[
        char[8]\ Name
        DWORD32\ VirtualSize
        DWORD32\ VirtualAddress
        DWORD32\ SizeOfRawData
        DWORD32\ PointerToRawData
        DWORD32\ PointerToRelocations
        DWORD32\ PointerToLinenumbers
        WORD\ NumberOfRelocations
        WORD\ NumberOfLinenumbers
        DWORD32\ Characteristics
      ]
    )

    # 拡張してみる
    ImageSectionHeader.prepend Module.new{
      def Name
        super.pack('c8').unpack('Z*').first
      end
    }
  end # End of ProcessMemory::WinMemAPI::PEFormat

  ImageSectionHeader = PEFormat::ImageSectionHeader
  ImageSectionHeaderSize = ImageSectionHeader.size

  def read_section(offset)
    buf = @mem.ptr_buf(offset, ImageSectionHeaderSize)
    ImageSectionHeader.new Fiddle::Pointer[buf]
  end

  def read_sections(offset, count)
    count.times.with_object({}) do |ix, memo|
      current = offset + ImageSectionHeaderSize * ix
      sec = read_section(current)

      memo[[sec.VirtualAddress, sec.VirtualSize]] = [ix, sec]
    end
  end
end
