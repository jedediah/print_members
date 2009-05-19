class Object
  # Anonymous singleton class of this object
  def singleton_class
    class << self; self; end
  end

  # Eval block in the context of the singleton class
  def singleton_class_eval &block
    self.singleton_class.class_eval &block
  end
end

class Module
  alias_method :instance_method_defined?, :method_defined?

  # Instance methods from included modules
  def included_methods
    included_modules.map(&:instance_methods).flatten
  end

  # True if method +m+ is defined in this module,
  # false if +m+ doesn't exist or was extended from another module or inherited from a superclass
  def method_local? m
    self.respond_to?(m) && self.method(m).owner == self
  end

  # True if instance method +m+ is defined in this module,
  # false if +m+ doesn't exist or is inherited from an ancestor e.g. an included module or superclass
  def instance_method_local? m
    self.method_defined?(m) && self.instance_method(m).owner == self
  end

  # True only if method +m+ exists in this module and is not local
  def method_inherited? m
    self.respond_to?(m) && self.method(m).owner != self
  end

  # True only if instance method +m+ exists in this module and is not local
  def instance_method_inherited? m
    self.method_defined?(m) && self.instance_method(m).owner != self
  end

  # True only if instance method +m+ is local and also exists in an ancestor
  def instance_method_overridden? m
    self.method_defined?(m) && self.instance_method(m).owner == self && self.ancestors[1..-1].any?{|mod| mod.method_defined?(m)}
  end

  # Methods defined in this module (not inherited)
  def local_methods
    self.methods.select{|m| self.method(m).owner == self }
  end

  # Instance methods defined in this module (not inherited)
  def local_instance_methods
    self.instance_methods.select{|m| self.instance_method(m).owner == self }
  end

  # Methods in this module that are not local
  def inherited_methods
    self.methods.select{|m| self.method(m).owner != self }
  end

  # Instance methods in this module that are not local
  def inherited_instance_methods
    self.instance_methods.select{|m| self.instance_method(m).owner != self }
  end

  # Instance methods defined in this module (local) that are also in an ancestor module
  def overridden_instance_methods
    ancestors[1..-1].map(&:instance_methods).flatten.select{|m| self.instance_method_local? m }.uniq
  end

  def grouped_methods
    { :local => self.local_methods,
      :inherited => self.inherited_methods,
      :local_instance => self.local_instance_methods,
      :inherited_instance => self.inherited_instance_methods,
      :overridden_instance => self.overridden_instance_methods }
  end

  # Class and its ancestors (BasicObject, Object, Kernel, Module) are considered
  # "boring" for documentation purposes, because they appear in nearly all other classes/objects.
  # Note that +self+ and its includes are never boring, even if +self+ is in the boring list.
  def boring_classes
    return [Class, *Class.included_modules,
            Module, *Module.included_modules,
            Kernel, *Kernel.included_modules,
            Object, *Object.included_modules,
            BasicObject, *BasicObject.included_modules].uniq
  end

  # Module (and Class) don't consider themselves to be boring.
  def self.boring_classes
    return [Kernel, *Kernel.included_modules,
            Object, *Object.included_modules,
            BasicObject, *BasicObject.included_modules].uniq
  end

  BORING_CLASSES = [BasicObject,Object,Kernel,Module,Class]

  # "Unboring" methods are simply those not inherited from any of the boring classes.
  # Methods become unboring if they are overridden in an unboring class/module.
  # This method returns all of the unboring singleton methods.
  def unboring_methods
    if self.is_a?(self)
      self.local_methods - self.local_instance_methods
    else
      self.local_methods
    end

#     (if self.is_a?(self)
#       self.local_methods - self.local_instance_methods
#     else
#       self.local_methods
#     end + (self.ancestors.uniq -
#            BORING_CLASSES.map{|c| [c,*c.included_modules] } -
#           [self, *self.included_modules]).map{|c| c.local_methods }.flatten).uniq
  end

  # "Unboring" methods are simply those not inherited from any of the boring classes.
  # Methods become unboring if they are overridden in an unboring class/module.
  # This method returns all of the unboring instance methods.
  def unboring_instance_methods
    self.local_instance_methods

#     bc ||= boring_classes
#     instance_methods.select{|m| not bc.include? instance_method(m).owner }
  end
end

module Kernel
  # Kernel finds all the same classes boring as other modules do, except for itself.
  def self.boring_classes
    super - [Kernel, *Kernel.included_modules]
  end
end

class BasicObject
  # BasicObject and Object are very boring classes and thus do not consider any other classes to be boring.
  # No, this does not pollute BasicObject. It already inherits the full suite of class methods from Class.
  def self.boring_classes
    if self == ::BasicObject || self == ::Object
      super - [self, self.included_modules]
    else
      super   # this will resolve to Module#boring_classes
    end
  end
end

class Class
  # True only if method +m+ is defined in this class (local) and is also in the superclass
  def method_overridden? m
    self.method_local?(m) && superclass.respond_to?(m)
  end

  # Methods defined in this class (local) that are also in the superclass
  def overridden_methods
    superclass.methods.select{|m| self.method_local? m }
  end
end

module PrintMembers

  # This hash contains configuration stuff that you can change.
  # Below are the default values.
  #
	#  :terminal_width           => "COLUMNS",  # determine terminal width from environment
  #                                           # (can also be a number)
	#  :color                    => true,       # enable colors
	#  :title_color              => "41;37;1",  # bright white on red
	#  :heading_color            => "37;1",     # bright white
	#  :constant_color           => "31;1",     # bright red
	#  :class_method_color       => "36;1",     # bright cyan
	#  :instance_method_color    => "32;1",     # bright blue
	#  :singleton_method_color   => "33;1",     # bright yellow
	#  :slash_color              => "37;0",     # white
	#  :arity_color              => "37;0"      # white
  
  CONF = {
    :terminal_width            => "COLUMNS",   # determine terminal width from environment (can also be a number or nil)
    :color                     => true,        # enable colors
    :title_color               => "41;37;1",   # bright white on red
    :heading_color             => "37;1",      # bright white
    :constant_color            => "31;1",      # bright red
    :class_method_color        => "36;1",      # bright cyan
    :instance_method_color     => "32;1",      # bright blue
    :singleton_method_color    => "33;1",      # bright yellow
    :slash_color               => "37;0",      # white
    :arity_color               => "37;0"       # white
  }

  private
    def self.change_color code
      if CONF[:color]
        "\e[#{code}m"
      end.to_s
    end

    def self.method_list title, meths, color, width, extract
      unless meths.empty?
        "\n#{change_color CONF[:heading_color]} #{title}:#{change_color '0'}\n" +
        meths.sort.map do |m|
          arity = extract[m].arity if extract
           [change_color(color) + m.to_s + (change_color(CONF[:slash_color]) + '/' + change_color(CONF[:arity_color]) + arity.to_s if extract).to_s,
            (m.to_s + ('/'+arity.to_s if extract).to_s).size]
        end.columnize(width).map{|l| "  #{l}\n"}.join
      end.to_s
    end

  public

  # Extend Object with convenience method +pm+
  def self.install
    Object.class_eval do
      def pm x=nil
        print ::PrintMembers[x || self]
      end
    end
  end

  DELIMS = {
    "do"            => "end",
    "begin"         => "end",
    "def"           => "end",
    "class"         => "end",
    "module"        => "end",
    "if"            => "end",
    "unless"        => "end",
    "while"         => "end",
    "until"         => "end"
  }

  DELIM_OPEN = /\b(do|begin|def|class|module|if|unless|while|until)\b/
  DELIM_CLOSE = /\bend\b/
  DELIM = /\b(do|begin|def|class|module|if|unless|while|until|end)\b/

  def self.src obj, mem
    meth = (obj.method(mem) rescue obj.instance_method(mem) rescue obj.singleton_method(mem) rescue nil)

    if meth.nil?
      if obj.const_defined? mem
        raise "const source not supported yet"
      else
        raise "unknown member"
      end
    end

    pathname, lineno = meth.source_location
    
    if pathname && File.exist?(pathname)
      File.open pathname, "r" do |io|
        io.lines.take lineno-1
        ss = StringScanner.new io.read

        parse_block = lambda do
          puts "*** parsing block"
          ss.scan_until DELIM
          if !ss.matched? || ss[0] == "end" || ss[0] == "}"
            puts "!!! no open delim"
            return nil
          end

          puts "*** found open delim #{ss.matched}"

          loop do
            ss.scan_until DELIM

            unless ss.matched?
              puts "!!! no delims left and block still open"
              return nil
            end

            if ss[0] == "end" || ss[0] == "}"
              puts "*** found close delim #{ss.matched}"
              return true
            end

            ss.pos -= ss.matched_size
            return nil unless parse_block[]
          end
        end

        parse_block[]
        
        if ss.matched?
          return ss.pre_match + ss.matched + "\n"
        else
          return ss.string
        end
      end
    else
      return "can't locate source for #{obj}.#{mem}\n"
    end
  end

  # Generate a pretty list of member methods/constants
  def self.[] obj
    width = CONF[:terminal_width]
    width = if width.is_a? String
              ENV[width].to_i - 2 rescue 78
            elsif width.is_a? Fixnum
              width
            else
              78
            end

    klass,inst = if obj.is_a? Module
                   [obj, nil]
                 else
                   [obj.class, obj]
                 end

    "#{change_color CONF[:title_color]} #{klass} #{change_color '0'}\n" +
      method_list("Constants", klass.constants, CONF[:constant_color], width, nil) +
      method_list("Class Methods", klass.unboring_methods, CONF[:class_method_color], width, klass.method(:method)) +
      method_list("Instance Methods", klass.unboring_instance_methods, CONF[:instance_method_color], width, klass.method(:instance_method)) +
      (inst and method_list("Singleton Methods", inst.singleton_methods, CONF[:singleton_method_color], width, inst.method(:method))).to_s
  end

  module Ext
    module Array
      # Arrange strings into equal width columns.
      # Each item can either be a string or an array of the form [string,length] to override the length of the item.
      # Overriding the length is useful if the string contains non-printing characters.
      # The column width will be the length of the longest item or +width+, whichever is less.
      # Columns will be +spacing+ characters apart.
      # An array of rows is returned.
      def columnize width, spacing=1
        return [] if empty?
        column_width = 0
        items_sizes = map{|x| if x.is_a? Array
                              column_width = x[1] if x[1] > column_width
                              x
                            else
                              column_width = x.size if x.size > column_width
                              [x,x.size]
                            end }
        column_width = width if column_width > width
        ncolumns = (width+spacing) / (column_width+spacing)
        items_sizes.map{|x| x[0] + " "*(column_width-x[1]) }.each_slice(ncolumns).map{|row| row.join(' '*spacing)}
      end
    end
  end

end

class Array
  include PrintMembers::Ext::Array
end

# PrintMembers.install
