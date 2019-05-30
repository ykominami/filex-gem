# frozen_string_literal: true

#
# ファイル操作用モジュール
#
module Filex
  require "digest"
  require "pp"
  require "erubis"
  require "yaml"
  require "messagex"
  require "filex/version"

  #
  # ファイル操作用モジュールのエラークラス
  #
  class Error < StandardError; end

  #
  # ファイル操作用モジュール
  #
  class Filex # rubocop:disable Metrics/ClassLength
    #
    # Filexクラスで利用する終了ステータスの登録
    #
    # @param mes [Messagex] Messagexクラスのインスタンス
    # @return [void]
    def self.setup(mes)
      mes.add_exitcode("EXIT_CODE_CANNOT_ANALYZE_YAMLFILE")
      mes.add_exitcode("EXIT_CODE_NAME_ERROR_EXCEPTION_IN_ERUBY")
      mes.add_exitcode("EXIT_CODE_ERROR_EXCEPTION_IN_ERUBY")
      mes.add_exitcode("EXIT_CODE_FILE_IS_EMPTY")
    end

    #
    # YAML形式文字列をRubyのオブジェクトに変換
    # @param str [String] YAML形式の文字列
    # @param mes [Messagex] Messagexクラスのインスタンス
    # @return [Hash] YAMLの変換結果
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

    #
    # YAML形式ファイルをRubyのオブジェクトに変換
    #
    # @param yamlfname [String] yamlファイル名
    # @param mes [Messagex] Messagexクラスのインスタンス
    # @return [Hash] YAMLの変換結果
    def self.check_and_load_yamlfile(yamlfname, mes)
      str = Filex.check_and_load_file(yamlfname, mes)
      load_yaml(str, mes)
    end

    #
    # YAML形式ファイルを存在チェック、（eRubyスクリプトとしての）YAMLファイルをハッシュを用いて置換した後にRubyのオブジェクトに変換
    #
    # @param yamlfname [String] yamlファイル名(eRubyスクリプトでもある)
    # @param objx [Hash] eRubyスクリプト置換用ハッシュ
    # @param mes [Messagex] Messagexクラスのインスタンス
    # @return [Hash] YAMLの変換結果
    def self.check_and_expand_yamlfile(yamlfname, objx, mes)
      lines = Filex.check_and_expand_file_lines(yamlfname, objx, mes)
      str = escape_by_single_quote_with_lines_in_yamlformat(lines, mes).join("\n")
      mes.output_debug("=str")
      mes.output_debug(str)
      load_yaml(str, mes)
    end

    #
    # eRubyスクリプトの存在チェック、ハッシュを用いて置換したものを行の配列として得る
    #
    # @param fname [String] eRubyスクリプト名
    # @param data [Hash] eRubyスクリプト置換用ハッシュ
    # @param mes [Messagex] Messagexクラスのインスタンス
    # @return [Array<String>] eRubyスクリプトの変換結果
    def self.check_and_expand_file_lines(fname, data, mes)
      check_and_expand_file(fname, data, mes).split("\n")
    end

    #
    # テキストファイルの存在チェック、ファイルの内容を1個の文字列に変換
    #
    # @param fname [String] ファイル名
    # @param mes [Messagex] Messagexクラスのインスタンス
    # @return [String] ファイルの内容
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

    #
    # eRubyスクリプト文字列を、ハッシュを用いて置換した内容を1個の文字列に変換
    #
    # @param eruby_str [String] eRubyスクリプト文字列
    # @param data [Hash] eRubyスクリプト置換用ハッシュ
    # @param mes [Messagex] Messagexクラスのインスタンス
    # @param fnames [Hash] 入力ファイル名群
    # @return [String] eRubyスクリプトの変換結果
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

    #
    # eRubyスクリプトファイルの存在チェック、ハッシュを用いてを置換後に1個の文字列に変換
    #
    # @param fname [String] eRubyスクリプトファイル
    # @param objx [Hash] eRubyスクリプト置換用ハッシュ
    # @param mes [Messagex] Messagexクラスのインスタンス
    # @return [String] eRubyスクリプトファイルの変換結果
    def self.check_and_expand_file(fname, objx, mes)
      strdata = check_and_load_file(fname, mes)
      mes.output_info("fname=#{fname}")
      mes.output_info("strdata=#{strdata}")
      mes.output_info("objx=#{objx}")
      strdata2 = expand_str(strdata, objx, mes, fname: fname)
      strdata2
    end

    #
    # 最初に現れる「:」と空白文字の組み合わせを区切り文字列として、文字列を２つに分割する
    #
    # @param str [String] 分割対象文字列
    # @return [Array<String>] 第0要素　分割文字列の左側部分、第１要素　分割文字列の右側部分
    def self.colon_space(str)
      if (m = /^(\s*([^\s]+):\s)(.*)$/.match(str))
        left = m[1]
        right = m[3]
      end

      [left, right]
    end

    #
    # 最初に現れる「:」と空白文字以外の文字の組み合わせを区切り文字列として、文字列を２つに分割する
    #
    # @param str [String] 分割対象文字列
    # @return [Array<String>] 第0要素　分割文字列の左側部分、第１要素　分割文字列の右側部分
    def self.colon_not_space(str)
      if (m = /^(\s*([^\s]+):[^\s])(.*)$/.match(str))
        left = m[1]
        right = m[3]
      end

      [left, right]
    end

    #
    # 最初に現れる「:」を区切り文字として、文字列を２つに分割する
    #
    # @param str [String] 分割対象文字列
    # @return [Array<String>] 第0要素　分割文字列の左側部分、第１要素　分割文字列の右側部分
    def self.colon(str)
      if (m = /^(\s*([^\s]+):)(.*)$/.match(str))
        left = m[1]
        right = m[3]
      end

      [left, right]
    end

    #
    # 最初に現れる「-」と空白文字の組み合わせを区切り文字列として、文字列を２つに分割する
    #
    # @param str [String] 分割対象文字列
    # @return [Array<String>] 第0要素　分割文字列の左側部分、第１要素　分割文字列の右側部分
    def self.hyphen_space(str)
      if (m = /^(\s*((\-\s+)+))(.+)$/.match(str))
        left = m[1]
        right = m[4]
      end

      [left, right]
    end

    #
    # YAML形式の文字列に、シングルクォーテーションでのエスケープが必要かを調べる（第1段階）
    #
    # @param line [String] 対象文字列
    # @param state [Hash] 状態
    # @return [Array<String>] 第0要素　分割文字列の左側部分、第１要素　分割文字列の右側部分
    def self.escape_single_quote_yaml_first(line, state)
      # lineに対して": "での分割を試みる
      left, right = colon_space(line)
      state[:mes].output_info("1|left=#{left}")
      left, right = colon(line) unless left
      state[:mes].output_info("2|left=#{left}")

      if right&.index("-")
        left, right = hyphen_space(line)
        state[:mes].output_info("3|left=#{left}")
        if left
          state[:need_quoto] = true
          state[:mes].output_info("NQ|1|need_quoto=#{state[:need_quoto]}")
        end
      end

      unless left
        left, right = hyphen_space(line)
      end

      [left, right]
    end

    #
    # YAML形式の文字列に、シングルクォーテーションでのエスケープが必要かを調べる（第2段階）
    #
    # @param line [String] 対象文字列
    # @param right [String] 対象文字列の分割右側部分
    # @param state [Hash] 状態
    # @option state [Messagex] :mes Messagexクラスのインスタンス
    # @option state [Booleand] :has_quoto true: 対象文字列がエスケープされている false: 対象文字列はエスケープされていない
    # @return [Array<String>] 第0要素　分割文字列の左側部分、第１要素　分割文字列の右側部分
    def self.check_colon_in_right(right, state)
      left3, right3 = colon_not_space(right)
      state[:mes].output_info("52|left3=#{left3}|right3=#{right3}")
      state[:need_quoto] = true
      return [nil, nil] if left3

      left2, right2 = colon(right)
      state[:mes].output_info("53|left2=#{left2}|right2=#{right2}")
      state[:need_quoto] = true
      [left2, right2]
    end

    #
    # YAML形式の文字列に、シングルクォーテーションでのエスケープが必要かを調べる（第2段階）
    #
    # @param line [String] 対象文字列
    # @param state [Hash] 状態
    # @option state [Messagex] :mes Messagexクラスのインスタンス
    # @option state [Booleand] :has_quoto true: 対象文字列がエスケープされている false: 対象文字列はエスケープされていない
    # @param left [String] 対象文字列の分割左側部分
    # @param right [String] 対象文字列の分割右側部分
    # @return [Array<String>] 第0要素　分割された文字列の左側部分、第１要素　分割された文字列の右側部分
    def self.escape_single_quote_yaml_second(line, state, left, right)
      state[:mes].output_info("4|left=#{left}|right=#{right}")

      return [left, right] if right.nil? || right.strip.empty?

      state[:has_quoto] = true if right.index("'")

      return [left, right] if right.index(":").nil?

      return([left, right]) if /\d:/.match?(right)

      left2, right2 = colon_space(right)
      state[:mes].output_info("51|left2=#{left2}|right2=#{right2}")

      unless left2
        left2, right2 = check_colon_in_right(right, state)
      end

      if left2
        left += left2
        right = right2
        state[:mes].output_info("6|left=#{left}|right=#{right}")
      end
      [left, right]
    end

    #
    # YAML形式の文字列に、シングルクォーテーションでのエスケープが必要かを調べる（第3段階）
    #
    # @param line [String] 対象文字列
    # @param state [Hash] 状態
    # @option state [Messagex] :mes Messagexクラスのインスタンス
    # @option state [Booleand] :has_quoto true: 対象文字列がエスケープされている false: 対象文字列はエスケープされていない
    # @param left [String] 対象文字列の分割左側部分
    # @param right [String] 対象文字列の分割右側部分
    # @return [void]
    def self.escape_single_quote_yaml_third(line, state, left, right)
      return if right.nil? || right.strip.empty?

      return if state[:need_quoto]

      return unless right.index(":") && right.index("*")

      state[:mes].output_info("1 not need_quoto")
      unless right.index("-")
        state[:need_quoto] = true
        state[:mes].output_info("NQ|2|need_quoto=#{state[:need_quoto]}")
      end
      state[:mes].output_info("1A need_quoto=#{state[:need_quoto]}")
    end

    #
    # YAML形式の文字列の配列に（必要であれば）シングルクォーテーションでのエスケープを追加
    #
    # @param lines [Array<String>] 対象行の配列
    # @param mes [Messagex] :mes Messagexクラスのインスタンス
    # @return [Array<String>] 必要なエスケープがされた対象文字列
    def self.escape_by_single_quote_with_lines_in_yamlformat(lines, mes)
      state = { mes: mes }
      lines.map do |line|
        state[:need_quoto] = false
        state[:has_quoto] = false

        left, right = escape_single_quote_yaml_first(line, state)
        left, right = escape_single_quote_yaml_second(line, state, left, right)
        if left
          escape_single_quote_yaml_third(line, state, left, right)
        end
        if state[:need_quoto] && !state[:has_quoto]
          state[:mes].output_info("2 need_quoto")
          left + %q(') + right + %q(')
        else
          line
        end
      end
    end
  end
end
