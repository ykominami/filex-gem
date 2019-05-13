require "filex/version"

module Filex
  require "digest"
  require "pp"
  require "erubis"
  require "yaml"
  require "messagex"

  class Error < StandardError; end

  class Filex
    def self.setup(mes)
      mes.add_exitcode("EXIT_CODE_CANNOT_ANALYZE_YAMLFILE")
      mes.add_exitcode("EXIT_CODE_NAME_ERROR_EXCEPTION_IN_ERUBY")
      mes.add_exitcode("EXIT_CODE_ERROR_EXCEPTION_IN_ERUBY")
    end

    def self.load_yaml(str, mes)
      yamlhs = {}
      begin
        yamlhs = YAML.safe_load(str, [Date, Symbol])
      rescue Error => e
        mes.output_exception(e)
        mes.output_fatal("str=#{str}")
        exit(mes.ec("EXIT_CODE_CANNOT_ANALYZE_YAMLFILE"))
      end

      yamlhs
    end

    def self.check_and_load_yamlfile(yamlfname, mes)
      str = Filex.check_and_load_file(yamlfname, mes)
      load_yaml(str, mes)
    end

    def self.check_and_expand_yamlfile(yamlfname, objx, mes)
      lines = Filex.check_and_expand_file_lines(yamlfname, objx, mes)
      str = escape_by_single_quote_with_lines_in_yamlformat(lines, mes).join("\n")
      mes.output_debug("=str")
      mes.output_debug(str)
      load_yaml(str, mes)
    end

    def self.check_and_expand_file_lines(fname, data, mes)
      check_and_expand_file(fname, data, mes).split("\n")
    end

    def self.check_and_load_file(fname, mes)
      size = File.size?(fname)
      if size && (size > 0)
        begin
          strdata = File.read(fname)
        rescue IOError => e
          mesg = "Can't read #{fname}"
          mes.output_fatal(mesg)
          mes.output_exception(e)
          exit(mes.ec("EXIT_CODE_CANNOT_READ_FILE"))
        rescue SystemCallError => e
          mesg = "Can't write #{fname}"
          mes.output_fatal(mesg)
          mes.output_exception(e)
          exit(mes.ec("EXIT_CODE_CANNOT_READ_FILE"))
        end
      else
        mesg = %Q(Can not find #{fname} or is empty| size=|#{size}|)
        mes.output_error(mesg)
        exit(mes.ec("EXIT_CODE_CANNOT_FIND_FILE_OR_EMPTY"))
      end

      if strdata.strip.empty?
        mesg = %Q(#{fname} is empty)
        mes.output_fatal(mesg)
        exit(mes.ec("EXIT_CODE_FILE_IS_EMPTY"))
      else
        digest = Digest::MD5.hexdigest(strdata)
        mes.output_info(digest)
      end

      strdata
    end

    def self.expand_str(eruby_str, data, mes, fnames={})
      begin
        mes.output_info("eruby_str=|#{eruby_str}|")
        mes.output_info("data=#{data}")
        strdata = Erubis::Eruby.new(eruby_str).result(data)
      rescue NameError => e
        mes.output_exception(e)
        fnames.map {|x| mes.output_fatal(%Q(#{x[0]}=#{x[1]})) }
        exit(mes.ec("EXIT_CODE_NAME_ERROR_EXCEPTION_IN_ERUBY"))
      rescue Error => e
        mes.output_exception(e)
        fnames.map {|x| mes.output_fatal(%Q(#{x[0]}=#{x[1]})) }
        exit(mes.ec("EXIT_CODE_ERROR_EXCEPTION_IN_ERUBY"))
      end
      strdata
    end

    def self.check_and_expand_file(fname, objx, mes)
      strdata = check_and_load_file(fname, mes)
      mes.output_info("fname=#{fname}")
      mes.output_info("strdata=#{strdata}")
      mes.output_info("objx=#{objx}")
      strdata2 = expand_str(strdata, objx, mes, { fname: fname })
      strdata2
    end

    def self.colon_space(str)
      if (m = /^(\s*([^\s]+):\s)(.*)$/.match(str))
        key = m[1]
        value = m[3]
      end

      [key, value]
    end

    def self.colon_not_space(str)
      if (m = /^(\s*([^\s]+):[^\s])(.*)$/.match(str))
        key = m[1]
        value = m[3]
      end

      [key, value]
    end

    def self.colon(str)
      if (m = /^(\s*([^\s]+):)(.*)$/.match(str))
        key = m[1]
        value = m[3]
      end

      [key, value]
    end

    def self.hyphen_space(str)
      if (m = /^(\s*((\-\s+)+))(.+)$/.match(str))
        key = m[1]
        value = m[4]
      end

      [key, value]
    end

    def self.escape_single_quote_yaml_first(line, state)
      k, v = colon_space(line)
      state[:mes].output_info("1|k=#{k}")
      k, v = colon(line) unless k
      state[:mes].output_info("2|k=#{k}")

      if v&.index("-")
        k, v = hyphen_space(line)
        state[:mes].output_info("3|k=#{k}")
        if k
          state[:need_quoto] = true
          state[:mes].output_info("NQ|1|need_quoto=#{state[:need_quoto]}")
        end
      end

      unless k
        k, v = hyphen_space(line)
      end

      [k, v]
    end

    def self.escape_single_quote_yaml_second(line, state, key, value)
      state[:mes].output_info("4|k=#{key}|v=#{value}")

      return [key, value] if value.nil? || value.strip.empty?

      state[:has_quoto] = true if value.index("'")

      return [key, value] if value.index(":").nil?

      return([key, value]) if /\d:/.match?(value)

      k2, v2 = colon_space(value)
      state[:mes].output_info("51|k2=#{k2}|v2=#{v2}")

      unless k2
        k3, v3 = colon_not_space(value)
        state[:mes].output_info("52|k3=#{k3}|v3=#{v3}")
        state[:need_quoto] = true

        unless k3
          k2, v2 = colon(value)
          state[:mes].output_info("53|k2=#{k2}|v2=#{v2}")
          state[:need_quoto] = true
        end
      end

      if k2
        key += k2
        value = v2
        state[:mes].output_info("6|k=#{key}|v=#{value}")
      end
      [key, value]
    end

    def self.escape_single_quote_yaml_third(line, state, key, value)
      return line if value.nil? || value.strip.empty?

      unless state[:need_quoto]
        if value.index(":") || value.index("*")
          state[:mes].output_info("1 not need_quoto")
          unless value.index("-")
            state[:need_quoto] = true
            state[:mes].output_info("NQ|2|need_quoto=#{state[:need_quoto]}")
          end
          state[:mes].output_info("1A need_quoto=#{state[:need_quoto]}")
        end
      end

      if state[:need_quoto] && !state[:has_quoto]
        state[:mes].output_info("2 need_quoto")
        key + %q(') + value + %q(')
      else
        line
      end
    end

    def self.escape_by_single_quote_with_lines_in_yamlformat(lines, mes)
      state = { mes: mes }
      lines.map do |line|
        state[:need_quoto] = false
        state[:has_quoto] = false

        k, v = escape_single_quote_yaml_first(line, state)
        k, v = escape_single_quote_yaml_second(line, state, k, v)
        if k
          escape_single_quote_yaml_third(line, state, k, v)
        else
          line
        end
      end
    end
  end
end
