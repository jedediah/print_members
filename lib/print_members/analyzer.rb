require 'ripper'

module PrintMembers
  module Analyzer
    class Parser < Ripper
      def initialize io, &block
        super io
        @block = block
      end
      
      def on_def meth, params, body
        # puts "#{lineno}, #{column}: on_def #{[meth,params,body].inspect}"
        @block.call :line => meth[1][0],
                    :column => meth[1][1],
                    :ident => meth[0],
                    :leading => params[0],
                    :optional => params[1],
                    :splat => params[2],
                    :trailing => params[3],
                    :block => params[4],
                    :params => (params[0]+params[1].map{|x| x[0]}+[params[2]]+params[3]+[params[4]]).compact
      end

      def on_defs context, delim, meth, params, body
        # puts "#{lineno}, #{column}: on_defs #{a.inspect}"
        on_def meth, params, body
      end

      def on_params leading, optional, splat, trailing, block
        return [ leading.to_a.compact.map {|x| x[0].intern },
                 optional.to_a.compact.map {|x| [x[0][0].intern, x[1]] },
                 splat && splat[0].intern,
                 trailing.to_a.compact.map {|x| x[0].intern },
                 block && block[0].intern ]
      end

      def on_ident s
        [s.intern, [lineno, column]]
      end

      def on_op s
        on_ident s
      end
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
      return nil unless source_location && defined? Gem
      src = source_location[0]
      rsep = Regexp.escape(File::SEPARATOR)

      if path = Gem.path.find {|p| src.start_with? p }
        rpath = Regexp.escape(path)
        src =~ /^#{rpath}#{rsep}gems#{rsep}([^#{rsep}]+)-([0-9\.]+)/
        [:gem,$1,$2.split(/\./).map(&:to_i)]
      elsif !(path = $LOAD_PATH.select {|p| src.start_with? p }).empty?
        rpath = Regexp.escape(path.max(&:size))
        src =~ /^#{rpath}#{rsep}([^#{rsep}]+)/
        [:lib,$1,nil]
      end
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
        a += defn[:optional].map{|x| "#{x[0]}=?" }
        a << "*#{defn[:splat]}" if defn[:splat]
        a += defn[:trailing].map{|x| x.to_s }
        a << "&#{defn[:block]}" if defn[:block]
        return a.join(',')
      end
    end

    def definition
      file,line = source_location
      Analyzer.lookup_method :filename => file, :ident => self.name, :line => line if file
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

  end # module MethodTools
end # module PrintMembers

class Method
  include PrintMembers::MethodTools
end

class UnboundMethod
  include PrintMembers::MethodTools
end
