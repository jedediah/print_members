%w{extensions ansi librarian analyzer method}.each do |lib|
  require File.join(File.dirname(__FILE__),'print_members',lib) + '.rb'
end

module PrintMembers

  # This hash contains configuration stuff that you can change.
  # Below are the default values. You should copy this to your
  # file and mess with it there. Be sure to put it in the
  # PrintMembers namespace.
  #unless defined? CONF
    CONF = {
      :terminal_width            => nil,                       # terminal width in columns or the name of an environment variable
                                                               # or nil to try to detect width using ENV['COLUMNS'] then terminfo gem
      :indent_size               => 2,
      :color                     => true,                      # enable colors
    
      :class_title_color         => "41;37;1",                 # title of a class page
      :module_title_color        => "44;37;1",                 # title of a module page
      :heading_color             => "37;1",                    # section names
      :class_color               => "31;1",                    # classes in ancestry
      :module_color              => "34;1",                    # modules in ancestry
      :constant_color            => "31;1",                    # member constants
      :class_method_color        => "36;1",                    # class methods
      :instance_method_color     => "32;1",                    # instance methods
      :singleton_method_color    => "33;1",                    # methods of defined only on the singleton class
      :method_param_color        => "37",                     
      :slash_color               => "34;1",                    # misc punctuation
      :arity_color               => "37",                      # method arity (number of arguments)
      :file_name_color           => "1;33",
      :line_number_color         => "1;36",
      :error_color               => "31"
    }
  #end

  
  class Formatter
    class FallbackContext < BasicObject
      class << self
        private :new
        def evaluate primary, *args, &block
          send(:new, primary, block.binding.eval('self')).instance_exec *args, &block
        end

        def const_missing c
          ::Object.const_get c
        end
      end

      def initialize primary, fallback
        @primary = primary
        @fallback = fallback
      end

      def method_missing meth, *args, &block
        begin
          @primary.send meth, *args, &block
        rescue ::NoMethodError => ex
          ::Kernel.raise unless ex.name.intern == meth
          begin
            @fallback.send ex.name, *args, &block
          rescue ::NoMethodError => ex
            ::Kernel.raise unless ex.name.intern == meth
            ::Kernel.raise ex.exception "Method '#{meth}' was not found in either " \
                                        "#{@primary.inspect[0..20]} or #{@fallback.inspect[0..20]}"
          end
        end
      end
    end

    def self.format &block
      #new.instance_exec &block
      FallbackContext.evaluate new, &block
    end

    def initialize conf={}
      @conf = CONF.merge conf
      tw = @conf[:terminal_width]
      @width = if tw.respond_to? :to_int
                 tw
               elsif tw.respond_to? :to_str
                 ENV[tw].to_i
               else
                 ENV['COLUMNS'].to_i
               end
      begin
        require 'terminfo'
        @width = TermInfo.screen_width
      rescue LoadError
        @width = 78
      end unless @width.to_i > 0
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
      super unless clr = Ansi.parse_rendition_name(meth)
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
      list = list.to_a
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

  end # Formatter

  class << self

    def format_unsafe &block
      Formatter.format &block
    end

    def format_safe &block
      format_unsafe &block
    rescue => ex
      format_unsafe { error_color { "[#{ex.class} during introspection: #{ex.message}]" } }
      raise
    end

    def format_params meth
      format_safe {
        if (par = meth.pretty_params) # && par.size < 12
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
      format_safe {
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

    def format_module_list mods
      format_safe {
        columns mods.map {|m|
          if m.is_a? Class
            class_color m.to_s
          else
            module_color m.to_s
          end
        }
      }
    end

    def constants_of klass, pat=//
      a = klass.send_bypass_singleton(:constants).grep(pat).group_by {|c|
        case klass.send_bypass_singleton :safe_const_get, c
        when Class
          :classes
        when Module
          :modules
        else
          :constants
        end }

      s = format_safe { nul }

      s << format_safe {
        br + heading("Nested Modules and Classes:") {
          columns((a[:modules].to_a.map {|m| module_color m.to_s } +
                   a[:classes].to_a.map {|m| class_color m.to_s }).sort)
        }
      } unless a[:modules].to_a.empty? && a[:classes].to_a.empty?

      s << format_safe {
        br + heading("Constants:") { constant_color { columns a[:constants] } }
      } unless a[:constants].to_a.empty?

      return s
    end

    def class_methods_of klass, pat=//
      a = klass.unboring_methods.grep(pat).map{|m| klass.safe_method m }.compact
      format_method_list("Class Methods", :class_method_color, a) unless a.empty?
    end

    def instance_methods_of klass, pat=//
      a = klass.unboring_instance_methods.grep(pat).map {|m| klass.safe_instance_method m }.compact
      a << klass.instance_method(:initialize) if klass.private_method_defined? :initialize
      format_method_list("Instance Methods", :instance_method_color, a) unless a.empty?
    end

    def singleton_methods_of obj, pat=//
      a = obj.singleton_methods.grep(pat).map {|m| obj.safe_method m }.compact
      this = self
      format_safe {
        this.format_method_list("Singleton Methods", :singleton_method_color, a)
      } unless a.empty?
    end

    def instance_variables_of obj, pat=//
      a = Hash[*obj.instance_variables.grep(pat).map {|v| [v, obj.instance_variable_get(v)] }.flatten]
      # TODO
    end

    def ancestors_of klass
      format_safe {
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

    def descendants_of klass
      unless Object <= klass
        if klass.is_a? Class
          a = klass.subclasses
          h = "Subclasses"
        else
          a = klass.including_modules
          h = "Included By"
        end

        a = a.to_a
        this = self
        
        format_safe do
          br + heading(h) {
            this.format_module_list a
          }
        end unless a.empty?
      end
    end
    
    def members_of obj, pat=//
      klass,inst = if obj.is_a? Module
                     [obj, nil]
                   else
                     [obj.class, obj]
                   end

      format_safe {
        if klass.is_a? Class
          class_title_color(" #{klass} ")
        else
          module_title_color(" #{klass} ")
        end + br
      } +
      ancestors_of(klass) +
      descendants_of(klass) +
      constants_of(klass, pat) +
      class_methods_of(klass, pat) +
      instance_methods_of(klass, pat) +
      if inst then singleton_methods_of(inst, pat) else '' end
    end


    def select_modules obj=Object, pat=//
      [ obj,
        *obj.nested_modules.select { |mod|
          mod != Object && mod != obj
        }.map { |mod|
          select_modules mod, pat
        }
      ].flatten
    end
    
    def print_members obj, pat=//
      print members_of(obj, pat)
    end

    def resolve_method obj, meth
      if obj.respond_to?(:call)
        return obj
      elsif meth.respond_to? :call
        return meth
      elsif meth
        if (obj.respond_to?(:private_method_defined?) && obj.private_method_defined?(meth)) ||
           (obj.respond_to?(:instance_method_defined?) && obj.instance_method_defined?(meth))
          return obj.instance_method meth
        elsif obj.singleton_method_defined?(meth) ||
              obj.singleton_class.private_method_defined?(meth)
          return obj.method meth
        end
      end
      raise NoMethodError.new "Can't find a method called `#{meth}' for object #{obj.inspect}"
    end

    def print_source obj, meth, opts={}
      m = resolve_method obj, meth
      file,line = m.source_location
      if file
        print format_unsafe {
          "#{line_number_color line.to_s} #{file_name_color file}\n\n" +
          indent { MethodPrinter.get_method m, opts } + "\n\n"
        }
      else
        puts  "Sorry, I can't find the source for `#{meth}'. If this bothers you, please\n" \
              "encourage the Ruby core team to implement source_location more thoroughly.\n"
      end
    end
    
    def list_modules obj=Object, pat=//
      obj = obj.class unless obj.is_a? Module

      select_modules(obj,pat).select {|mod|
        mod.base_name =~ pat
      }.sort_by(&:name).each {|mod|
        puts format_unsafe {
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

    def list_libraries *a
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

      print format_unsafe {
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

    def list_sources obj=nil, pat=//
      print format_unsafe {
        columns( if obj.nil?
                   Librarian.ruby_files
                 elsif obj.respond_to? :source_files
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

    module ModuleCommands
      def lsmod pat=//
        PrintMembers.list_modules self, pat
      end

      def lslib pat=//
        PrintMembers.list_libraries self, pat
      end

      def lsrb pat=//
        PrintMembers.list_sources self, pat
      end
    end
      
    module ObjectCommands
      def pm pat=//
        PrintMembers.print_members self, pat
      end

      def ps meth, opts={}
        PrintMembers.print_source self, meth, opts
      end

      def lsmod pat=//
        PrintMembers.list_modules Object, pat
      end

      def lslib pat=//
        PrintMembers.list_libraries nil, pat
      end

      def lsrb pat=//
        PrintMembers.list_sources nil, pat
      end
    end

    module MethodCommands
      def ps opts={}
        PrintMembers.print_source self, opts
      end
    end
      
    def install
      Module.send :include, ModuleCommands
      Object.send :include, ObjectCommands
      [Method,UnboundMethod].each{|m| m.send :include, MethodCommands }
      true
    end
  
  end # << self
end # PrintMembers

