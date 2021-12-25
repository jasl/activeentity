# frozen_string_literal: true

require "mutex_m"
require "active_support/core_ext/enumerable"

module ActiveEntity
  # = Active Entity Attribute Methods
  module AttributeMethods
    extend ActiveSupport::Concern
    include ActiveModel::AttributeMethods

    included do
      initialize_generated_modules
      include Read
      include Write
      include BeforeTypeCast
      include Query
      include PrimaryKey
      include TimeZoneConversion
      include Dirty
      include Serialization
    end

    RESTRICTED_CLASS_METHODS = %w(private public protected allocate new name parent superclass)

    # Port from ActiveModel https://github.com/rails/rails/blob/df475877efdcf74d7524f734ab8ad1d4704fd187/activemodel/lib/active_model/attribute_methods.rb#L518-L553
    module AttrNames # :nodoc:
      DEF_SAFE_NAME = /\A[a-zA-Z_]\w*\z/

      # We want to generate the methods via module_eval rather than
      # define_method, because define_method is slower on dispatch.
      # Evaluating many similar methods may use more memory as the instruction
      # sequences are duplicated and cached (in MRI).  define_method may
      # be slower on dispatch, but if you're careful about the closure
      # created, then define_method will consume much less memory.
      #
      # But sometimes the database might return columns with
      # characters that are not allowed in normal method names (like
      # 'my_column(omg)'. So to work around this we first define with
      # the __temp__ identifier, and then use alias method to rename
      # it to what we want.
      #
      # We are also defining a constant to hold the frozen string of
      # the attribute name. Using a constant means that we do not have
      # to allocate an object on each call to the attribute method.
      # Making it frozen means that it doesn't get duped when used to
      # key the @attributes in read_attribute.
      def self.define_attribute_accessor_method(owner, attr_name, writer: false)
        method_name = "#{attr_name}#{'=' if writer}"
        if attr_name.ascii_only? && DEF_SAFE_NAME.match?(attr_name)
          yield method_name, "'#{attr_name}'"
        else
          safe_name = attr_name.unpack1("h*")
          const_name = "ATTR_#{safe_name}"
          const_set(const_name, attr_name) unless const_defined?(const_name)
          temp_method_name = "__temp__#{safe_name}#{'=' if writer}"
          attr_name_expr = "::ActiveModel::AttributeMethods::AttrNames::#{const_name}"
          yield temp_method_name, attr_name_expr
          owner.rename_method(temp_method_name, method_name)
        end
      end
    end

    class GeneratedAttributeMethods < Module #:nodoc:
      include Mutex_m
    end

    class << self
      def dangerous_attribute_methods # :nodoc:
        @dangerous_attribute_methods ||= (
        Base.instance_methods +
          Base.private_instance_methods -
          Base.superclass.instance_methods -
          Base.superclass.private_instance_methods
        ).map { |m| -m.to_s }.to_set.freeze
      end
    end

    module ClassMethods
      def inherited(child_class) #:nodoc:
        child_class.initialize_generated_modules
        super
      end

      def initialize_generated_modules # :nodoc:
        @generated_attribute_methods = const_set(:GeneratedAttributeMethods, GeneratedAttributeMethods.new)
        private_constant :GeneratedAttributeMethods
        @attribute_methods_generated = false
        include @generated_attribute_methods

        super
      end

      # Generates all the attribute related methods for columns in the database
      # accessors, mutators and query methods.
      def define_attribute_methods # :nodoc:
        return false if @attribute_methods_generated
        # Use a mutex; we don't want two threads simultaneously trying to define
        # attribute methods.
        generated_attribute_methods.synchronize do
          return false if @attribute_methods_generated
          superclass.define_attribute_methods unless base_class?
          super(attribute_names)
          @attribute_methods_generated = true
        end
      end

      def undefine_attribute_methods # :nodoc:
        generated_attribute_methods.synchronize do
          super if defined?(@attribute_methods_generated) && @attribute_methods_generated
          @attribute_methods_generated = false
        end
      end

      # Raises an ActiveEntity::DangerousAttributeError exception when an
      # \Active \Record method is defined in the model, otherwise +false+.
      #
      #   class Person < ActiveEntity::Base
      #     def save
      #       'already defined by Active Entity'
      #     end
      #   end
      #
      #   Person.instance_method_already_implemented?(:save)
      #   # => ActiveEntity::DangerousAttributeError: save is defined by Active Entity. Check to make sure that you don't have an attribute or method with the same name.
      #
      #   Person.instance_method_already_implemented?(:name)
      #   # => false
      def instance_method_already_implemented?(method_name)
        if dangerous_attribute_method?(method_name)
          raise DangerousAttributeError, "#{method_name} is defined by Active Entity. Check to make sure that you don't have an attribute or method with the same name."
        end

        if superclass == Base
          super
        else
          # If ThisClass < ... < SomeSuperClass < ... < Base and SomeSuperClass
          # defines its own attribute method, then we don't want to overwrite that.
          defined = method_defined_within?(method_name, superclass, Base) &&
            ! superclass.instance_method(method_name).owner.is_a?(GeneratedAttributeMethods)
          defined || super
        end
      end

      # A method name is 'dangerous' if it is already (re)defined by Active Entity, but
      # not by any ancestors. (So 'puts' is not dangerous but 'save' is.)
      def dangerous_attribute_method?(name) # :nodoc:
        ::ActiveEntity::AttributeMethods.dangerous_attribute_methods.include?(name.to_s)
      end

      def method_defined_within?(name, klass, superklass = klass.superclass) # :nodoc:
        if klass.method_defined?(name) || klass.private_method_defined?(name)
          if superklass.method_defined?(name) || superklass.private_method_defined?(name)
            klass.instance_method(name).owner != superklass.instance_method(name).owner
          else
            true
          end
        else
          false
        end
      end

      # A class method is 'dangerous' if it is already (re)defined by Active Entity, but
      # not by any ancestors. (So 'puts' is not dangerous but 'new' is.)
      def dangerous_class_method?(method_name)
        return true if RESTRICTED_CLASS_METHODS.include?(method_name.to_s)

        if Base.respond_to?(method_name, true)
          if Object.respond_to?(method_name, true)
            Base.method(method_name).owner != Object.method(method_name).owner
          else
            true
          end
        else
          false
        end
      end

      # Returns an array of column names as strings if it's not an abstract class.
      # Otherwise it returns an empty array.
      #
      #   class Person < ActiveEntity::Base
      #   end
      #
      #   Person.attribute_names
      #   # => ["id", "created_at", "updated_at", "name", "age"]
      def attribute_names
        @attribute_names ||= if !abstract_class?
          attribute_types.keys
        else
          []
        end
      end

      # Returns true if the given attribute exists, otherwise false.
      #
      #   class Person < ActiveEntity::Base
      #   end
      #
      #   Person.has_attribute?('name')     # => true
      #   Person.has_attribute?('new_name') # => true
      #   Person.has_attribute?(:age)       # => true
      #   Person.has_attribute?(:nothing)   # => false
      def has_attribute?(attr_name)
        attr_name = attr_name.to_s
        attr_name = attribute_aliases[attr_name] || attr_name
        attribute_types.key?(attr_name)
      end

      def _has_attribute?(attr_name) # :nodoc:
        attribute_types.key?(attr_name)
      end

      # Port https://github.com/rails/rails/blob/df475877efdcf74d7524f734ab8ad1d4704fd187/activemodel/lib/active_model/attribute_methods.rb#L108-L111
      def define_attribute_methods(*attr_names)
        CodeGenerator.batch(generated_attribute_methods, __FILE__, __LINE__) do |owner|
          attr_names.flatten.each { |attr_name| define_attribute_method(attr_name, _owner: owner) }
        end
      end

      # https://github.com/rails/rails/blob/df475877efdcf74d7524f734ab8ad1d4704fd187/activemodel/lib/active_model/attribute_methods.rb#L208-L217
      def alias_attribute(new_name, old_name)
        self.attribute_aliases = attribute_aliases.merge(new_name.to_s => old_name.to_s)
        CodeGenerator.batch(self, __FILE__, __LINE__) do |owner|
          attribute_method_matchers.each do |matcher|
            matcher_new = matcher.method_name(new_name).to_s
            matcher_old = matcher.method_name(old_name).to_s
            define_proxy_call false, owner, matcher_new, matcher_old
          end
        end
      end
    end

    # Returns +true+ if the given attribute is in the attributes hash, otherwise +false+.
    #
    #   class Person < ActiveEntity::Base
    #     alias_attribute :new_name, :name
    #   end
    #
    #   person = Person.new
    #   person.has_attribute?(:name)     # => true
    #   person.has_attribute?(:new_name) # => true
    #   person.has_attribute?('age')     # => true
    #   person.has_attribute?(:nothing)  # => false
    def has_attribute?(attr_name)
      attr_name = attr_name.to_s
      attr_name = self.class.attribute_aliases[attr_name] || attr_name
      @attributes.key?(attr_name)
    end

    def _has_attribute?(attr_name) # :nodoc:
      @attributes.key?(attr_name)
    end

    # Returns an array of names for the attributes available on this object.
    #
    #   class Person < ActiveEntity::Base
    #   end
    #
    #   person = Person.new
    #   person.attribute_names
    #   # => ["id", "created_at", "updated_at", "name", "age"]
    def attribute_names
      @attributes.keys
    end

    # Returns a hash of all the attributes with their names as keys and the values of the attributes as values.
    #
    #   class Person < ActiveEntity::Base
    #   end
    #
    #   person = Person.create(name: 'Francesco', age: 22)
    #   person.attributes
    #   # => {"id"=>3, "created_at"=>Sun, 21 Oct 2012 04:53:04, "updated_at"=>Sun, 21 Oct 2012 04:53:04, "name"=>"Francesco", "age"=>22}
    def attributes
      @attributes.to_hash
    end

    # Returns an <tt>#inspect</tt>-like string for the value of the
    # attribute +attr_name+. String attributes are truncated up to 50
    # characters, Date and Time attributes are returned in the
    # <tt>:db</tt> format. Other attributes return the value of
    # <tt>#inspect</tt> without modification.
    #
    #   person = Person.create!(name: 'David Heinemeier Hansson ' * 3)
    #
    #   person.attribute_for_inspect(:name)
    #   # => "\"David Heinemeier Hansson David Heinemeier Hansson ...\""
    #
    #   person.attribute_for_inspect(:created_at)
    #   # => "\"2012-10-22 00:15:07\""
    #
    #   person.attribute_for_inspect(:tag_ids)
    #   # => "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]"
    def attribute_for_inspect(attr_name)
      attr_name = attr_name.to_s
      value = _read_attribute(attr_name)
      format_for_inspect(value)
    end

    # Returns +true+ if the specified +attribute+ has been set by the user or by a
    # database load and is neither +nil+ nor <tt>empty?</tt> (the latter only applies
    # to objects that respond to <tt>empty?</tt>, most notably Strings). Otherwise, +false+.
    # Note that it always returns +true+ with boolean attributes.
    #
    #   class Task < ActiveEntity::Base
    #   end
    #
    #   task = Task.new(title: '', is_done: false)
    #   task.attribute_present?(:title)   # => false
    #   task.attribute_present?(:is_done) # => true
    #   task.title = 'Buy milk'
    #   task.is_done = true
    #   task.attribute_present?(:title)   # => true
    #   task.attribute_present?(:is_done) # => true
    def attribute_present?(attr_name)
      attr_name = attr_name.to_s
      value = _read_attribute(attr_name)
      !value.nil? && !(value.respond_to?(:empty?) && value.empty?)
    end

    # Returns the value of the attribute identified by <tt>attr_name</tt> after it has been typecast (for example,
    # "2004-12-12" in a date column is cast to a date object, like Date.new(2004, 12, 12)). It raises
    # <tt>ActiveModel::MissingAttributeError</tt> if the identified attribute is missing.
    #
    # Note: +:id+ is always present.
    #
    #   class Person < ActiveEntity::Base
    #     belongs_to :organization
    #   end
    #
    #   person = Person.new(name: 'Francesco', age: '22')
    #   person[:name] # => "Francesco"
    #   person[:age]  # => 22
    #
    #   person = Person.select('id').first
    #   person[:name]            # => ActiveModel::MissingAttributeError: missing attribute: name
    #   person[:organization_id] # => ActiveModel::MissingAttributeError: missing attribute: organization_id
    def [](attr_name)
      read_attribute(attr_name) { |n| missing_attribute(n, caller) }
    end

    # Updates the attribute identified by <tt>attr_name</tt> with the specified +value+.
    # (Alias for the protected #write_attribute method).
    #
    #   class Person < ActiveEntity::Base
    #   end
    #
    #   person = Person.new
    #   person[:age] = '22'
    #   person[:age] # => 22
    #   person[:age].class # => Integer
    def []=(attr_name, value)
      write_attribute(attr_name, value)
    end

    private

      # Port https://github.com/rails/rails/blob/df475877efdcf74d7524f734ab8ad1d4704fd187/activemodel/lib/active_model/attribute_methods.rb#L338-L376
      class CodeGenerator
        class << self
          def batch(owner, path, line)
            if owner.is_a?(CodeGenerator)
              yield owner
            else
              instance = new(owner, path, line)
              result = yield instance
              instance.execute
              result
            end
          end
        end

        def initialize(owner, path, line)
          @owner = owner
          @path = path
          @line = line
          @sources = ["# frozen_string_literal: true\n"]
          @renames = {}
        end

        def <<(source_line)
          @sources << source_line
        end

        def rename_method(old_name, new_name)
          @renames[old_name] = new_name
        end

        def execute
          @owner.module_eval(@sources.join(";"), @path, @line - 1)
          @renames.each do |old_name, new_name|
            @owner.alias_method new_name, old_name
            @owner.undef_method old_name
          end
        end
      end
      private_constant :CodeGenerator

      def attribute_method?(attr_name)
        # We check defined? because Syck calls respond_to? before actually calling initialize.
        defined?(@attributes) && @attributes.key?(attr_name)
      end

      def format_for_inspect(value)
        if value.is_a?(String) && value.length > 50
          "#{value[0, 50]}...".inspect
        elsif value.is_a?(Date) || value.is_a?(Time)
          %("#{value.to_s(:db)}")
        else
          value.inspect
        end
      end

      def pk_attribute?(name)
        name == @primary_key
      end
  end
end
