require 'ProcessMemory/pe'

pe = PE::PEModule.new ProcessMemory::ProcessMemoryUtil.memoryutil_startup
base = pe.base_addr

def build_expr(_base, name, ix, offset, _pe)
  "_ (MName::#{name}) => base;[:$base + 0x3C:] + 4 + $base => fh;" \
    "[:($fh + 20 + ([:$fh + 16:] & 0xFFFF)) + 40 * #{ix} + 12:] => va;" +
    format('$base+$va+0x%0X', offset)
end

def build_expr_tenuki(base, name, ix, offset, pe)
  fh = pe.ptr_i32(base + 0x3C) + 4 + base

  va_offset = fh + 0x14 + (pe.ptr_i32(fh + 0x10) & 0xFFFF) + 0x28 * ix + 12
  va_offset -= base

  "_ (MName::#{name}) => base;" \
    "[:$base+#{va_offset}:] => va;" +
    format('$base+$va+0x%0X', offset)
end

def build_expr_usamimi(_base, _name, ix, offset, _pe)
  "h = ptr(g + 0x3C) + 4 + g\n" \
    "i = ptr(h + 0x14 +(ptr(h + 0x10) & 0xFFFF) + 0x28 * 0x#{ix.to_s 16} + 0x0C)\n" +
    format('g + i + 0x%0X', offset)
end

puts pe.base_name
puts format('%08X - %08X', pe.base_addr, pe.base_addr + pe.size)

print 'input:'
while (addr = STDIN.gets.hex) != 0
  puts "\noutput:"
  sec = pe.address_of addr
  ix = sec.index
  if ix
    va = sec.virtual_address
    offset = addr - base - va
    args = [base, pe.base_name, ix, offset, pe]
    puts format('0x%08X = 0x%08X + 0x%08X + 0x%08X', addr, base, va, offset)
    puts build_expr(*args)
    puts build_expr_tenuki(*args)
    puts build_expr_usamimi(*args)
  else
    puts format('0x%08X is not found', addr)
  end
  print "\ninput:"
end
