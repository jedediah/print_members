require 'ripper'

module PrintMembers
  module Ext
    module IO
      # zero-based
      def goto_line line
        if lineno < line
          (line-lineno).times { gets }
        elsif lineno > line
          rewind
          line.times { gets }
        end
      end # goto_line
    end # IO
  end # Ext

  IO.send :include, Ext::IO

  class MethodPrinter < Ripper
    # Set colors in print_members.rb
    TOKEN_COLORS = Hash.new Ansi.bright_white

    TOKEN_GROUP_MAP = {
      :CHAR            => :string,
      :backtick        => :string,
      :tstring_beg     => :string,
      :tstring_content => :string,
      :tstring_end     => :string,
      :words_beg       => :string,
      :words_sep       => :string,
      :heredoc_beg     => :string,
      :heredoc_end     => :string,
      :qwords_beg      => :string,

      :regexp_beg      => :regexp,
      :regexp_end      => :regexp,

      :symbeg          => :symbol,

      :float           => :number,
      :int             => :number,

      :const           => :constant,

      :comment         => :comment,
      :embdoc          => :comment,
      :embdoc_beg      => :comment,
      :embdoc_end      => :comment,

      :ident           => :identifier,
      :label           => :identifier,

      :kw              => :keyword,

      :cvar            => :variable,
      :gvar            => :variable,
      :ivar            => :variable,
      :embvar          => :variable,

      :ignored_nl      => :whitespace,
      :sp              => :whitespace,
      :nl              => :whitespace,

      :op              => :operator,
      :period          => :operator,
      :tlambda         => :operator,

      :comma           => :punctuation,
      :semicolon       => :punctuation,
      :rbrace          => :punctuation,
      :lbrace          => :punctuation,
      :rbracket        => :punctuation,
      :lbracket        => :punctuation,
      :rparen          => :punctuation,
      :lparen          => :punctuation,
      :embexpr_beg     => :punctuation,
      :embexpr_end     => :punctuation,
      :tlambeg         => :punctuation
    }

    TOKEN_GROUP_MAP.each do |token,group|
      TOKEN_COLORS[token] = SOURCE_COLORS[group] unless TOKEN_COLORS.key? token
    end if defined? SOURCE_COLORS

    def self.parse_method meth, opts={}
      if (sl = meth.source_location) && File.exist?(sl[0])
        File.open sl[0] do |io|
          parse_method_at io, sl[1]
        end
      end
    end

    def self.parse_method_at io, line, opts={}
      io.goto_line line-1
      md = new io, nil, line, opts
      catch :def do
        md.parse
        return nil
      end
    end

    DEFAULT_OPTIONS = {:color => true}

    def initialize src, file, line, opts={}
      super src, file, line
      @options = DEFAULT_OPTIONS.merge opts
      @source = []
      @tstring_host = []
      @last_token = nil
      #self.yydebug = true
    end

    def finish
      throw :def, @source.sort{|a,b| a[0] <=> b[0] }.map{|x| x[1]}.join
    end
    
    def on_def id,params,body
      finish
    end

    def on_defs obj,op,id,params,body
      finish
    end

    def colorize token, src
      if @options[:color]
        "#{TOKEN_COLORS[token]}#{src}"
      else
        src
      end
    end

    def on_scanner_event token, src
      # p [[lineno,column],@tstring_host,token,src]
      t = if @last_token == :symbeg
            :symbeg
          else
            token
          end

      @source << [[lineno,column],colorize(t, src)]
      @last_token = token
    end

    SCANNER_EVENTS.each do |token|
      define_method("on_#{token}") {|src| on_scanner_event token, src }
    end

    def on_tstring_content x
      on_scanner_event @tstring_host.last, x
    end
    alias on_tstring_end on_tstring_content

    [:symbeg,:regexp_beg,:backtick,:tstring_beg,:words_beg,:qwords_beg,:heredoc_beg].each do |token|
      define_method "on_#{token}" do |x|
        @tstring_host << token
        on_scanner_event token, x
      end
    end

    [:symbol_literal,:dyna_symbol,:regexp_literal,:xstring_literal,:string_literal].each do |symbol|
      define_method "on_#{symbol}" do |*a|
        @last_token = symbol
        @tstring_host.pop
      end
    end
  end # MethodPrinter
end # PrintMembers
