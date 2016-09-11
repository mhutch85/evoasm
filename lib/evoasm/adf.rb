require 'evoasm/search'

module Evoasm
  class ADF < FFI::AutoPointer

    require_relative 'adf/io.rb'


    def self.release(ptr)
      Libevoasm.adf_destroy(ptr)
      Libevoasm.adf_free(ptr)
    end

    def initialize(other_ptr)
      ptr = Libevoasm.adf_alloc
      unless Libevoasm.adf_clone other_ptr, ptr
        Libevoasm.adf_free(ptr)
        raise Error.last
      end
      super ptr
    end

    def run(*input_example)
      run_all(input_example).first
    end

    def run_all(*input_examples)
      input = ADF::Input.new(input_examples)

      output_ptr = Libevoasm.adf_run self, input

      if output_ptr.null?
        raise Error.last
      end

      ADF::Output.new(output_ptr).to_a
    end

    def size
      Libevoasm.adf_size self
    end

    def clone
      self.class.new self
    end

    def eliminate_introns!
      unless Libevoasm.adf_eliminate_introns self
        raise Libevoasm::Error.last
      end
    end

    def eliminate_introns
      clone.tap(&:eliminate_introns!)
    end

    def disassemble_kernel(kernel_index)
      code_ptr_ptr = FFI::MemoryPointer.new :pointer
      code_len = Libevoasm.adf_kernel_code self, kernel_index, code_ptr_ptr
      code_ptr = code_ptr_ptr.read_pointer
      code = code_ptr.read_string(code_len)

      X64.disassemble code, code_ptr.address
    end

    def disassemble_kernels
      Array.new(size) do |kernel_index|
        disassemble_kernel kernel_index
      end
    end

    private def io_registers(input, kernel_index)
      reg_enum_type = Libevoasm.enum_type(:x64_reg_id)
      reg_enum_type.to_h.each_with_object([]) do |(k, v), acc|
        unless k == :n_regs
          io =
            if input
              Libevoasm.adf_is_input_reg(self, kernel_index, v)
            else
              Libevoasm.adf_is_output_reg(self, kernel_index, v)
            end

          acc << k if io
        end
      end
    end

    def input_registers(kernel_index = 0)
      io_registers true, kernel_index
    end

    def output_registers(kernel_index = size - 1)
      io_registers false, kernel_index
    end

    def disassemble(frame = false)
      code_ptr_ptr = FFI::MemoryPointer.new :pointer
      code_len = Libevoasm.adf_code self, frame, code_ptr_ptr
      code_ptr = code_ptr_ptr.read_pointer
      code = code_ptr.read_string(code_len)

      p code.each_byte.map { |b| "%0.2x" % b }.join(' ')
      p input_registers
      p output_registers

      X64.disassemble code, code_ptr.address
    end

    def to_gv
      require 'gv'

      graph = GV::Graph.open 'g'

      disasms = disassemble_kernels
      addrs = disasms.map do |disasm|
        disasm.first&.first
      end

      size.times do |kernel_index|
        label = '<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0">'

        label << '<TR>'
        label << %Q{<TD COLSPAN="3"><B>Kernel #{kernel_index}</B></TD>}
        label << '</TR>'

        disasm = disasms[kernel_index]
        addr = addrs[kernel_index]
        jmp_addrs = []

        disasm.each do |line|
          op_str = line[2]

          label << '<TR>'
          label << %Q{<TD ALIGN="LEFT">0x#{line[0].to_s 16}</TD>}
          label << %Q{<TD ALIGN="LEFT">#{line[1]}</TD>}

          if op_str =~ /0x(\h+)/
            jmp_addr = Integer($1, 16)
            jmp_addrs << jmp_addr
            port = jmp_addr
          else
            port = ''
          end
          label << %Q{<TD ALIGN="LEFT" PORT="#{port}">#{op_str}</TD>}
          label << '</TR>'
        end
        label << '</TABLE>'

        node = graph.node addr.to_s,
                          shape: :none,
                          label: graph.html(label)

        succs = [kernel_index + 1, Libevoasm.adf_kernel_alt_succ(self, kernel_index)].select do |succ|
          succ < size
        end

        succs.each do |succ|
          succ_addr = addrs[succ]
          tail_port =
            if jmp_addrs.include? succ_addr
              # Remove, in case we have the same
              # successor multiple times
              # only one of which goes through the jump
              jmp_addrs.delete succ_addr
              succ_addr.to_s
            else
              's'
            end
          graph.edge 'e', node, graph.node(succ_addr.to_s), tailport: tail_port, headport: 'n'
        end
      end

      graph
    end
  end
end
