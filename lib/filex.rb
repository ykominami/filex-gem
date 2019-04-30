require "filex/version"

module Filex
  require 'digest'
  require 'pp'
  require 'erubis'
  require 'yaml'

  class Error < StandardError; end
  # Your code goes here...
  class Filex
    def self.setup(mes)
      mes.addExitCode("EXIT_CODE_CANNOT_ANALYZE_YAMLFILE")
      mes.addExitCode("EXIT_CODE_NAME_ERROR_EXCEPTION_IN_ERUBY")
      mes.addExitCode("EXIT_CODE_ERROR_EXCEPTION_IN_ERUBY")
    end

    def self.loadYaml(str, mes)
      yamlhs={}
      begin
        yamlhs=YAML.load(str)
      rescue Error => ex
        mes.outputException(ex)
        exit(mes.ec("EXIT_CODE_CANNOT_ANALYZE_YAMLFILE"))
      end

      yamlhs
    end

    def self.checkAndLoadYamlfile(yamlfname, mes)
      str=Filex.checkAndLoadFile(yamlfname, mes)
      self.loadYaml(str, mes)
    end

    def self.checkAndExpandYamlfile(yamlfname, objx, mes)
      lines=Filex.checkAndExpandFileLines(yamlfname, objx, mes)
      str=self.escapeBySingleQuoteInYamlFormatOneLines(lines).join("\n")
      mes.outputDebug("=str")
      mes.outputDebug(str)
      self.loadYaml(str, mes)
    end

    def self.checkAndExpandFileLines(fname, data, mes)
       checkAndExpandFile(fname, data, mes).split("\n")
    end

    def self.checkAndLoadFile(fname, mes)
      size=File.size?(fname)
      if size and size > 0
        begin
          strdata=File.read(fname)
        rescue IOError => ex
          mesg = "Can't read #{fname}"
          mes.outputFatal(mesg)
          mes.outputException(ex)
          exit(mes.ec("EXIT_CODE_CANNOT_READ_FILE"))
        rescue SystemCallError => ex
          mesg = "Can't write #{fname}"
          mes.outputFatal(mesg)
          mes.outputException(ex)
          exit(mes.ec("EXIT_CODE_CANNOT_READ_FILE"))
        end
      else
        mesg=%Q!Can not find #{fname} or is empty| size=|#{size}|!
        mes.outputError(mesg)
        exit(mes.ec("EXIT_CODE_CANNOT_FIND_FILE_OR_EMPTY"))
      end

      if strdata.strip.empty?
        mesg=%Q!#{fname} is empty!
        mes.outputFatal(mesg)
        exit(mes.ec("EXIT_CODE_FILE_IS_EMPTY"))
      else
#        mes.outputInfo(Digest::MD5.hexdigest(strdata))
      end

      strdata
    end

    def self.expandStr(erubyStr, data, mes,fnames={})
      begin
        mes.outputInfo("erubyStr=|#{erubyStr}|")
        mes.outputInfo("data=#{data}")
        strdata=Erubis::Eruby.new(erubyStr).result(data)
      rescue NameError => ex
        mes.outputException(ex)
        fnames.map{|x| mes.outputFatal( %Q!#{x[0]}=#{x[1]}! )}
        exit(mes.ec("EXIT_CODE_NAME_ERROR_EXCEPTION_IN_ERUBY"))
      rescue Error => ex
        mes.outputException(ex)
        fnames.map{|x| mes.outputFatal(%Q!#{x[0]}=#{x[1]}!) }
        exit(mes.ec("EXIT_CODE_ERROR_EXCEPTION_IN_ERUBY"))
      end
      strdata
    end

    def self.checkAndExpandFile(fname, objx, mes)
      strdata=checkAndLoadFile(fname, mes)
      mes.outputInfo("fname=#{fname}")
      mes.outputInfo("strdata=#{strdata}")
      mes.outputInfo("objx=#{objx}")
      strdata2=expandStr(strdata, objx, mes, {fname: fname})
      strdata2
    end

    def self.escapeBySingleQuoteInYamlFormatOneLines(lines)
      prevQuoto=false
      str=lines.map{|x|
        index=x.index('*')
        index=x.index(':') unless index
        if index
          index2=x.index(%q!'!)
          unless index2
            y=Filex.escapeBySingleQuoteInYamlFormatOneLine(x, prevQuoto)
            prevQuoto=true
          else
            y=x
          end
          y
        else
          x
        end
      }
    end

    def self.escapeBySingleQuoteInYamlFormatOneLine(x, prevQuotoFlag=false)
      if (m=/(^[\s\-]+)([^\-\s\:].*)/.match(x))
        l=m[1]
        r=m[2]
        if prevQuotoFlag
          l+"'"+r+"'"
        else
          index=r.index('-')
          index=r.index('*') unless index
          index=r.index(':') unless index
          if index
            l+"'"+r+"'"
          else
            l+r
          end
        end
      elsif (index=x.index(':'))
        if index
          l=x.slice(0,(index+1))
          r=x.slice((index+1),x.size)
        else
          l=x
          r=nil
        end
        #      l,r=x.split(':')
        if r and !(r.strip.empty?)
          l+"'"+r+"'"
        else
          l
        end
      else
        x
      end
    end
  end
end
