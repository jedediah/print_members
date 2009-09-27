module PrintMembers

  # Low level module to generate ANSI escape sequences.
  # Usage forms include:
  #   Ansi[1,33,45]                       => "\e[1;33;45m"
  #   Ansi.red                            => "\e[31m"
  #   Ansi.italic_green_on_bright_blue    => "\e[3;32;5;44m"
  #   Ansi.rgb345                         => "\e[38;5;153m"
  #   Ansi.on_grey13                      => "\e[48;5;245m"
  module Ansi
    RENDITION = {
      normal:'0',
      reset:'0',
      bright:'1',
      italic:'3',
      italics:'3',
      underline:'4',
      underlined:'4',
      blink:'5',
      blinking:'5',
      on_bright:'5',
      inverse:'7',
      inverted:'7',
      negative:'7',

      non_bright:'22',
      dim:'22',
      no_underline:'24',
      non_underlined:'24',
      no_blink:'25',
      non_blinking:'25',
      non_on_bright:'25',
      on_dim:'25',
      no_inverse:'27',
      non_inverted:'27',
      positive:'27',

      black:'30',
      red:'31',
      green:'32',
      yellow:'33',
      blue:'34',
      magenta:'35',
      cyan:'36',
      white:'37',

      on_black:'40',
      on_red:'41',
      on_green:'42',
      on_yellow:'43',
      on_blue:'44',
      on_magenta:'45',
      on_cyan:'46',
      on_white:'47',

      on_bright_black:'5;40',
      on_bright_red:'5;41',
      on_bright_green:'5;42',
      on_bright_yellow:'5;43',
      on_bright_blue:'5;44',
      on_bright_magenta:'5;45',
      on_bright_cyan:'5;46',
      on_bright_white:'5;47'
    }

    class << self
      def format_rendition *r
        r.join(';')
      end

      def format_sequence *r
        "\e[#{format_rendition r}m"
      end
      alias_method :[], :format_sequence

      def parse_rendition s
        a = s.sub(/^\e\[([0-9;]*)m$/,'\1').split(/;/).select{|x| x =~ /^[0-9]+$/}.map(&:to_i)
        a.sort! unless a[1] == 5 && a[0] == 38 || a[0] == 48
        return a
      end
      alias_method :parse_sequence, :parse_rendition

      def parse_rendition_name rend
        ['0',*rend.to_s.scan(/(?:on_(?:bright_)?)?[^_]+/).map do |x|
            if x =~ /^rgb(\d)(\d)(\d)$/
              "38;5;" + (16 + $1.to_i*36 + $2.to_i*6 + $3.to_i).to_s
            elsif x =~ /^grey(\d\d?)/
              "38;5;" + (232 + $1.to_i).to_s
            elsif x =~ /^on_rgb(\d)(\d)(\d)$/
              "48;5;" + (16 + $1.to_i*36 + $2.to_i*6 + $3.to_i).to_s
            elsif x =~ /^on_grey(\d\d?)/
              "48;5;" + (232 + $1.to_i).to_s
            else
              RENDITION[x.intern]
            end.to_s
          end].join(';')
      end

      def method_missing meth, *args, &block
        super unless ansi = parse_rendition_name(meth)
        "\e[#{ansi}m"
      end

      def decode encoded
        colors = []
        current = [0]
        pos = 0

        string = encoded.gsub /\e\[[0-9;]*m/ do |m|
          seq_begin = $~.begin(0)
          seq_end =  $~.end(0)
          rend = parse_rendition($&)
          colors += Array.new(seq_begin - pos, current.join(';'))
          current = rend
          pos = seq_end
          ''
        end

        colors += Array.new(encoded.size - pos, current.join(';'))
        return [string, colors]
      end

      def encode string, colors
        encoded = ''
        pos = 0
        cur_clr = nil
        colors.run_length_encode do |clr,len|
          encoded << "\e[#{clr}m" << string[pos,len]
          pos += len
          cur_clr = clr
        end
        encoded << "\e[0m" unless cur_clr =~ /^0+$/
        return encoded
      end

    end # class << self
  end # class Ansi

  # Objects of this class are essentially strings that contain color information for each character.
  # When the object is converted to a string with +to_str+ or +to_s+,
  # the colors are rendered as ANSI escape sequences.
  # Enough of the String interface is implemented right now to allow this class to be used
  # in many places you would normally use strings.
  # The color information will survive slicing and other such transformations and will be ignored by
  # methods such as +size+ and +length+.
  class ColorString
    def initialize str='', col=nil
      if col.nil?
        if !str.is_a?(ColorString) && str.respond_to?(:to_color_string)
          str = str.to_color_string
        else
          str = str.to_str.to_color_string
        end

        @string = str.string.dup
        @colors = str.colors.dup
      else
        if str.respond_to? :to_color_string
          # re-coloring a ColorString
          # check for ColorString first to avoid inf recurse
          if str.is_a? ColorString
            str = str.string.dup
          else
            str = str.to_color_string.string.dup
          end
        elsif str.respond_to? :to_str
          str = str.to_str.dup
        else
          raise ArgumentError.new "first argument must be a string, not a #{str.class}"
        end

        @string = str
        @colors = if col.is_a? Array
                    col.map{|x| x||'0' }.pad @string.size, '0'
                  else
                    Array.new(@string.size, col||'0')
                  end
      end
    end

    # Decode any ANSI color escape sequences in a raw
    # string and create a ColorString. +new+ does this
    # as well.
    def self.decode str
      allocate.instance_exec(str) {|str|
        @string,@colors = Ansi.decode(str.to_str)
        self
      }
    end

    attr_reader :colors
    attr_reader :string

    def to_str
      Ansi.encode @string, @colors
    end

    def to_s
      # self defines to_str thus qualifies as a string to be returned from to_s
      # self
      to_str
    end

    def to_color_string
      self
    end

    include Comparable

    def <=> x
      if x.is_a? self.class
        @string <=> x.string
      else
        @string <=> x.to_str
      end
    end

    def size
      @string.length
    end
    alias_method :length, :size

    def slice *args
      self.class.new @string.slice(*args), @colors.slice(*args)
    end
    alias_method :[], :slice

    def ljust! n, pad=' ', padcolor='0'
      if n > size
        @string = @string.ljust(n, pad)
        @colors.pad! n, padcolor
      end
      self
    end

    def ljust n, pad=' ', padcolor='0'
      dup.ljust! n, pad, padcolor
    end

    def left_fixed n, pad=' ', padcolor='0'
      if n > size
        ljust n, pad, padcolor
      else
        slice 0...n
      end
    end

    def dup
      ColorString.new @string, @colors
    end

    def concat str
      if str.respond_to? :to_color_string
        str = str.to_color_string
        @string += str.string
        @colors += str.colors
      elsif str.respond_to? :to_str
        @string += str.to_str
        @colors.pad! @string.size, '0'
      end
      self
    end
    alias_method :<<, :concat

    def + str
      dup.concat str
    end

    def lines
      if block_given?
        @string.scan /^.*\r?\n|^.+$/ do |line|
          yield ColorString.new line, @colors[$~.begin(0),line.size]
        end
      else
        enum_for :lines
      end
    end
    alias_method :each_line, :lines

    def chars
      if block_given?
        @string.chars.each_with_index do |c,i|
          yield ColorString.new c, @colors[i]
        end
      else
        enum_for :chars
      end
    end
    alias_method :each_char, :chars

    def method_missing meth, *args, &block
      @string.send meth, *args, &block
    end

  end # ColorString

  module Ext
    module String
      # Promote a raw String to a ColorString using
      # ColorString::Ansi.decode to interpolate out
      # any ANSI color escape seuences. Unrecognized
      # escape sequences are preserved.
      def to_color_string
        ColorString.decode(self)
      end
    end
  end

  String.send :include, Ext::String
end # PrintMembers
