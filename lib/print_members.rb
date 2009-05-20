load File.join(File.dirname(__FILE__),'print_members/extensions.rb')

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

end

