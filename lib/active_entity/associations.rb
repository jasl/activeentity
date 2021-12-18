# frozen_string_literal: true

module ActiveEntity
  class AssociationNotFoundError < ConfigurationError # :nodoc:
    attr_reader :record, :association_name

    def initialize(record = nil, association_name = nil)
      @record           = record
      @association_name = association_name
      if record && association_name
        super("Association named '#{association_name}' was not found on #{record.class.name}; perhaps you misspelled it?")
      else
        super("Association was not found.")
      end
    end

    if defined?(DidYouMean::Correctable) && defined?(DidYouMean::SpellChecker)
      include DidYouMean::Correctable

      def corrections
        if record && association_name
          @corrections ||= begin
            maybe_these = record.class.reflections.keys
            DidYouMean::SpellChecker.new(dictionary: maybe_these).correct(association_name)
          end
        else
          []
        end
      end
    end
  end

  class InverseOfAssociationNotFoundError < ActiveEntityError # :nodoc:
    attr_reader :reflection, :associated_class

    def initialize(reflection = nil, associated_class = nil)
      if reflection
        @reflection = reflection
        @associated_class = associated_class.nil? ? reflection.klass : associated_class
        super("Could not find the inverse association for #{reflection.name} (#{reflection.options[:inverse_of].inspect} in #{associated_class.nil? ? reflection.class_name : associated_class.name})")
      else
        super("Could not find the inverse association.")
      end
    end

    if defined?(DidYouMean::Correctable) && defined?(DidYouMean::SpellChecker)
      include DidYouMean::Correctable

      def corrections
        if reflection && associated_class
          @corrections ||= begin
            maybe_these = associated_class.reflections.keys
            DidYouMean::SpellChecker.new(dictionary: maybe_these).correct(reflection.options[:inverse_of].to_s)
          end
        else
          []
        end
      end
    end
  end

  class InverseOfAssociationRecursiveError < ActiveEntityError # :nodoc:
    attr_reader :reflection
    def initialize(reflection = nil)
      if reflection
        @reflection = reflection
        super("Inverse association #{reflection.name} (#{reflection.options[:inverse_of].inspect} in #{reflection.class_name}) is recursive.")
      else
        super("Inverse association is recursive.")
      end
    end
  end

  # See ActiveEntity::Associations::ClassMethods for documentation.
  module Associations # :nodoc:
    extend ActiveSupport::Autoload
    extend ActiveSupport::Concern

    module Embeds
      extend ActiveSupport::Autoload

      # These classes will be loaded when associations are created.
      # So there is no need to eager load them.
      autoload :Association
      autoload :SingularAssociation
      autoload :CollectionAssociation
      autoload :CollectionProxy

      module Builder # :nodoc:
        autoload :Association,             "active_entity/associations/embeds/builder/association"
        autoload :SingularAssociation,     "active_entity/associations/embeds/builder/singular_association"
        autoload :CollectionAssociation,   "active_entity/associations/embeds/builder/collection_association"

        autoload :EmbeddedIn,              "active_entity/associations/embeds/builder/embedded_in"
        autoload :EmbedsOne,               "active_entity/associations/embeds/builder/embeds_one"
        autoload :EmbedsMany,              "active_entity/associations/embeds/builder/embeds_many"
      end

      eager_autoload do
        autoload :EmbeddedInAssociation
        autoload :EmbedsOneAssociation
        autoload :EmbedsManyAssociation
      end
    end

    def self.eager_load!
      super
      Embeds.eager_load!
    end

    # Returns the association instance for the given name, instantiating it if it doesn't already exist
    def association(name) # :nodoc:
      association = association_instance_get(name)

      if association.nil?
        unless reflection = self.class._reflect_on_association(name)
          raise AssociationNotFoundError.new(self, name)
        end
        association = reflection.association_class.new(self, reflection)
        association_instance_set(name, association)
      end

      association
    end

    def association_cached?(name) # :nodoc:
      @association_cache.key?(name)
    end

    def initialize_dup(*) # :nodoc:
      @association_cache = {}
      super
    end

    private

      def init_internals
        @association_cache = {}
        super
      end

      # Returns the specified association instance if it exists, +nil+ otherwise.
      def association_instance_get(name)
        @association_cache[name]
      end

      # Set the specified association instance.
      def association_instance_set(name, association)
        @association_cache[name] = association
      end

      # \Associations are a set of macro-like class methods for tying objects together through
      # foreign keys. They express relationships like "Project has one Project Manager"
      # or "Project belongs to a Portfolio". Each macro adds a number of methods to the
      # class which are specialized according to the collection or association symbol and the
      # options hash. It works much the same way as Ruby's own <tt>attr*</tt>
      # methods.
      #
      #   class Project < ActiveEntity::Base
      #     belongs_to              :portfolio
      #     has_one                 :project_manager
      #     has_many                :milestones
      #     has_and_belongs_to_many :categories
      #   end
      #
      # The project class now has the following methods (and more) to ease the traversal and
      # manipulation of its relationships:
      # * <tt>Project#portfolio</tt>, <tt>Project#portfolio=(portfolio)</tt>, <tt>Project#reload_portfolio</tt>
      # * <tt>Project#project_manager</tt>, <tt>Project#project_manager=(project_manager)</tt>, <tt>Project#reload_project_manager</tt>
      # * <tt>Project#milestones.empty?</tt>, <tt>Project#milestones.size</tt>, <tt>Project#milestones</tt>, <tt>Project#milestones<<(milestone)</tt>,
      #   <tt>Project#milestones.delete(milestone)</tt>, <tt>Project#milestones.destroy(milestone)</tt>, <tt>Project#milestones.find(milestone_id)</tt>,
      #   <tt>Project#milestones.build</tt>, <tt>Project#milestones.create</tt>
      # * <tt>Project#categories.empty?</tt>, <tt>Project#categories.size</tt>, <tt>Project#categories</tt>, <tt>Project#categories<<(category1)</tt>,
      #   <tt>Project#categories.delete(category1)</tt>, <tt>Project#categories.destroy(category1)</tt>
      #
      # === A word of warning
      #
      # Don't create associations that have the same name as {instance methods}[rdoc-ref:ActiveEntity::Core] of
      # <tt>ActiveEntity::Base</tt>. Since the association adds a method with that name to
      # its model, using an association with the same name as one provided by <tt>ActiveEntity::Base</tt> will override the method inherited through <tt>ActiveEntity::Base</tt> and will break things.
      # For instance, +attributes+ and +connection+ would be bad choices for association names, because those names already exist in the list of <tt>ActiveEntity::Base</tt> instance methods.
      #
      # == Auto-generated methods
      # See also Instance Public methods below for more details.
      #
      # === Singular associations (one-to-one)
      #                                     |            |  belongs_to  |
      #   generated methods                 | belongs_to | :polymorphic | has_one
      #   ----------------------------------+------------+--------------+---------
      #   other                             |     X      |      X       |    X
      #   other=(other)                     |     X      |      X       |    X
      #   build_other(attributes={})        |     X      |              |    X
      #   create_other(attributes={})       |     X      |              |    X
      #   create_other!(attributes={})      |     X      |              |    X
      #   reload_other                      |     X      |      X       |    X
      #   other_changed?                    |     X      |      X       |
      #   other_previously_changed?         |     X      |      X       |
      #
      # === Collection associations (one-to-many / many-to-many)
      #                                     |       |          | has_many
      #   generated methods                 | habtm | has_many | :through
      #   ----------------------------------+-------+----------+----------
      #   others                            |   X   |    X     |    X
      #   others=(other,other,...)          |   X   |    X     |    X
      #   other_ids                         |   X   |    X     |    X
      #   other_ids=(id,id,...)             |   X   |    X     |    X
      #   others<<                          |   X   |    X     |    X
      #   others.push                       |   X   |    X     |    X
      #   others.concat                     |   X   |    X     |    X
      #   others.build(attributes={})       |   X   |    X     |    X
      #   others.create(attributes={})      |   X   |    X     |    X
      #   others.create!(attributes={})     |   X   |    X     |    X
      #   others.size                       |   X   |    X     |    X
      #   others.length                     |   X   |    X     |    X
      #   others.count                      |   X   |    X     |    X
      #   others.sum(*args)                 |   X   |    X     |    X
      #   others.empty?                     |   X   |    X     |    X
      #   others.clear                      |   X   |    X     |    X
      #   others.delete(other,other,...)    |   X   |    X     |    X
      #   others.delete_all                 |   X   |    X     |    X
      #   others.destroy(other,other,...)   |   X   |    X     |    X
      #   others.destroy_all                |   X   |    X     |    X
      #   others.find(*args)                |   X   |    X     |    X
      #   others.exists?                    |   X   |    X     |    X
      #   others.distinct                   |   X   |    X     |    X
      #   others.reset                      |   X   |    X     |    X
      #   others.reload                     |   X   |    X     |    X
      #
      # === Overriding generated methods
      #
      # Association methods are generated in a module included into the model
      # class, making overrides easy. The original generated method can thus be
      # called with +super+:
      #
      #   class Car < ActiveEntity::Base
      #     belongs_to :owner
      #     belongs_to :old_owner
      #
      #     def owner=(new_owner)
      #       self.old_owner = self.owner
      #       super
      #     end
      #   end
      #
      # The association methods module is included immediately after the
      # generated attributes methods module, meaning an association will
      # override the methods for an attribute with the same name.
      #
      # == Cardinality and associations
      #
      # Active Entity associations can be used to describe one-to-one, one-to-many and many-to-many
      # relationships between models. Each model uses an association to describe its role in
      # the relation. The #belongs_to association is always used in the model that has
      # the foreign key.
      #
      # === One-to-one
      #
      # Use #has_one in the base, and #belongs_to in the associated model.
      #
      #   class Employee < ActiveEntity::Base
      #     has_one :office
      #   end
      #   class Office < ActiveEntity::Base
      #     belongs_to :employee    # foreign key - employee_id
      #   end
      #
      # === One-to-many
      #
      # Use #has_many in the base, and #belongs_to in the associated model.
      #
      #   class Manager < ActiveEntity::Base
      #     has_many :employees
      #   end
      #   class Employee < ActiveEntity::Base
      #     belongs_to :manager     # foreign key - manager_id
      #   end
      #
      # === Many-to-many
      #
      # There are two ways to build a many-to-many relationship.
      #
      # The first way uses a #has_many association with the <tt>:through</tt> option and a join model, so
      # there are two stages of associations.
      #
      #   class Assignment < ActiveEntity::Base
      #     belongs_to :programmer  # foreign key - programmer_id
      #     belongs_to :project     # foreign key - project_id
      #   end
      #   class Programmer < ActiveEntity::Base
      #     has_many :assignments
      #     has_many :projects, through: :assignments
      #   end
      #   class Project < ActiveEntity::Base
      #     has_many :assignments
      #     has_many :programmers, through: :assignments
      #   end
      #
      # For the second way, use #has_and_belongs_to_many in both models. This requires a join table
      # that has no corresponding model or primary key.
      #
      #   class Programmer < ActiveEntity::Base
      #     has_and_belongs_to_many :projects       # foreign keys in the join table
      #   end
      #   class Project < ActiveEntity::Base
      #     has_and_belongs_to_many :programmers    # foreign keys in the join table
      #   end
      #
      # Choosing which way to build a many-to-many relationship is not always simple.
      # If you need to work with the relationship model as its own entity,
      # use #has_many <tt>:through</tt>. Use #has_and_belongs_to_many when working with legacy schemas or when
      # you never work directly with the relationship itself.
      #
      # == Is it a #belongs_to or #has_one association?
      #
      # Both express a 1-1 relationship. The difference is mostly where to place the foreign
      # key, which goes on the table for the class declaring the #belongs_to relationship.
      #
      #   class User < ActiveEntity::Base
      #     # I reference an account.
      #     belongs_to :account
      #   end
      #
      #   class Account < ActiveEntity::Base
      #     # One user references me.
      #     has_one :user
      #   end
      #
      # The tables for these classes could look something like:
      #
      #   CREATE TABLE users (
      #     id bigint NOT NULL auto_increment,
      #     account_id bigint default NULL,
      #     name varchar default NULL,
      #     PRIMARY KEY  (id)
      #   )
      #
      #   CREATE TABLE accounts (
      #     id bigint NOT NULL auto_increment,
      #     name varchar default NULL,
      #     PRIMARY KEY  (id)
      #   )
      #
      # == Unsaved objects and associations
      #
      # You can manipulate objects and associations before they are saved to the database, but
      # there is some special behavior you should be aware of, mostly involving the saving of
      # associated objects.
      #
      # You can set the <tt>:autosave</tt> option on a #has_one, #belongs_to,
      # #has_many, or #has_and_belongs_to_many association. Setting it
      # to +true+ will _always_ save the members, whereas setting it to +false+ will
      # _never_ save the members. More details about <tt>:autosave</tt> option is available at
      # AutosaveAssociation.
      #
      # === One-to-one associations
      #
      # * Assigning an object to a #has_one association automatically saves that object and
      #   the object being replaced (if there is one), in order to update their foreign
      #   keys - except if the parent object is unsaved (<tt>new_record? == true</tt>).
      # * If either of these saves fail (due to one of the objects being invalid), an
      #   ActiveEntity::RecordNotSaved exception is raised and the assignment is
      #   cancelled.
      # * If you wish to assign an object to a #has_one association without saving it,
      #   use the <tt>#build_association</tt> method (documented below). The object being
      #   replaced will still be saved to update its foreign key.
      # * Assigning an object to a #belongs_to association does not save the object, since
      #   the foreign key field belongs on the parent. It does not save the parent either.
      #
      # === Collections
      #
      # * Adding an object to a collection (#has_many or #has_and_belongs_to_many) automatically
      #   saves that object, except if the parent object (the owner of the collection) is not yet
      #   stored in the database.
      # * If saving any of the objects being added to a collection (via <tt>push</tt> or similar)
      #   fails, then <tt>push</tt> returns +false+.
      # * If saving fails while replacing the collection (via <tt>association=</tt>), an
      #   ActiveEntity::RecordNotSaved exception is raised and the assignment is
      #   cancelled.
      # * You can add an object to a collection without automatically saving it by using the
      #   <tt>collection.build</tt> method (documented below).
      # * All unsaved (<tt>new_record? == true</tt>) members of the collection are automatically
      #   saved when the parent is saved.
      #
      # == Customizing the query
      #
      # \Associations are built from <tt>Relation</tt> objects, and you can use the Relation syntax
      # to customize them. For example, to add a condition:
      #
      #   class Blog < ActiveEntity::Base
      #     has_many :published_posts, -> { where(published: true) }, class_name: 'Post'
      #   end
      #
      # Inside the <tt>-> { ... }</tt> block you can use all of the usual Relation methods.
      #
      # === Accessing the owner object
      #
      # Sometimes it is useful to have access to the owner object when building the query. The owner
      # is passed as a parameter to the block. For example, the following association would find all
      # events that occur on the user's birthday:
      #
      #   class User < ActiveEntity::Base
      #     has_many :birthday_events, ->(user) { where(starts_on: user.birthday) }, class_name: 'Event'
      #   end
      #
      # Note: Joining, eager loading and preloading of these associations is not possible.
      # These operations happen before instance creation and the scope will be called with a +nil+ argument.
      #
      # == Association callbacks
      #
      # Similar to the normal callbacks that hook into the life cycle of an Active Entity object,
      # you can also define callbacks that get triggered when you add an object to or remove an
      # object from an association collection.
      #
      #   class Project
      #     has_and_belongs_to_many :developers, after_add: :evaluate_velocity
      #
      #     def evaluate_velocity(developer)
      #       ...
      #     end
      #   end
      #
      # It's possible to stack callbacks by passing them as an array. Example:
      #
      #   class Project
      #     has_and_belongs_to_many :developers,
      #                             after_add: [:evaluate_velocity, Proc.new { |p, d| p.shipping_date = Time.now}]
      #   end
      #
      # Possible callbacks are: +before_add+, +after_add+, +before_remove+ and +after_remove+.
      #
      # If any of the +before_add+ callbacks throw an exception, the object will not be
      # added to the collection.
      #
      # Similarly, if any of the +before_remove+ callbacks throw an exception, the object
      # will not be removed from the collection.
      #
      # == Association extensions
      #
      # The proxy objects that control the access to associations can be extended through anonymous
      # modules. This is especially beneficial for adding new finders, creators, and other
      # factory-type methods that are only used as part of this association.
      #
      #   class Account < ActiveEntity::Base
      #     has_many :people do
      #       def find_or_create_by_name(name)
      #         first_name, last_name = name.split(" ", 2)
      #         find_or_create_by(first_name: first_name, last_name: last_name)
      #       end
      #     end
      #   end
      #
      #   person = Account.first.people.find_or_create_by_name("David Heinemeier Hansson")
      #   person.first_name # => "David"
      #   person.last_name  # => "Heinemeier Hansson"
      #
      # If you need to share the same extensions between many associations, you can use a named
      # extension module.
      #
      #   module FindOrCreateByNameExtension
      #     def find_or_create_by_name(name)
      #       first_name, last_name = name.split(" ", 2)
      #       find_or_create_by(first_name: first_name, last_name: last_name)
      #     end
      #   end
      #
      #   class Account < ActiveEntity::Base
      #     has_many :people, -> { extending FindOrCreateByNameExtension }
      #   end
      #
      #   class Company < ActiveEntity::Base
      #     has_many :people, -> { extending FindOrCreateByNameExtension }
      #   end
      #
      # Some extensions can only be made to work with knowledge of the association's internals.
      # Extensions can access relevant state using the following methods (where +items+ is the
      # name of the association):
      #
      # * <tt>record.association(:items).owner</tt> - Returns the object the association is part of.
      # * <tt>record.association(:items).reflection</tt> - Returns the reflection object that describes the association.
      # * <tt>record.association(:items).target</tt> - Returns the associated object for #belongs_to and #has_one, or
      #   the collection of associated objects for #has_many and #has_and_belongs_to_many.
      #
      # However, inside the actual extension code, you will not have access to the <tt>record</tt> as
      # above. In this case, you can access <tt>proxy_association</tt>. For example,
      # <tt>record.association(:items)</tt> and <tt>record.items.proxy_association</tt> will return
      # the same object, allowing you to make calls like <tt>proxy_association.owner</tt> inside
      # association extensions.
      #
      # == Association Join Models
      #
      # Has Many associations can be configured with the <tt>:through</tt> option to use an
      # explicit join model to retrieve the data. This operates similarly to a
      # #has_and_belongs_to_many association. The advantage is that you're able to add validations,
      # callbacks, and extra attributes on the join model. Consider the following schema:
      #
      #   class Author < ActiveEntity::Base
      #     has_many :authorships
      #     has_many :books, through: :authorships
      #   end
      #
      #   class Authorship < ActiveEntity::Base
      #     belongs_to :author
      #     belongs_to :book
      #   end
      #
      #   @author = Author.first
      #   @author.authorships.collect { |a| a.book } # selects all books that the author's authorships belong to
      #   @author.books                              # selects all books by using the Authorship join model
      #
      # You can also go through a #has_many association on the join model:
      #
      #   class Firm < ActiveEntity::Base
      #     has_many   :clients
      #     has_many   :invoices, through: :clients
      #   end
      #
      #   class Client < ActiveEntity::Base
      #     belongs_to :firm
      #     has_many   :invoices
      #   end
      #
      #   class Invoice < ActiveEntity::Base
      #     belongs_to :client
      #   end
      #
      #   @firm = Firm.first
      #   @firm.clients.flat_map { |c| c.invoices } # select all invoices for all clients of the firm
      #   @firm.invoices                            # selects all invoices by going through the Client join model
      #
      # Similarly you can go through a #has_one association on the join model:
      #
      #   class Group < ActiveEntity::Base
      #     has_many   :users
      #     has_many   :avatars, through: :users
      #   end
      #
      #   class User < ActiveEntity::Base
      #     belongs_to :group
      #     has_one    :avatar
      #   end
      #
      #   class Avatar < ActiveEntity::Base
      #     belongs_to :user
      #   end
      #
      #   @group = Group.first
      #   @group.users.collect { |u| u.avatar }.compact # select all avatars for all users in the group
      #   @group.avatars                                # selects all avatars by going through the User join model.
      #
      # An important caveat with going through #has_one or #has_many associations on the
      # join model is that these associations are *read-only*. For example, the following
      # would not work following the previous example:
      #
      #   @group.avatars << Avatar.new   # this would work if User belonged_to Avatar rather than the other way around
      #   @group.avatars.delete(@group.avatars.last)  # so would this
      #
      # == Setting Inverses
      #
      # If you are using a #belongs_to on the join model, it is a good idea to set the
      # <tt>:inverse_of</tt> option on the #belongs_to, which will mean that the following example
      # works correctly (where <tt>tags</tt> is a #has_many <tt>:through</tt> association):
      #
      #   @post = Post.first
      #   @tag = @post.tags.build name: "ruby"
      #   @tag.save
      #
      # The last line ought to save the through record (a <tt>Tagging</tt>). This will only work if the
      # <tt>:inverse_of</tt> is set:
      #
      #   class Tagging < ActiveEntity::Base
      #     belongs_to :post
      #     belongs_to :tag, inverse_of: :taggings
      #   end
      #
      # If you do not set the <tt>:inverse_of</tt> record, the association will
      # do its best to match itself up with the correct inverse. Automatic
      # inverse detection only works on #has_many, #has_one, and
      # #belongs_to associations.
      #
      # <tt>:foreign_key</tt> and <tt>:through</tt> options on the associations
      # will also prevent the association's inverse from being found automatically,
      # as will a custom scopes in some cases. See further details in the
      # {Active Entity Associations guide}[https://guides.rubyonrails.org/association_basics.html#bi-directional-associations].
      #
      # The automatic guessing of the inverse association uses a heuristic based
      # on the name of the class, so it may not work for all associations,
      # especially the ones with non-standard names.
      #
      # You can turn off the automatic detection of inverse associations by setting
      # the <tt>:inverse_of</tt> option to <tt>false</tt> like so:
      #
      #   class Tagging < ActiveEntity::Base
      #     belongs_to :tag, inverse_of: false
      #   end
      #
      # == Nested \Associations
      #
      # You can actually specify *any* association with the <tt>:through</tt> option, including an
      # association which has a <tt>:through</tt> option itself. For example:
      #
      #   class Author < ActiveEntity::Base
      #     has_many :posts
      #     has_many :comments, through: :posts
      #     has_many :commenters, through: :comments
      #   end
      #
      #   class Post < ActiveEntity::Base
      #     has_many :comments
      #   end
      #
      #   class Comment < ActiveEntity::Base
      #     belongs_to :commenter
      #   end
      #
      #   @author = Author.first
      #   @author.commenters # => People who commented on posts written by the author
      #
      # An equivalent way of setting up this association this would be:
      #
      #   class Author < ActiveEntity::Base
      #     has_many :posts
      #     has_many :commenters, through: :posts
      #   end
      #
      #   class Post < ActiveEntity::Base
      #     has_many :comments
      #     has_many :commenters, through: :comments
      #   end
      #
      #   class Comment < ActiveEntity::Base
      #     belongs_to :commenter
      #   end
      #
      # When using a nested association, you will not be able to modify the association because there
      # is not enough information to know what modification to make. For example, if you tried to
      # add a <tt>Commenter</tt> in the example above, there would be no way to tell how to set up the
      # intermediate <tt>Post</tt> and <tt>Comment</tt> objects.
      #
      # == Polymorphic \Associations
      #
      # Polymorphic associations on models are not restricted on what types of models they
      # can be associated with. Rather, they specify an interface that a #has_many association
      # must adhere to.
      #
      #   class Asset < ActiveEntity::Base
      #     belongs_to :attachable, polymorphic: true
      #   end
      #
      #   class Post < ActiveEntity::Base
      #     has_many :assets, as: :attachable         # The :as option specifies the polymorphic interface to use.
      #   end
      #
      #   @asset.attachable = @post
      #
      # This works by using a type column in addition to a foreign key to specify the associated
      # record. In the Asset example, you'd need an +attachable_id+ integer column and an
      # +attachable_type+ string column.
      #
      # Using polymorphic associations in combination with single table inheritance (STI) is
      # a little tricky. In order for the associations to work as expected, ensure that you
      # store the base model for the STI models in the type column of the polymorphic
      # association. To continue with the asset example above, suppose there are guest posts
      # and member posts that use the posts table for STI. In this case, there must be a +type+
      # column in the posts table.
      #
      # Note: The <tt>attachable_type=</tt> method is being called when assigning an +attachable+.
      # The +class_name+ of the +attachable+ is passed as a String.
      #
      #   class Asset < ActiveEntity::Base
      #     belongs_to :attachable, polymorphic: true
      #
      #     def attachable_type=(class_name)
      #        super(class_name.constantize.base_class.to_s)
      #     end
      #   end
      #
      #   class Post < ActiveEntity::Base
      #     # because we store "Post" in attachable_type now dependent: :destroy will work
      #     has_many :assets, as: :attachable, dependent: :destroy
      #   end
      #
      #   class GuestPost < Post
      #   end
      #
      #   class MemberPost < Post
      #   end
      #
      # == Caching
      #
      # All of the methods are built on a simple caching principle that will keep the result
      # of the last query around unless specifically instructed not to. The cache is even
      # shared across methods to make it even cheaper to use the macro-added methods without
      # worrying too much about performance at the first go.
      #
      #   project.milestones             # fetches milestones from the database
      #   project.milestones.size        # uses the milestone cache
      #   project.milestones.empty?      # uses the milestone cache
      #   project.milestones.reload.size # fetches milestones from the database
      #   project.milestones             # uses the milestone cache
      #
      # == Eager loading of associations
      #
      # Eager loading is a way to find objects of a certain class and a number of named associations.
      # It is one of the easiest ways to prevent the dreaded N+1 problem in which fetching 100
      # posts that each need to display their author triggers 101 database queries. Through the
      # use of eager loading, the number of queries will be reduced from 101 to 2.
      #
      #   class Post < ActiveEntity::Base
      #     belongs_to :author
      #     has_many   :comments
      #   end
      #
      # Consider the following loop using the class above:
      #
      #   Post.all.each do |post|
      #     puts "Post:            " + post.title
      #     puts "Written by:      " + post.author.name
      #     puts "Last comment on: " + post.comments.first.created_on
      #   end
      #
      # To iterate over these one hundred posts, we'll generate 201 database queries. Let's
      # first just optimize it for retrieving the author:
      #
      #   Post.includes(:author).each do |post|
      #
      # This references the name of the #belongs_to association that also used the <tt>:author</tt>
      # symbol. After loading the posts, +find+ will collect the +author_id+ from each one and load
      # all of the referenced authors with one query. Doing so will cut down the number of queries
      # from 201 to 102.
      #
      # We can improve upon the situation further by referencing both associations in the finder with:
      #
      #   Post.includes(:author, :comments).each do |post|
      #
      # This will load all comments with a single query. This reduces the total number of queries
      # to 3. In general, the number of queries will be 1 plus the number of associations
      # named (except if some of the associations are polymorphic #belongs_to - see below).
      #
      # To include a deep hierarchy of associations, use a hash:
      #
      #   Post.includes(:author, { comments: { author: :gravatar } }).each do |post|
      #
      # The above code will load all the comments and all of their associated
      # authors and gravatars. You can mix and match any combination of symbols,
      # arrays, and hashes to retrieve the associations you want to load.
      #
      # All of this power shouldn't fool you into thinking that you can pull out huge amounts
      # of data with no performance penalty just because you've reduced the number of queries.
      # The database still needs to send all the data to Active Entity and it still needs to
      # be processed. So it's no catch-all for performance problems, but it's a great way to
      # cut down on the number of queries in a situation as the one described above.
      #
      # Since only one table is loaded at a time, conditions or orders cannot reference tables
      # other than the main one. If this is the case, Active Entity falls back to the previously
      # used <tt>LEFT OUTER JOIN</tt> based strategy. For example:
      #
      #   Post.includes([:author, :comments]).where(['comments.approved = ?', true])
      #
      # This will result in a single SQL query with joins along the lines of:
      # <tt>LEFT OUTER JOIN comments ON comments.post_id = posts.id</tt> and
      # <tt>LEFT OUTER JOIN authors ON authors.id = posts.author_id</tt>. Note that using conditions
      # like this can have unintended consequences.
      # In the above example, posts with no approved comments are not returned at all because
      # the conditions apply to the SQL statement as a whole and not just to the association.
      #
      # You must disambiguate column references for this fallback to happen, for example
      # <tt>order: "author.name DESC"</tt> will work but <tt>order: "name DESC"</tt> will not.
      #
      # If you want to load all posts (including posts with no approved comments), then write
      # your own <tt>LEFT OUTER JOIN</tt> query using <tt>ON</tt>:
      #
      #   Post.joins("LEFT OUTER JOIN comments ON comments.post_id = posts.id AND comments.approved = '1'")
      #
      # In this case, it is usually more natural to include an association which has conditions defined on it:
      #
      #   class Post < ActiveEntity::Base
      #     has_many :approved_comments, -> { where(approved: true) }, class_name: 'Comment'
      #   end
      #
      #   Post.includes(:approved_comments)
      #
      # This will load posts and eager load the +approved_comments+ association, which contains
      # only those comments that have been approved.
      #
      # If you eager load an association with a specified <tt>:limit</tt> option, it will be ignored,
      # returning all the associated objects:
      #
      #   class Picture < ActiveEntity::Base
      #     has_many :most_recent_comments, -> { order('id DESC').limit(10) }, class_name: 'Comment'
      #   end
      #
      #   Picture.includes(:most_recent_comments).first.most_recent_comments # => returns all associated comments.
      #
      # Eager loading is supported with polymorphic associations.
      #
      #   class Address < ActiveEntity::Base
      #     belongs_to :addressable, polymorphic: true
      #   end
      #
      # A call that tries to eager load the addressable model
      #
      #   Address.includes(:addressable)
      #
      # This will execute one query to load the addresses and load the addressables with one
      # query per addressable type.
      # For example, if all the addressables are either of class Person or Company, then a total
      # of 3 queries will be executed. The list of addressable types to load is determined on
      # the back of the addresses loaded. This is not supported if Active Entity has to fallback
      # to the previous implementation of eager loading and will raise ActiveEntity::EagerLoadPolymorphicError.
      # The reason is that the parent model's type is a column value so its corresponding table
      # name cannot be put in the +FROM+/+JOIN+ clauses of that query.
      #
      # == Table Aliasing
      #
      # Active Entity uses table aliasing in the case that a table is referenced multiple times
      # in a join. If a table is referenced only once, the standard table name is used. The
      # second time, the table is aliased as <tt>#{reflection_name}_#{parent_table_name}</tt>.
      # Indexes are appended for any more successive uses of the table name.
      #
      #   Post.joins(:comments)
      #   # => SELECT ... FROM posts INNER JOIN comments ON ...
      #   Post.joins(:special_comments) # STI
      #   # => SELECT ... FROM posts INNER JOIN comments ON ... AND comments.type = 'SpecialComment'
      #   Post.joins(:comments, :special_comments) # special_comments is the reflection name, posts is the parent table name
      #   # => SELECT ... FROM posts INNER JOIN comments ON ... INNER JOIN comments special_comments_posts
      #
      # Acts as tree example:
      #
      #   TreeMixin.joins(:children)
      #   # => SELECT ... FROM mixins INNER JOIN mixins childrens_mixins ...
      #   TreeMixin.joins(children: :parent)
      #   # => SELECT ... FROM mixins INNER JOIN mixins childrens_mixins ...
      #                               INNER JOIN parents_mixins ...
      #   TreeMixin.joins(children: {parent: :children})
      #   # => SELECT ... FROM mixins INNER JOIN mixins childrens_mixins ...
      #                               INNER JOIN parents_mixins ...
      #                               INNER JOIN mixins childrens_mixins_2
      #
      # Has and Belongs to Many join tables use the same idea, but add a <tt>_join</tt> suffix:
      #
      #   Post.joins(:categories)
      #   # => SELECT ... FROM posts INNER JOIN categories_posts ... INNER JOIN categories ...
      #   Post.joins(categories: :posts)
      #   # => SELECT ... FROM posts INNER JOIN categories_posts ... INNER JOIN categories ...
      #                              INNER JOIN categories_posts posts_categories_join INNER JOIN posts posts_categories
      #   Post.joins(categories: {posts: :categories})
      #   # => SELECT ... FROM posts INNER JOIN categories_posts ... INNER JOIN categories ...
      #                              INNER JOIN categories_posts posts_categories_join INNER JOIN posts posts_categories
      #                              INNER JOIN categories_posts categories_posts_join INNER JOIN categories categories_posts_2
      #
      # If you wish to specify your own custom joins using ActiveEntity::QueryMethods#joins method, those table
      # names will take precedence over the eager associations:
      #
      #   Post.joins(:comments).joins("inner join comments ...")
      #   # => SELECT ... FROM posts INNER JOIN comments_posts ON ... INNER JOIN comments ...
      #   Post.joins(:comments, :special_comments).joins("inner join comments ...")
      #   # => SELECT ... FROM posts INNER JOIN comments comments_posts ON ...
      #                              INNER JOIN comments special_comments_posts ...
      #                              INNER JOIN comments ...
      #
      # Table aliases are automatically truncated according to the maximum length of table identifiers
      # according to the specific database.
      #
      # == Modules
      #
      # By default, associations will look for objects within the current module scope. Consider:
      #
      #   module MyApplication
      #     module Business
      #       class Firm < ActiveEntity::Base
      #         has_many :clients
      #       end
      #
      #       class Client < ActiveEntity::Base; end
      #     end
      #   end
      #
      # When <tt>Firm#clients</tt> is called, it will in turn call
      # <tt>MyApplication::Business::Client.find_all_by_firm_id(firm.id)</tt>.
      # If you want to associate with a class in another module scope, this can be done by
      # specifying the complete class name.
      #
      #   module MyApplication
      #     module Business
      #       class Firm < ActiveEntity::Base; end
      #     end
      #
      #     module Billing
      #       class Account < ActiveEntity::Base
      #         belongs_to :firm, class_name: "MyApplication::Business::Firm"
      #       end
      #     end
      #   end
      #
      # == Bi-directional associations
      #
      # When you specify an association, there is usually an association on the associated model
      # that specifies the same relationship in reverse. For example, with the following models:
      #
      #    class Dungeon < ActiveEntity::Base
      #      has_many :traps
      #      has_one :evil_wizard
      #    end
      #
      #    class Trap < ActiveEntity::Base
      #      belongs_to :dungeon
      #    end
      #
      #    class EvilWizard < ActiveEntity::Base
      #      belongs_to :dungeon
      #    end
      #
      # The +traps+ association on +Dungeon+ and the +dungeon+ association on +Trap+ are
      # the inverse of each other, and the inverse of the +dungeon+ association on +EvilWizard+
      # is the +evil_wizard+ association on +Dungeon+ (and vice-versa). By default,
      # Active Entity can guess the inverse of the association based on the name
      # of the class. The result is the following:
      #
      #    d = Dungeon.first
      #    t = d.traps.first
      #    d.object_id == t.dungeon.object_id # => true
      #
      # The +Dungeon+ instances +d+ and <tt>t.dungeon</tt> in the above example refer to
      # the same in-memory instance since the association matches the name of the class.
      # The result would be the same if we added +:inverse_of+ to our model definitions:
      #
      #    class Dungeon < ActiveEntity::Base
      #      has_many :traps, inverse_of: :dungeon
      #      has_one :evil_wizard, inverse_of: :dungeon
      #    end
      #
      #    class Trap < ActiveEntity::Base
      #      belongs_to :dungeon, inverse_of: :traps
      #    end
      #
      #    class EvilWizard < ActiveEntity::Base
      #      belongs_to :dungeon, inverse_of: :evil_wizard
      #    end
      #
      # For more information, see the documentation for the +:inverse_of+ option.
      #
      # == Deleting from associations
      #
      # === Dependent associations
      #
      # #has_many, #has_one, and #belongs_to associations support the <tt>:dependent</tt> option.
      # This allows you to specify that associated records should be deleted when the owner is
      # deleted.
      #
      # For example:
      #
      #     class Author
      #       has_many :posts, dependent: :destroy
      #     end
      #     Author.find(1).destroy # => Will destroy all of the author's posts, too
      #
      # The <tt>:dependent</tt> option can have different values which specify how the deletion
      # is done. For more information, see the documentation for this option on the different
      # specific association types. When no option is given, the behavior is to do nothing
      # with the associated records when destroying a record.
      #
      # Note that <tt>:dependent</tt> is implemented using Rails' callback
      # system, which works by processing callbacks in order. Therefore, other
      # callbacks declared either before or after the <tt>:dependent</tt> option
      # can affect what it does.
      #
      # Note that <tt>:dependent</tt> option is ignored for #has_one <tt>:through</tt> associations.
      #
      # === Delete or destroy?
      #
      # #has_many and #has_and_belongs_to_many associations have the methods <tt>destroy</tt>,
      # <tt>delete</tt>, <tt>destroy_all</tt> and <tt>delete_all</tt>.
      #
      # For #has_and_belongs_to_many, <tt>delete</tt> and <tt>destroy</tt> are the same: they
      # cause the records in the join table to be removed.
      #
      # For #has_many, <tt>destroy</tt> and <tt>destroy_all</tt> will always call the <tt>destroy</tt> method of the
      # record(s) being removed so that callbacks are run. However <tt>delete</tt> and <tt>delete_all</tt> will either
      # do the deletion according to the strategy specified by the <tt>:dependent</tt> option, or
      # if no <tt>:dependent</tt> option is given, then it will follow the default strategy.
      # The default strategy is to do nothing (leave the foreign keys with the parent ids set), except for
      # #has_many <tt>:through</tt>, where the default strategy is <tt>delete_all</tt> (delete
      # the join records, without running their callbacks).
      #
      # There is also a <tt>clear</tt> method which is the same as <tt>delete_all</tt>, except that
      # it returns the association rather than the records which have been deleted.
      #
      # === What gets deleted?
      #
      # There is a potential pitfall here: #has_and_belongs_to_many and #has_many <tt>:through</tt>
      # associations have records in join tables, as well as the associated records. So when we
      # call one of these deletion methods, what exactly should be deleted?
      #
      # The answer is that it is assumed that deletion on an association is about removing the
      # <i>link</i> between the owner and the associated object(s), rather than necessarily the
      # associated objects themselves. So with #has_and_belongs_to_many and #has_many
      # <tt>:through</tt>, the join records will be deleted, but the associated records won't.
      #
      # This makes sense if you think about it: if you were to call <tt>post.tags.delete(Tag.find_by(name: 'food'))</tt>
      # you would want the 'food' tag to be unlinked from the post, rather than for the tag itself
      # to be removed from the database.
      #
      # However, there are examples where this strategy doesn't make sense. For example, suppose
      # a person has many projects, and each project has many tasks. If we deleted one of a person's
      # tasks, we would probably not want the project to be deleted. In this scenario, the delete method
      # won't actually work: it can only be used if the association on the join model is a
      # #belongs_to. In other situations you are expected to perform operations directly on
      # either the associated records or the <tt>:through</tt> association.
      #
      # With a regular #has_many there is no distinction between the "associated records"
      # and the "link", so there is only one choice for what gets deleted.
      #
      # With #has_and_belongs_to_many and #has_many <tt>:through</tt>, if you want to delete the
      # associated records themselves, you can always do something along the lines of
      # <tt>person.tasks.each(&:destroy)</tt>.
      #
      # == Type safety with ActiveEntity::AssociationTypeMismatch
      #
      # If you attempt to assign an object to an association that doesn't match the inferred
      # or specified <tt>:class_name</tt>, you'll get an ActiveEntity::AssociationTypeMismatch.
      #
      # == Options
      #
      # All of the association macros can be specialized through options. This makes cases
      # more complex than the simple and guessable ones possible.
      module ClassMethods
        def embedded_in(name, **options)
          reflection = Embeds::Builder::EmbeddedIn.build(self, name, options)
          Reflection.add_reflection self, name, reflection
        end

        def embeds_one(name, **options)
          reflection = Embeds::Builder::EmbedsOne.build(self, name, options)
          Reflection.add_reflection self, name, reflection
        end

        def embeds_many(name, **options)
          reflection = Embeds::Builder::EmbedsMany.build(self, name, options)
          Reflection.add_reflection self, name, reflection
        end

        def association_names
          @association_names ||=
            if !abstract_class?
              reflections.keys.map(&:to_sym)
            else
              []
            end
        end

        def embeds_association_names
          @association_names ||=
            if !abstract_class?
              reflections.select { |_, r| r.embedded? }.keys.map(&:to_sym)
            else
              []
            end
        end
      end
  end
end
