require 'ripper'
require File.join(File.dirname(__FILE__), 'librarian.rb')

module PrintMembers
  module Analyzer
    class Parser < Ripper
      def initialize io, &block
        super io
        @block = block
      end
      
      def on_def(meth, params, body)
        ident, location = meth
        line, column = location
        leading, optional, splat, trailing, keywords, kwsplat, block = params
        kwreq = keywords.to_a.select{|x| !x[1] }
        kwopt = keywords.to_a.select{|x|  x[1] }

        h = {
          :line => line,
          :column => column,
          :ident => ident,
          :leading => leading.to_a.compact.map{|x| x[0].intern },
          :optional => optional.to_a.compact.map{|x| x[0][0].intern },
          :splat => splat && splat[0].intern,
          :trailing => trailing.to_a.compact.map{|x| x[0].intern },
          :kwreq => kwreq.map{|x| x[0][0].intern },
          :kwopt => kwopt.map{|x| x[0][0].intern },
          :kwsplat => kwsplat && kwsplat[0].intern,
          :block => block && block[0].intern,
        }

        @block.call(**h)
      end

      def on_defs context, delim, meth, params, body
        on_def meth, params, body
      end

      def on_params(*args)
        args
      end

      def on_token s
        [s.intern, [lineno, column]]
      end

      # It seems nearly any token can be a method name!
      # We use send here because RDoc doesn't like direct calls
      # to alias_method with anything but symbol literals
      SCANNER_EVENTS.each {|m| send :alias_method, "on_#{m}".intern, :on_token }
    end

    METHODS = {}

    class << self
      def analyze fn
        fn = File.expand_path(fn)
        File.open fn do |io|
          Parser.new io do |meth|
            METHODS[fn] ||= {}
            METHODS[fn][[meth[:line],meth[:ident]]] = meth
          end.parse
        end
      end # def analyze

      def lookup_method opts
        fn = File.expand_path(opts[:filename])
        analyze fn unless METHODS.has_key? fn
        METHODS[fn][[opts[:line],opts[:ident]]] || METHODS[fn][[opts[:line]+1,opts[:ident]]]
      end

      def clear_cache filename=nil
        if filename
          METHODS.delete File.expand_path(filename)
        else
          METHODS.clear
        end
      end
    end
  end # module Analyzer

  module MethodTools

    # If this method was defined in a gem, a 3-tuple of this form is returned:
    #   [:gem,+gem_name+,[+gem_version+]]
    # where
    #  +gem_name+ is the name of the gem as a string e.g. "rake"
    #  +gem_version+ is an integer array of the version components e.g. [2,1,0]
    #
    # If this method was defined in a non-gem library, the following 3-tuple is returned:
    #   [:lib,+lib_name+,nil]
    # where lib_name is the first component of the source file path that is not part of
    # any entry in $LOAD_PATH, stripped of the .rb extension, if it has one.
    #
    # If the source of the method is unknown, +nil+ is returned.
    # This could mean, for example, that the method is built-in, part of a C extension
    # or was defined in an eval call.
    def source_lib
      source_location && Librarian.library_for_path(source_location[0])
    end

    # Returns a Hash mapping the names of the parameters of this method
    # to the string source of their default values. The order of the
    # paramaters in the Hash matches their order in the method.
    # Parameters with no default are mapped to +nil+.
    def params
      
    end

    def pretty_params
      if defn = definition
        a = []
        a += defn[:leading].map{|x| x.to_s }
        a += defn[:optional].map{|x| "#{x}=?" }
        a << "*#{defn[:splat]}" if defn[:splat]
        a += defn[:trailing].map{|x| x.to_s }
        a += defn[:kwreq].map{|x| x.to_s }
        a += defn[:kwopt].map{|x| "#{x}?" }
        a << "**#{defn[:kwsplat]}" if defn[:kwsplat]
        a << "&#{defn[:block]}" if defn[:block]
        a.join(',')
      end
    end

    def definition
      file,line = source_location
      Analyzer.lookup_method :filename => file, :ident => self.name, :line => line if file && File.exist?(file)
    end

    def refresh
      file,line = source_location
      Analyzer.clear_cache file if file
    end

    # Returns one of :public, :private or :protected according to the
    # visibility of this method within its owner, or +nil+ if that
    # is unknown.
    def visibility
      if owner.public_instance_methods.include? name
        :public
      elsif owner.private_instance_methods.include? name
        :private
      elsif owner.protected_instance_methods.include? name
        :protected
      else
        nil
      end
    end

    # Uses dark magic to get the compiled RubyVM::InstructionSequence for the method
    def iseq
      ::ObjectSpace.each_object(::RubyVM::InstructionSequence).find {|iseq|
        iseq.inspect =~ /^<RubyVM::InstructionSequence:#{self.name}@/ }
    end

  end # module MethodTools
end # module PrintMembers

class ::Module
  def source_libs
    (local_methods.map{|m| method(m).source_lib } +
     local_instance_methods.map{|m| instance_method(m).source_lib }
    ).compact.uniq
  end

  def source_files
    (local_methods.map {|m| method(m).source_location.to_a[0] } +
     local_instance_methods.map {|m| instance_method(m).source_location.to_a[0] }
    ).compact.uniq
  end
end

class ::Method
  include PrintMembers::MethodTools
end

class ::UnboundMethod
  include PrintMembers::MethodTools
end
