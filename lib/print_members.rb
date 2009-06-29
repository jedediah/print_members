
proc do |lib|
  load lib['print_members/extensions.rb']
  load lib['print_members/librarian.rb']
  load lib['print_members/analyzer.rb']
  load lib['print_members/active_record.rb'] if Object.const_defined? :ActiveRecord
end[ proc{|x| File.join(File.dirname(__FILE__),x) } ]



# Objects of this class are essentially strings that contain color information for each character.
# When the object is converted to a string with +to_str+ or +to_s+,
# the colors are rendered as ANSI escape sequences.
# Enough of the String interface is implemented right now to allow this class to be used
# in many places you would normally use strings.
# The color information will survive slicing and other such transformations and will be ignored by
# methods such as +size+ and +length+.
class ColorString

  # Low level module to generate ANSI escape sequences.
  # Usage forms include:
  #   Ansi[1,33,45]                       => "\e[1;33;45m"
  #   Ansi.red                            => "\e[31m"
  #   Ansi.italic_green_on_bright_blue    => "\e[3;32;5;44m"
  #   Ansi.rgb345                         => "\e[38;5;153m"
  #   Ansi.on_grey13                      => "\e[48;5;245m"
  class Ansi
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
        rend.to_s.scan(/(?:on_(?:bright_)?)?[^_]+/).map do |x|
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
        end.join(';')
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

  def initialize str='', col=nil
    if col.nil?
      if str.respond_to? :to_color_string
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

module StringExt
  # Promote a raw String to a ColorString using
  # ColorString::Ansi.decode to interpolate out
  # any ANSI color escape seuences. Unrecognized
  # escape sequences are preserved.
  def to_color_string
    ColorString.decode(self)
  end
end

String.send :include, StringExt    


module PrintMembers

  # This hash contains configuration stuff that you can change.
  # Below are the default values.
  
  unless defined? CONF
    CONF = {
      :terminal_width            => "COLUMNS",   # determine terminal width from environment (can also be a number or nil)
      :indent_size               => 2,
      :color                     => true,        # enable colors
      :class_title_color         => "41;37;1",   # title of a class page
      :module_title_color        => "44;37;1",   # title of a module page
      :heading_color             => "37;1",      # section names
      :class_color               => "31;1",      # classes in ancestry
      :module_color              => "34;1",      # modules in ancestry
      :constant_color            => "31;1",      # member constants
      :class_method_color        => "36;1",      # class methods
      :instance_method_color     => "32;1",      # instance methods
      :singleton_method_color    => "33;1",      # methods of defined only on the singleton class
      :method_param_color        => "37",
      :slash_color               => "34;1",      # misc punctuation
      :arity_color               => "37"         # method arity (number of arguments)
    }
  end

  class Formatter
    def self.format &block
      new.instance_eval &block
    end

    def initialize conf=nil
      @conf = conf || CONF
      @width = if @conf[:terminal_width].is_a? Integer
                 @conf[:terminal_width]
               else
                 ENV[@conf[:terminal_width]].to_i rescue 78
               end
    end

    def cousin conf={}
      self.class.new @conf.merge(conf)
    end

    def color code, str=nil, &block
      str = if block_given?
              instance_eval(&block).to_s
            else
              str
            end

      code = @conf[code] if code.is_a? Symbol

      if @conf[:color]
        ColorString.new str, code
      else
        str
      end
    end

    CONF.each_pair do |k,v|
      define_method(k) {|str=nil, &block| color @conf[k], str, &block } if k =~ /_color$/
    end

    def default_color str=nil, &block
      color '0', str, &block
    end

    def method_missing meth, *args, &block
      super unless clr = ColorString::Ansi.parse_rendition_name(meth)
      color clr, args[0], &block
    end

    def indent n=nil, &block
      n ||= [@conf[:indent_size], @width].min
      old_width = @width
      begin
        @width -= n
        return instance_eval(&block).
               lines.
               map {|l| ColorString.new(' '*n) + l }.
               joincat
      ensure
        @width = old_width
      end
    end

    def title str, &block
      if block_given?
        title(str) + "\n" + instance_eval(&block)
      else
        title_color(" #{str} ")
      end
    end

    def heading str, &block
      res = ColorString.new
      res << " " << heading_color(str) << "\n" if str
      res << indent(&block) if block
      res
    end

    def br
      ColorString.new "\n"
    end

    def nul
      ColorString.new ''
    end

    def columns list
      return '' if list.empty?

      list = list.map {|x| if x.respond_to? :to_str then x else x.to_s end }
      col_width = list.map(&:size).max
      col_width = @width if col_width > @width
      ncols = (@width+1) / (col_width+1)
      nrows = (list.size.to_f/ncols).ceil

      nrows.times.map do |y|
        ncols.times.map do |x|
          i = x*nrows+y
          if i < list.size then list[i].left_fixed(col_width) else '' end
        end.joincat(' ') + "\n"
      end.joincat
    end

    class TableDefinition
      def initialize opts={}, &block
        @opts = opts.dup
        @cells = []
        instance_eval &block if block
      end

      def cells *a
        @cells << a
      end

      def row *a
        raise "mixing columns and rows in table definition" if @opts[:major] == :column
        @opts[:major] = :row
        cells *a
      end

      def column *a
        raise "mixing columns and rows in table definition" if @opts[:major] == :row
        @opts[:major] = :column
        cells *a
      end
      alias_method :col, :column

      def each major=:row, &block
        if block
          if @opts[:major] == major
            @cells.each &block
          else
            @cells.map(&:size).max.times.map {|i| @cells.map {|c| c[i] } }.each &block
          end
        else
          enum_for :each, major
        end
      end

      def rows &block
        each :row, &block
      end

      def columns &block
        each :column, &block
      end

      def method_missing meth, *args, &block
        if @opts[:context]
          @opts[:context].send meth, *args, &block
        else
          super
        end        
      end
    end

    def table opts = {}, &block
      opts = opts.dup
      opts[:column_spacing] ||= 1
      opts[:context] = self
      tab = TableDefinition.new(opts, &block)
      column_widths = tab.columns.map {|col| col.compact.map(&:size).max }

      tab.rows.map do |row|
        row.map_with_index do |cell,i|
          if cell
            cell.left_fixed(column_widths[i])
          else
            default_color ' '*column_widths[i]
          end
        end.joincat(' '*opts[:column_spacing]) + "\n"
      end.joincat
    end

  end # class Formatter

  class << self

    def format &block
      Formatter.format &block
    end

    def format_params meth
      format {
        if (par = meth.pretty_params) && par.size < 12
          slash_color{'('} +
          method_param_color{par} +
          slash_color{')'}
        else
          slash_color{'/'} + arity_color { meth.arity.to_s }
        end
      }
    end

    def format_method_list label, clr, meths
      this = self
      format {
        groups = meths.group_by {|m| m.source_lib }
        groups.keys.sort {|a,b|
          if a.nil?
            -1
          elsif b.nil?
            1
          else
            [b[0],a[1],a[2]] <=> [a[0],b[1],b[2]]
          end
        }.map {|lib|
          br + heading(
            label + if lib.nil?
                      ':'
                    else
                      lib[0] == :gem ? " From #{lib[1]}-#{lib[2].join('.')}:" : " From #{lib[1]}:"
                    end
          ) + indent {
            columns groups[lib].sort {|a,b| a.name <=> b.name }.map {|m|
              color(clr, m.name.to_s) + this.format_params(m)
            }
          }
        }.join
      }
    end

    def constants_of klass, pat=//
      a = klass.send_bypass_singleton(:constants).grep(pat).group_by {|c|
        case klass.send_bypass_singleton :const_get, c
        when Class
          :classes
        when Module
          :modules
        else
          :constants
        end }

      s = format { nul }

      s << format {
        br + heading("Nested Modules and Classes:") {
          columns((a[:modules].to_a.map {|m| module_color m.to_s } +
                   a[:classes].to_a.map {|m| class_color m.to_s }).sort)
        }
      } unless a[:modules].to_a.empty? && a[:classes].to_a.empty?

      s << format {
        br + heading("Constants:") { constant_color { columns a[:constants] } }
      } unless a[:constants].to_a.empty?

      return s
    end

    def class_methods_of klass, pat=//
      a = klass.unboring_methods.grep(pat).map{|m| klass.method m }
      this = self
      format {
        this.format_method_list("Class Methods", :class_method_color, a)
      } unless a.empty?
    end

    def instance_methods_of klass, pat=//
      a = klass.unboring_instance_methods.grep(pat).map {|m| klass.instance_method m }
      this = self
      format {
        this.format_method_list("Instance Methods", :instance_method_color, a)
      } unless a.empty?
    end

    def singleton_methods_of obj, pat=//
      a = obj.singleton_methods.grep(pat).map {|m| obj.method m }
      this = self
      format {
        this.format_method_list("Singleton Methods", :singleton_method_color, a)
      } unless a.empty?
    end

    def ancestors_of klass
      format {
        if klass.is_a? Class
          "\n" + indent {
            table {
              row heading_color("Superclasses    "), heading_color("Included Modules")

              klass.direct_includes.to_a.map {|mod| row '',module_color(mod.to_s) }

              klass.direct_lineage[1..-1].to_a.each {|supa|
                row class_color(supa.to_s), module_color(supa.direct_includes[0].to_s)
                supa.direct_includes[1..-1].to_a.map {|mod|
                  row '',module_color(mod.to_s)
                }
              }
            }
          }
        else
          a = klass.direct_includes.to_a
          heading("Included Modules") {
            a.map {|mod| module_color(mod.to_s) + "\n" }.join
          } unless a.empty?
        end
      }
    end

    def members_of obj, pat=//
      klass,inst = if obj.is_a? Module
                     [obj, nil]
                   else
                     [obj.class, obj]
                   end

      format {
        if klass.is_a? Class
          class_title_color(" #{klass} ")
        else
          module_title_color(" #{klass} ")
        end + br
      } +
      ancestors_of(klass) +
      constants_of(klass, pat) +
      class_methods_of(klass, pat) +
      instance_methods_of(klass, pat) +
      if inst then singleton_methods_of(inst, pat) else '' end
    end

    def pm obj, pat=//
      print members_of(obj, pat)
    end


    def select_modules obj=Object, pat=//
      [obj,*obj.nested_modules.select{|mod| mod != Object && mod != obj }.map{|mod| select_modules mod, pat }].flatten
    end

    def lsmod obj=Object, pat=//
      obj = obj.class unless obj.is_a? Module

      select_modules(obj,pat).select {|mod|
        mod.base_name =~ pat
      }.sort_by(&:name).each {|mod|
        puts format {
          if np = mod.nesting_path
            np.map {|seg|
              if seg.is_a? Class
                class_color { seg.base_name }
              else
                module_color { seg.base_name }
              end
            }.join default_color { '::' }
          end + default_color { "\n" }
        } 
      }
      nil
    end

    def lslib *a
      opts = {}
      pat = //
      obj = nil

      a.each do |x|
        case x
        when Hash
          opts = x
        when Regexp
          pat = x
        else
          obj = x
        end
      end

      print format {
        if obj.nil?
          columns Librarian.libraries(opts).keys.select{|l| l =~ pat }.sort
        else
          if obj.is_a? Module
            obj.source_libs
          else
            obj.class.source_libs
          end.select{|l| l[1] =~ pat }.sort.map {|lib|
            if lib[0] == :gem
              lib[1] + '-' + lib[2].join('.')
            else
              lib[1]
            end + "\n"
          }.join
        end
      }
    end

    def lsrb obj=nil, pat=//
      print format {
        columns( if obj.nil?
                   Librarian.ruby_files
                 elsif obj.is_a? Module
                   obj.source_files
                 else
                   obj.class.source_files
                 end.select {|l| l =~ pat }.sort
        )
      }
    end

    def proto obj, meth
      mo = (obj.respond_to? meth and obj.method meth) or
           (obj.is_a? Module and obj.instance_method_defined? meth and obj.instance_method meth) or
           raise 
    end

    def install
      Object.class_eval do
        def pm pat=//
          ::PrintMembers.pm self, pat
        end

        def lsmod pat=//
          ::PrintMembers.lsmod Object, pat
        end

        def lslib pat=//
          ::PrintMembers.lslib nil, pat
        end

        def lsrb pat=//
          ::PrintMembers.lsrb nil, pat
        end
      end

      Module.class_eval do
        def lsmod pat=//
          ::PrintMembers.lsmod self, pat
        end

        def lslib pat=//
          ::PrintMembers.lslib self, pat
        end

        def lsrb pat=//
          ::PrintMembers.lsrb self, pat
        end
      end
    end # def install
  
  end
end

