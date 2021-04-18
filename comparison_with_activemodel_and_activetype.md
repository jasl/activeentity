# Comparison with ActiveModel and ActiveType

## In most simple cases use ActiveModel is enough

You can make your "BaseFormObject":

```ruby
class BaseFormObject
  # Acts as Active Model
  # includes Rails integration and Validation
  include ActiveModel::Base
  
  # Enable Attribute API 
  # <https://api.rubyonrails.org/classes/ActiveRecord/Attributes/ClassMethods.html#method-i-attribute>
  # <https://bigbinary.com/blog/rails-5-attributes-api>
  include ActiveModel::Attributes
  
  # (Optional) Enable dirty tracking
  # <https://api.rubyonrails.org/classes/ActiveModel/Dirty.html>
  include ActiveModel::Dirty
  
  # (Optional) Enable serialization
  # e.g. dump attributes to hash or JSON
  include ActiveModel::Serialization
end
```

Usage:

```ruby
class Book < BaseFormObject
  attribute :title, :string
  attribute :score, :integer
  
  validates :title, presence: true
  validates :score, numericality: { only_integer: true }
end
```

It basically acts as Active Record model.

In addition, some Active Record model plugins (e.g [adzap/validates_timeliness](https://github.com/adzap/validates_timeliness)) which not save or update database will compatible with the `BaseFormObject`.

## ActiveType

It has extra features:

- Derivable from an exists Active Record model
- Nested attributes

It:

- Built upon `ActiveRecord::Model` with patches to made it table-less
- Doesn't reuse Active Model Attribute API, Dirty and other components
- Active maintain

## ActiveEntity

It has extra features:

- Nested attributes (I call it embedded models)
- Port PG-only feature typed array attribute.
- Extra useful validations

It:

- Forked from Active Record and removing all database relates codes
  - Initially for the author personal usage (such as [Flow Core](https://github.com/rails-engine/flow_core), [Form Core](https://github.com/rails-engine/form_core), [Script Core](https://github.com/rails-engine/script_core)) Less reliable because tests are not ported
- Reuse Active Model features, only few part such as "Nested attributes" are written by the author
    - More similar to Active Record
- Less active maintain, but issue will be reply quickly

## Extra read: What is Active Model

Not all business objects are backed with database, and modeling them is an essential thing for complex applications.

### Plain Ordinary Ruby Object

you can just define a `class` to do that.

```ruby
class Post
  attr_reader :title, :body
  
  # Initializer, attribute writers, methods, etc.
end
```

But we're on Rails, compared to Active Record model, it's lacking:

- Typed attributes
- Validation
- Integrate with Rails, the most part is integrate with Strong parameter, form helpers and I18n

### ActiveModel::Base

Since Rails 4, Active Record has extracted the Rails integration layer called Active Model, it defined essential interfaces that how controller and view helpers can interact with the model.

Many people don't know Active Model because lacking guide, actually it has a WIP one, and it's not easy to be found: <https://guides.rubyonrails.org/active_model_basics.html>.

I recommend read it first, here I want to explain what features contains in `ActiveModel::Model`

```ruby
  module Model
    # It's a Mixin
    extend ActiveSupport::Concern
    
    # Provides `write_attribute`, `read_attribute` and `assign_attributes` methods as unify attribute accessor,
    # other extensions will depend on this
    include ActiveModel::AttributeAssignment
    # Validation DSL (e.g `validates :title, presence: true`), same as ActiveRecord validations
    include ActiveModel::Validations
    # Interfaces of how to interact with URL helpers and rendering helpers
    include ActiveModel::Conversion

    included do
      # Reflection of the model name
      extend ActiveModel::Naming
      # Interfaces of how to interact with I18n
      extend ActiveModel::Translation
    end

    # Initializes a new model with the given +params+.
    #
    #   class Person
    #     include ActiveModel::Model
    #     attr_accessor :name, :age
    #   end
    #
    #   person = Person.new(name: 'bob', age: '18')
    #   person.name # => "bob"
    #   person.age  # => "18"
    def initialize(attributes = {})
      assign_attributes(attributes) if attributes

      super()
    end

    # Indicates if the model is persisted. Default is +false+.
    #
    #  class Person
    #    include ActiveModel::Model
    #    attr_accessor :id, :name
    #  end
    #
    #  person = Person.new(id: 1, name: 'bob')
    #  person.persisted? # => false
    def persisted?
      false
    end
  end
end
```

Including `ActiveModel::Model` to a class it will get:

- Validation
- Integrate with Rails, the most part is integrate with Strong parameter, form helpers and I18n

Still lacking

- Typed attributes

#### Attribute API, the hidden jewel in Active Model

Since Rails 5, attribute API was made public and moved to Active Model,
you can use it to define attributes with type.

See <https://api.rubyonrails.org/classes/ActiveRecord/Attributes/ClassMethods.html#method-i-attribute> and <https://bigbinary.com/blog/rails-5-attributes-api> for detail.

To enable it, just `include ActiveModel::Attributes`.
