# frozen_string_literal: true

require "monitor"

module ActiveEntity
  module ModelSchema
    extend ActiveSupport::Concern

    ##
    # :singleton-method: primary_key_prefix_type
    # :call-seq: primary_key_prefix_type
    #
    # The prefix type that will be prepended to every primary key column name.
    # The options are +:table_name+ and +:table_name_with_underscore+. If the first is specified,
    # the Product class will look for "productid" instead of "id" as the primary column. If the
    # latter is specified, the Product class will look for "product_id" instead of "id". Remember
    # that this is a global setting for all Active Entitys.

    ##
    # :singleton-method: primary_key_prefix_type=
    # :call-seq: primary_key_prefix_type=(prefix_type)
    #
    # Sets the prefix type that will be prepended to every primary key column name.
    # The options are +:table_name+ and +:table_name_with_underscore+. If the first is specified,
    # the Product class will look for "productid" instead of "id" as the primary column. If the
    # latter is specified, the Product class will look for "product_id" instead of "id". Remember
    # that this is a global setting for all Active Entitys.

    ##
    # :singleton-method: table_name_prefix
    # :call-seq: table_name_prefix
    #
    # The prefix string to prepend to every table name.

    ##
    # :singleton-method: table_name_prefix=
    # :call-seq: table_name_prefix=(prefix)
    #
    # Sets the prefix string to prepend to every table name. So if set to "basecamp_", all table
    # names will be named like "basecamp_projects", "basecamp_people", etc. This is a convenient
    # way of creating a namespace for tables in a shared database. By default, the prefix is the
    # empty string.
    #
    # If you are organising your models within modules you can add a prefix to the models within
    # a namespace by defining a singleton method in the parent module called table_name_prefix which
    # returns your chosen prefix.

    ##
    # :singleton-method: table_name_suffix
    # :call-seq: table_name_suffix
    #
    # The suffix string to append to every table name.

    ##
    # :singleton-method: table_name_suffix=
    # :call-seq: table_name_suffix=(suffix)
    #
    # Works like +table_name_prefix=+, but appends instead of prepends (set to "_basecamp" gives "projects_basecamp",
    # "people_basecamp"). By default, the suffix is the empty string.
    #
    # If you are organising your models within modules, you can add a suffix to the models within
    # a namespace by defining a singleton method in the parent module called table_name_suffix which
    # returns your chosen suffix.

    ##
    # :singleton-method: schema_migrations_table_name
    # :call-seq: schema_migrations_table_name
    #
    # The name of the schema migrations table. By default, the value is <tt>"schema_migrations"</tt>.

    ##
    # :singleton-method: schema_migrations_table_name=
    # :call-seq: schema_migrations_table_name=(table_name)
    #
    # Sets the name of the schema migrations table.

    ##
    # :singleton-method: internal_metadata_table_name
    # :call-seq: internal_metadata_table_name
    #
    # The name of the internal metadata table. By default, the value is <tt>"ar_internal_metadata"</tt>.

    ##
    # :singleton-method: internal_metadata_table_name=
    # :call-seq: internal_metadata_table_name=(table_name)
    #
    # Sets the name of the internal metadata table.

    ##
    # :singleton-method: pluralize_table_names
    # :call-seq: pluralize_table_names
    #
    # Indicates whether table names should be the pluralized versions of the corresponding class names.
    # If true, the default table name for a Product class will be "products". If false, it would just be "product".
    # See table_name for the full rules on table/class naming. This is true, by default.

    ##
    # :singleton-method: pluralize_table_names=
    # :call-seq: pluralize_table_names=(value)
    #
    # Set whether table names should be the pluralized versions of the corresponding class names.
    # If true, the default table name for a Product class will be "products". If false, it would just be "product".
    # See table_name for the full rules on table/class naming. This is true, by default.

    ##
    # :singleton-method: implicit_order_column
    # :call-seq: implicit_order_column
    #
    # The name of the column records are ordered by if no explicit order clause
    # is used during an ordered finder call. If not set the primary key is used.

    ##
    # :singleton-method: implicit_order_column=
    # :call-seq: implicit_order_column=(column_name)
    #
    # Sets the column to sort records by when no explicit order clause is used
    # during an ordered finder call. Useful when the primary key is not an
    # auto-incrementing integer, for example when it's a UUID. Records are subsorted
    # by the primary key if it exists to ensure deterministic results.

    ##
    # :singleton-method: immutable_strings_by_default=
    # :call-seq: immutable_strings_by_default=(bool)
    #
    # Determines whether columns should infer their type as +:string+ or
    # +:immutable_string+. This setting does not affect the behavior of
    # <tt>attribute :foo, :string</tt>. Defaults to false.

    included do
      # Defines the name of the table column which will store the class name on single-table
      # inheritance situations.
      #
      # The default inheritance column name is +type+, which means it's a
      # reserved word inside Active Entity. To be able to use single-table
      # inheritance with another column name, or to use the column +type+ in
      # your own model for something else, you can set +inheritance_column+:
      #
      #     self.inheritance_column = 'zoink'
      class_attribute :inheritance_column, instance_accessor: false, default: "type"
      singleton_class.class_eval do
        alias_method :_inheritance_column=, :inheritance_column=
        private :_inheritance_column=
        alias_method :inheritance_column=, :real_inheritance_column=
      end

      delegate :type_for_attribute, to: :class

      initialize_load_schema_monitor
    end

    module ClassMethods
      def real_inheritance_column=(value) # :nodoc:
        self._inheritance_column = value.to_s
      end

      def attributes_builder # :nodoc:
        unless defined?(@attributes_builder) && @attributes_builder
          defaults = _default_attributes.except(*(column_names - [primary_key]))
          @attributes_builder = ActiveModel::AttributeSet::Builder.new(attribute_types, defaults)
        end
        @attributes_builder
      end

      def attribute_types # :nodoc:
        load_schema
        @attribute_types ||= Hash.new(Type.default_value)
      end

      def yaml_encoder # :nodoc:
        @yaml_encoder ||= ActiveModel::AttributeSet::YAMLEncoder.new(attribute_types)
      end

      # Returns the type of the attribute with the given name, after applying
      # all modifiers. This method is the only valid source of information for
      # anything related to the types of a model's attributes. This method will
      # access the database and load the model's schema if it is required.
      #
      # The return value of this method will implement the interface described
      # by ActiveModel::Type::Value (though the object itself may not subclass
      # it).
      #
      # +attr_name+ The name of the attribute to retrieve the type for. Must be
      # a string or a symbol.
      def type_for_attribute(attr_name, &block)
        attr_name = attr_name.to_s
        attr_name = attribute_aliases[attr_name] || attr_name

        if block
          attribute_types.fetch(attr_name, &block)
        else
          attribute_types[attr_name]
        end
      end

      # Returns a hash where the keys are column names and the values are
      # default values when instantiating the Active Entity object for this table.
      def column_defaults
        load_schema
        @column_defaults ||= _default_attributes.deep_dup.to_hash.freeze
      end

      def _default_attributes # :nodoc:
        load_schema
        @default_attributes ||= ActiveModel::AttributeSet.new({})
      end

      protected

        def initialize_load_schema_monitor
          @load_schema_monitor = Monitor.new
        end

      private

        def inherited(child_class)
          super
          child_class.initialize_load_schema_monitor
        end

        def schema_loaded?
          defined?(@schema_loaded) && @schema_loaded
        end

        def load_schema
          return if schema_loaded?
          @load_schema_monitor.synchronize do
            return if defined?(@load_schema_invoked) && @load_schema_invoked

            load_schema!

            @schema_loaded = true
          rescue
            reload_schema_from_cache # If the schema loading failed half way through, we must reset the state.
            raise
          end
        end

        def load_schema!
          @load_schema_invoked = true
        end

        def reload_schema_from_cache
          @attribute_types = nil
          @default_attributes = nil
          @attributes_builder = nil
          @schema_loaded = false
          @load_schema_invoked = false
          @attribute_names = nil
          @yaml_encoder = nil
          subclasses.each do |descendant|
            descendant.send(:reload_schema_from_cache)
          end
        end
    end
  end
end
