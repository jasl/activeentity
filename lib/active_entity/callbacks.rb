# frozen_string_literal: true

module ActiveEntity
  # = Active Entity \Callbacks
  #
  # \Callbacks are hooks into the life cycle of an Active Entity object that allow you to trigger logic
  # before or after a change in the object state. This can be used to make sure that associated and
  # dependent objects are deleted when {ActiveEntity::Base#destroy}[rdoc-ref:Persistence#destroy] is called (by overwriting +before_destroy+) or
  # to massage attributes before they're validated (by overwriting +before_validation+).
  # As an example of the callbacks initiated, consider the {ActiveEntity::Base#save}[rdoc-ref:Persistence#save] call for a new record:
  #
  # * (1) <tt>before_validation</tt>
  # * (-) <tt>validate</tt>
  # * (2) <tt>after_validation</tt>
  #
  # Also, an <tt>after_rollback</tt> callback can be configured to be triggered whenever a rollback is issued.
  # Check out ActiveEntity::Transactions for more details about <tt>after_commit</tt> and
  # <tt>after_rollback</tt>.
  #
  # Additionally, an <tt>after_touch</tt> callback is triggered whenever an
  # object is touched.
  #
  # Lastly an <tt>after_find</tt> and <tt>after_initialize</tt> callback is triggered for each object that
  # is found and instantiated by a finder, with <tt>after_initialize</tt> being triggered after new objects
  # are instantiated as well.
  #
  # There are nineteen callbacks in total, which give a lot of control over how to react and prepare for each state in the
  # Active Entity life cycle. The sequence for calling {ActiveEntity::Base#save}[rdoc-ref:Persistence#save] for an existing record is similar,
  # except that each <tt>_create</tt> callback is replaced by the corresponding <tt>_update</tt> callback.
  #
  # Examples:
  #   class CreditCard < ActiveEntity::Base
  #     # Strip everything but digits, so the user can specify "555 234 34" or
  #     # "5552-3434" and both will mean "55523434"
  #     before_validation(on: :create) do
  #       self.number = number.gsub(/[^0-9]/, "") if attribute_present?("number")
  #     end
  #   end
  #
  #   class Subscription < ActiveEntity::Base
  #     before_create :record_signup
  #
  #     private
  #       def record_signup
  #         self.signed_up_on = Date.today
  #       end
  #   end
  #
  #   class Firm < ActiveEntity::Base
  #     # Disables access to the system, for associated clients and people when the firm is destroyed
  #     before_destroy { |record| Person.where(firm_id: record.id).update_all(access: 'disabled')   }
  #     before_destroy { |record| Client.where(client_of: record.id).update_all(access: 'disabled') }
  #   end
  #
  # == Inheritable callback queues
  #
  # Besides the overwritable callback methods, it's also possible to register callbacks through the
  # use of the callback macros. Their main advantage is that the macros add behavior into a callback
  # queue that is kept intact through an inheritance hierarchy.
  #
  #   class Topic < ActiveEntity::Base
  #     before_destroy :destroy_author
  #   end
  #
  #   class Reply < Topic
  #     before_destroy :destroy_readers
  #   end
  #
  # When <tt>Topic#destroy</tt> is run only +destroy_author+ is called. When <tt>Reply#destroy</tt> is
  # run, both +destroy_author+ and +destroy_readers+ are called.
  #
  # *IMPORTANT:* In order for inheritance to work for the callback queues, you must specify the
  # callbacks before specifying the associations. Otherwise, you might trigger the loading of a
  # child before the parent has registered the callbacks and they won't be inherited.
  #
  # == Types of callbacks
  #
  # There are three types of callbacks accepted by the callback macros: method references (symbol), callback objects,
  # inline methods (using a proc). Method references and callback objects are the recommended approaches,
  # inline methods using a proc are sometimes appropriate (such as for creating mix-ins).
  #
  # The method reference callbacks work by specifying a protected or private method available in the object, like this:
  #
  #   class Topic < ActiveEntity::Base
  #     before_destroy :delete_parents
  #
  #     private
  #       def delete_parents
  #         self.class.delete_by(parent_id: id)
  #       end
  #   end
  #
  # The callback objects have methods named after the callback called with the record as the only parameter, such as:
  #
  #   class BankAccount < ActiveEntity::Base
  #     before_save      EncryptionWrapper.new
  #     after_save       EncryptionWrapper.new
  #     after_initialize EncryptionWrapper.new
  #   end
  #
  #   class EncryptionWrapper
  #     def before_save(record)
  #       record.credit_card_number = encrypt(record.credit_card_number)
  #     end
  #
  #     def after_save(record)
  #       record.credit_card_number = decrypt(record.credit_card_number)
  #     end
  #
  #     alias_method :after_initialize, :after_save
  #
  #     private
  #       def encrypt(value)
  #         # Secrecy is committed
  #       end
  #
  #       def decrypt(value)
  #         # Secrecy is unveiled
  #       end
  #   end
  #
  # So you specify the object you want to be messaged on a given callback. When that callback is triggered, the object has
  # a method by the name of the callback messaged. You can make these callbacks more flexible by passing in other
  # initialization data such as the name of the attribute to work with:
  #
  #   class BankAccount < ActiveEntity::Base
  #     before_save      EncryptionWrapper.new("credit_card_number")
  #     after_save       EncryptionWrapper.new("credit_card_number")
  #     after_initialize EncryptionWrapper.new("credit_card_number")
  #   end
  #
  #   class EncryptionWrapper
  #     def initialize(attribute)
  #       @attribute = attribute
  #     end
  #
  #     def before_save(record)
  #       record.send("#{@attribute}=", encrypt(record.send("#{@attribute}")))
  #     end
  #
  #     def after_save(record)
  #       record.send("#{@attribute}=", decrypt(record.send("#{@attribute}")))
  #     end
  #
  #     alias_method :after_initialize, :after_save
  #
  #     private
  #       def encrypt(value)
  #         # Secrecy is committed
  #       end
  #
  #       def decrypt(value)
  #         # Secrecy is unveiled
  #       end
  #   end
  #
  # == <tt>before_validation*</tt> returning statements
  #
  # If the +before_validation+ callback throws +:abort+, the process will be
  # aborted and {ActiveEntity::Base#save}[rdoc-ref:Persistence#save] will return +false+.
  # If {ActiveEntity::Base#save!}[rdoc-ref:Persistence#save!] is called it will raise an ActiveEntity::RecordInvalid exception.
  # Nothing will be appended to the errors object.
  #
  # == Canceling callbacks
  #
  # If a <tt>before_*</tt> callback throws +:abort+, all the later callbacks and
  # the associated action are cancelled.
  # Callbacks are generally run in the order they are defined, with the exception of callbacks defined as
  # methods on the model, which are called last.
  #
  # == Ordering callbacks
  #
  # Sometimes application code requires that callbacks execute in a specific order. For example, a +before_destroy+
  # callback (+log_children+ in this case) should be executed before records in the +children+ association are destroyed by the
  # <tt>dependent: :destroy</tt> option.
  #
  # Let's look at the code below:
  #
  #   class Topic < ActiveEntity::Base
  #     has_many :children, dependent: :destroy
  #
  #     before_destroy :log_children
  #
  #     private
  #       def log_children
  #         # Child processing
  #       end
  #   end
  #
  # In this case, the problem is that when the +before_destroy+ callback is executed, records in the +children+ association no
  # longer exist because the {ActiveEntity::Base#destroy}[rdoc-ref:Persistence#destroy] callback was executed first.
  # You can use the +prepend+ option on the +before_destroy+ callback to avoid this.
  #
  #   class Topic < ActiveEntity::Base
  #     has_many :children, dependent: :destroy
  #
  #     before_destroy :log_children, prepend: true
  #
  #     private
  #       def log_children
  #         # Child processing
  #       end
  #   end
  #
  # This way, the +before_destroy+ is executed before the <tt>dependent: :destroy</tt> is called, and the data is still available.
  #
  # Also, there are cases when you want several callbacks of the same type to
  # be executed in order.
  #
  # For example:
  #
  #   class Topic < ActiveEntity::Base
  #     has_many :children
  #
  #     after_save :log_children
  #     after_save :do_something_else
  #
  #     private
  #
  #     def log_children
  #       # Child processing
  #     end
  #
  #     def do_something_else
  #       # Something else
  #     end
  #   end
  #
  # In this case the +log_children+ is executed before +do_something_else+.
  # The same applies to all non-transactional callbacks.
  #
  # As seen below, in case there are multiple transactional callbacks the order
  # is reversed.
  #
  # For example:
  #
  #   class Topic < ActiveEntity::Base
  #     has_many :children
  #
  #     after_commit :log_children
  #     after_commit :do_something_else
  #
  #     private
  #
  #     def log_children
  #       # Child processing
  #     end
  #
  #     def do_something_else
  #       # Something else
  #     end
  #   end
  #
  # In this case the +do_something_else+ is executed before +log_children+.
  #
  # == \Transactions
  #
  # The entire callback chain of a {#save}[rdoc-ref:Persistence#save], {#save!}[rdoc-ref:Persistence#save!],
  # or {#destroy}[rdoc-ref:Persistence#destroy] call runs within a transaction. That includes <tt>after_*</tt> hooks.
  # If everything goes fine a +COMMIT+ is executed once the chain has been completed.
  #
  # If a <tt>before_*</tt> callback cancels the action a +ROLLBACK+ is issued. You
  # can also trigger a +ROLLBACK+ raising an exception in any of the callbacks,
  # including <tt>after_*</tt> hooks. Note, however, that in that case the client
  # needs to be aware of it because an ordinary {#save}[rdoc-ref:Persistence#save] will raise such exception
  # instead of quietly returning +false+.
  #
  # == Debugging callbacks
  #
  # The callback chain is accessible via the <tt>_*_callbacks</tt> method on an object. Active Model \Callbacks support
  # <tt>:before</tt>, <tt>:after</tt> and <tt>:around</tt> as values for the <tt>kind</tt> property. The <tt>kind</tt> property
  # defines what part of the chain the callback runs in.
  #
  # To find all callbacks in the +before_save+ callback chain:
  #
  #   Topic._save_callbacks.select { |cb| cb.kind.eql?(:before) }
  #
  # Returns an array of callback objects that form the +before_save+ chain.
  #
  # To further check if the before_save chain contains a proc defined as <tt>rest_when_dead</tt> use the <tt>filter</tt> property of the callback object:
  #
  #   Topic._save_callbacks.select { |cb| cb.kind.eql?(:before) }.collect(&:filter).include?(:rest_when_dead)
  #
  # Returns true or false depending on whether the proc is contained in the +before_save+ callback chain on a Topic model.
  #
  module Callbacks
    extend ActiveSupport::Concern

    CALLBACKS = [
      :after_initialize, :before_validation, :after_validation
    ]

    module ClassMethods
      include ActiveModel::Callbacks

      ##
      # :method: after_initialize
      #
      # :call-seq: after_initialize(*args, &block)
      #
      # Registers a callback to be called after a record is instantiated. See
      # ActiveEntity::Callbacks for more information.
    end

    included do
      include ActiveModel::Validations::Callbacks

      define_model_callbacks :initialize, only: :after
    end
  end
end
