class Module
  # instance methods from included modules
  def included_methods
    included_modules.map(&:instance_methods).flatten
  end

  # instance methods defined in this module
  def local_instance_methods
    instance_methods - included_methods
  end
end

class Class
  def inherited_instance_methods
    superclass.instance_methods
  end

  def local_instance_methods
    super - inherited_instance_methods
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
        meths.map do |m|
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
      method_list("Class Methods", klass.singleton_methods, CONF[:class_method_color], width, klass.method(:method)) +
      method_list("Instance Methods", klass.local_instance_methods, CONF[:instance_method_color], width, klass.method(:instance_method)) +
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
