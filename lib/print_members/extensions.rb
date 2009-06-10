
module Enumerable
  class << self
    def mash
      reduce({}) {|h,x| kv = yield x
                        h[kv[0]] = kv[1] if kv.respond_to? :[]
                        h }
    end
  end

  # Generate a run-length encoded representation of +self+.
  # Returns an enumeration of the form [ [elem,length], [elem,length], ... ]
  # where each [elem,length] pair represents a run of +elem+ repeated +length+ times.
  # If the returned sequence is expanded according to this scheme, it will be identical to +self+.
  def run_length_encode
    elem = nil
    len = 0

    if block_given?
      each do |x|
        if elem == x
          len += 1
        else
          yield elem, len if len != 0
          elem = x
          len = 1
        end
      end
      yield elem, len if len != 0
    else
      enum_for :run_length_encode
    end
  end # def run_length_encode
end # module Enumerable

module PrintMembers

  def self.tester leading1, leading2, optional3='abc', optional4=:default4, *splat5, trailing6, trailing7, &block8
  end

  module Ext

    module String
      # Return a string of length +n+, containing +self+ left-justified
      # and either padded with +pad+ or truncated, depending on its size relative to +n+.
      def left_fixed n, pad=' '
        if n > size
          ljust n, pad
        else
          slice 0...n
        end
      end

      # Create a ColorString from this String
      def to_color_string
        ::PrintMembers::ColorString.new self
      end
    end


    module MethodTools
=begin
      class MethodRipper < Ripper
        def self.parse io, line, meth
          rip = new io, meth
          if line == 1
            catch(:ok) { rip.parse; nil }
          else
            io.lines.take line-2
            prev = io.pos
            io.gets
            catch(:ok) { rip.parse; nil } or catch(:ok) { io.pos = prev; rip.parse; nil }
          end and rip or nil
        end

        def initialize io, meth
          super io
          @name = meth.intern
          @params = {}
        end

        PARSER_EVENTS.each {|meth| define_method("on_#{meth}") {|*a| puts "#{meth} #{a.inspect}"; return [meth,*a] } }
        SCANNER_EVENTS.each {|meth| define_method("on_#{meth}") {|t| puts "@#{meth} #{t.inspect}"; return ["@#{meth}".intern, t] } }

        def on_ident s
          s.intern
        end

        def on_defs base, delim, meth, dunno1, dunno2
          puts "on_defs #{base.inspect} #{delim.inspect} #{meth.inspect} #{dunno1.inspect} #{dunno2.inspect}"
          throw :ok, @name == meth.intern
        end

        def on_def meth, dunno1, dunno2
          puts "on_def #{meth.inspect} #{dunno1.inspect} #{dunno2.inspect}"
          throw :ok, @name == meth.intern
        end

        def on_params leading, optional, splat, trailing, block
          puts "on_params #{leading.inspect}, #{optional.inspect}, #{splat.inspect}, #{trailing.inspect}, #{block.inspect}"
          @params = { :leading => leading,
                      :optional => optional.reduce({}) {|h,(k,v)| h[k] = v; h },
                      :splat => splat,
                      :trailing => trailing,
                      :block => block,
                      :all => leading + optional.map(&:first) + splat + trailing + block }
        end

        attr_reader :name, :leading, :optional, :splat, :trailing, :block

      end # class MethodRipper
=end


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
      def parameters
        file,line = source_location
        if file
          File.open file, "r" do |io|
            MethodRipper.parse io, line, self.name
          end
        end
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

    module Method
      include MethodTools
    end

    module UnboundMethod
      include MethodTools
    end

    module Object
      # Anonymous singleton class of this object
      def singleton_class
        class << self; self; end
      end

      # Eval block in the context of the singleton class
      def singleton_class_eval &block
        self.singleton_class.class_eval &block
      end

      # Make the 
      def copy_singleton_methods obj
      end
    end

    module Module
      def instance_method_defined? x; method_defined? x; end

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
        return [::Class, *::Class.included_modules,
                ::Module, *::Module.included_modules,
                ::Kernel, *::Kernel.included_modules,
                ::Object, *::Object.included_modules,
                ::BasicObject, *::BasicObject.included_modules].uniq
      end

      # Module (and Class) don't consider themselves to be boring.
      def self.boring_classes
        return [::Kernel, *::Kernel.included_modules,
                ::Object, *::Object.included_modules,
                ::BasicObject, *::BasicObject.included_modules].uniq
      end

      # "Unboring" methods are simply those not inherited from any of the boring classes.
      # Methods become unboring if they are overridden in an unboring class/module.
      # This method returns all of the unboring singleton methods.
      def unboring_methods
        if [::Class,::Module].include? self
          # Only those instance methods that we have not by virtue of being an instance of ourself
          self.methods - (self.instance_methods - self.singleton_methods)
        elsif self.is_a? ::Class
          # Only those instance methods that we have not by virtue of being a Class, unless we have overridden them
          self.methods - (::Class.instance_methods - self.singleton_methods)
        else
          # Only those instance methods that we have not by virtue of being a Module, unless we have overridden them
          self.methods - (::Module.instance_methods - self.singleton_methods)
        end
      end

      # "Unboring" methods are simply those not inherited from any of the boring classes.
      # Methods become unboring if they are overridden in an unboring class/module.
      # This method returns all of the unboring instance methods.
      def unboring_instance_methods
        if [::BasicObject,::Object,::Kernel].include? self
          self.instance_methods
        # elsif [Class,Module].include? self
        #  self.instance_methods - Object.instance_methods
        else
          self.instance_methods - (::Object.instance_methods - self.local_instance_methods)
        end
      end

      def method_owner m
        method(m).owner
      end

      def method_gem m
        method(m).source_gem
      end

      def method_location m
        mm = method(m)
        [mm.owner,mm.source_gem]
      end

      def method_owners
        methods.mash {|m| [m, method(m).owner] }
      end

      def method_gems
        methods.mash {|m| [m, method(m).source_gem] }
      end

      def method_locations
        methods.mash {|m| mm = method(m); [m, [mm.owner, mm.source_gem]] }
      end

      def instance_method_owner m
        instance_method(m).owner
      end

      def instance_method_gem m
        instance_method(m).source_gem
      end

      def instance_method_location m
        mm = instance_method(m)
        [mm.owner,mm.source_gem]
      end

      def instance_method_owners
        instance_methods.mash {|m| [m, instance_method(m).owner] }
      end

      def instance_method_gems
        instance_methods.mash {|m| [m, instance_method(m).source_gem] }
      end

      def instance_method_locations
        instance_methods.mash {|m| mm = instance_method(m); [m, [mm.owner, mm.source_gem]] }
      end

      def indirect_ancestors
        ancestors[1..-1].to_a.map{|x| x.ancestors[1..-1].to_a }.flatten
      end

      def direct_ancestors
        ancestors[1..-1] - indirect_ancestors
      end

      def direct_includes
        direct_ancestors.reject {|x| x.is_a? Class }
      end


      def family_tree
        [self,direct_ancestors.map(&:family_tree)]
      end

      def family_tree_hash
        direct_ancestors.reduce({}) {|h,mod| h[mod] = mod.family_tree_hash; h }
      end
    end

    module Kernel
      module ClassMethods
        # Kernel finds all the same classes boring as other modules do, except for itself.
        def self.boring_classes
          super - [::Kernel, *::Kernel.included_modules]
        end
      end
    end

    module BasicObject
      module ClassMethods
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
    end

    module Class
      # True only if method +m+ is defined in this class (local) and is also in the superclass
      def method_overridden? m
        self.method_local?(m) && superclass.respond_to?(m)
      end

      # Methods defined in this class (local) that are also in the superclass
      def overridden_methods
        superclass.methods.select{|m| self.method_local? m }
      end

      def direct_lineage
        if superclass
          [self,*superclass.direct_lineage]
        else
          [self]
        end
      end
    end


    module Array
      # Join elements of the array into a string using the << method.
      # The separator can be specified as with +join+.
      # The value to return for an empty list can also be provided, defaulting to "".
      def joincat sep=nil, empty=''
        return empty if empty?
        sep ||= $,
        if sep.nil?
          reduce {|acc, x| acc << x }
        else
          reduce {|acc, x| acc << sep << x }
        end
      end
    end # module Array

  end # module Ext
end # module PrintMembers

[String,Method,Module,Class,Object,Kernel,BasicObject,Array].each do |mod|
  ext = PrintMembers::Ext.const_get(mod.name)
  mod.instance_exec(ext) {|ext| include ext }
  mod.extend ext::ClassMethods if defined? ext::ClassMethods
end

