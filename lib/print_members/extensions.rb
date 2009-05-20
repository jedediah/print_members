module PrintMembers
  module Ext

    module Enumerable
      module ClassMethods
        def mash
          reduce({}) {|h,x| kv = yield x
                            h[kv[0]] = kv[1] if kv.respond_to? :[]
                            h }
        end
      end
    end

    module MethodTools
      # Return the gem that defines this method in the form [name,version]
      # where name is the name of the gem as a string
      # and version is an array of the version number components.
      # For example: ["rails",[2,3,2]]
      # Returns +nil+ if this method is not part of a gem or if the source is unknown.
      def source_gem
        return nil unless source_location && defined? Gem
        src = source_location[0]
        rsep = Regexp.escape(File::SEPARATOR)

        if path = Gem.path.find {|p| src.start_with? p }
          rpath = Regexp.escape(path)
          src =~ /^#{rpath}#{rsep}gems#{rsep}([^#{rsep}]+)-([0-9\.]+)/
          return [$1,$2.split(/\./).map(&:to_i)]
        end

    # TODO: try to give some useful info for standard libraries
    #     elsif !(path = $LOAD_PATH.select {|p| src.start_with? p }).empty?
    #       rpath = Regexp.escape(path.max(&:size))
    #       src =~ /^#{rpath}#{rsep}([^#{rsep}]+)/
    #       [$1,nil]
    #     end
      end
    end

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
    end


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
    end # module Array

  end # module Ext
end # module PrintMembers

[Enumerable,Method,Module,Class,Object,Kernel,BasicObject,Array].each do |mod|
  ext = PrintMembers::Ext.const_get(mod.name)
  mod.instance_exec(ext) {|ext| include ext }
  mod.extend ext::ClassMethods if defined? ext::ClassMethods
end

