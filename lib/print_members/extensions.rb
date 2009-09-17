
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

  def group_by
    h = {}
    each {|x| k = yield x
              h[k] ||= []
              h[k] << x }
    return h
  end
end # module Enumerable

module PrintMembers
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

    module Object
      # Anonymous singleton class of this object
      def singleton_class
        class << self; self; end
      end

      # Eval block in the context of the singleton class
      def singleton_class_eval &block
        self.singleton_class.class_eval &block
      end

      def safe_method m
        method m rescue nil
      end

      # Call the given instance method defined in the class of +self+
      # bypassing any method defined in its singleton class
      def send_bypass_singleton meth, *args, &block
        self.class.instance_method(meth).bind(self).call *args, &block
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

      def pad len, val=nil
        if size < len
          self + ::Array.new(len-size, val)
        else
          self
        end
      end

      def pad! len, val=nil
        if size < len
          concat ::Array.new(len-size, val)
        else
          self
        end
      end

      def map_with_index
        if block_given?
          nova = ::Array.new size
          size.times {|i| nova[i] = yield self[i], i }
          nova
        else
          enum_for :map_with_index
        end
      end
    end # module Array

  end # module Ext
end # module PrintMembers

[String,Object,Kernel,BasicObject,Array].each do |mod|
  ext = PrintMembers::Ext.const_get(mod.name)
  mod.send :include, ext
  mod.extend ext::ClassMethods if defined? ext::ClassMethods
end

class ::Class
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

class ::Module
  def safe_const_get c
    const_get c rescue nil
  end

  def instances
    ::ObjectSpace.each_object(self).to_a
  end

  def nested_modules
    self.constants.map {|c|
      self.const_get c
    }.select {|m|
      m.is_a?(::Module) && m != self && (m.name.start_with?(self.name) || self == ::Object)
    }
  end

  def base_name
    self.name.split(/::/).last
  end

  def nesting_path
    last = ::Object
    name.split(/::/).map {|seg|
      return nil unless seg =~ /^[A-Z][A-Za-z0-9_]*$/
      last = last.const_get(seg)
    }
  end

  def nesting_depth
    self.name.scan(/::/).size
  end

  def nesting_parent
    self.nesting[-2] || ::Object
  end

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

  def safe_instance_method m
    instance_method m rescue nil
  end

  ### Ancestry ###

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

