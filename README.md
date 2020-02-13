Active Entity
====

Active Entity is a Rails virtual model solution based on ActiveModel and it's design for Rails 6+.

Active Entity is forked from Active Record by removing all database relates codes, so it nearly no need to learn how to use.

## About Virtual Model

Virtual Model is the model not backed by a database table, usually used as "form model" or "presenter", because it's implement interfaces of Active Model, so you can use it like a normal Active Record model in your Rails app.

## Features

### Attribute declaration

```ruby
class Book < ActiveEntity::Base
  attribute :title, :string
  attribute :tags, :string, array: true, default: []
end
```

Same usage with Active Record, [Learn more](https://api.rubyonrails.org/classes/ActiveRecord/Attributes/ClassMethods.html#method-i-attribute).

One enhancement is `array: true` that transform the attribute to an array that can accept multiple values.

### Nested attributes

Active Entity supports its own variant of nested attributes via the `embeds_one` / `embeds_many` macros. The intention is to be mostly compatible with ActiveRecord's `accepts_nested_attributes_for` functionality.

```ruby
class Holiday < ActiveEntity::Base
  attribute :date, :date
  validates :date, presence: true
end

class HolidaysForm < ActiveEntity::Base
  embeds_many :holidays
  accepts_nested_attributes_for :holidays, reject_if: :all_blank
end
```

### Validations

```ruby
class Book < ActiveEntity::Base
  attribute :title, :string
  validates :title, presence: true
end
```

Supported Active Record validations:

- [acceptance](https://guides.rubyonrails.org/active_record_validations.html#acceptance)
- [confirmation](https://guides.rubyonrails.org/active_record_validations.html#confirmation)
- [exclusion](https://guides.rubyonrails.org/active_record_validations.html#exclusion)
- [format](https://guides.rubyonrails.org/active_record_validations.html#format)
- [inclusion](https://guides.rubyonrails.org/active_record_validations.html#inclusion)
- [length](https://guides.rubyonrails.org/active_record_validations.html#length)
- [numericality](https://guides.rubyonrails.org/active_record_validations.html#numericality)
- [presence](https://guides.rubyonrails.org/active_record_validations.html#presence)
- [absence](https://guides.rubyonrails.org/active_record_validations.html#absence)

[Common validation options](https://guides.rubyonrails.org/active_record_validations.html#common-validation-options) supported too.

#### `subset` validation

Because Active Entity supports array attribute, for some reason, we may want to test values of an array attribute are all included in a given set.

Active Entity provides `subset` validation to achieve that, it usage similar to `inclusion` or `exclusion`

```ruby
class Steak < ActiveEntity::Base
  attribute :side_dishes, :string, array: true, default: []
  validates :side_dishes, subset: { in: %w(chips mashed_potato salad) }
end
```

#### `uniqueness_in_embedding` validation

Active Entity provides `uniqueness_in_embedding` validation to test duplicate nesting virtual record.

Argument `key` is attribute name of nested model, it also supports multiple attributes by given an array.

```ruby
class Category < ActiveEntity::Base
  attribute :name, :string
end

class Reviewer < ActiveEntity::Base
  attribute :first_name, :string
  attribute :last_name, :string
end

class Book < ActiveEntity::Base
  embeds_many :categories
  validates :categories, uniqueness_in_embeds: {key: :name}

  embeds_many :reviewers
  validates :categories, uniqueness_in_embeds: {key: [:first_name, :last_name]}
end
```

### Others

These Active Record feature also available in Active Entity

- [`composed_of`](https://api.rubyonrails.org/classes/ActiveRecord/Aggregations/ClassMethods.html)
- [`enum`](https://api.rubyonrails.org/v5.2.2/classes/ActiveRecord/Enum.html) (You must declare the attribute before using `enum`)
- [`serializable_hash`](https://api.rubyonrails.org/classes/ActiveModel/Serialization.html#method-i-serializable_hash)
- [`serialize`](https://api.rubyonrails.org/classes/ActiveRecord/AttributeMethods/Serialization/ClassMethods.html#method-i-serialize)
- [`store`](https://api.rubyonrails.org/classes/ActiveRecord/Store.html)

#### I18n

Same to [Active Record I18n](https://guides.rubyonrails.org/i18n.html#translations-for-active-record-models), the only different is the root of locale YAML is `active_entity` instead of `activerecord`

#### Read-only attributes

You can use `attr_readonly :title, :author` to prevent assign value to attribute after initialized.

You can use `enable_readonly!` and `disable_readonly!` to control the behavior.

**Important: It's no effect with embeds or array attributes !!!**

## Extending

Most of Active Model plugins are compatible with Active Entity.

You need to include them manually.

Tested extensions:

- [adzap/validates_timeliness](https://github.com/adzap/validates_timeliness)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'activeentity', require: "active_entity/railtie"
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install activeentity
```

## Other awesome gems

- [makandra/active_type](https://github.com/makandra/active_type)

## Contributing

- Fork the project.
- Make your feature addition or bug fix.
- Add tests for it. This is important so I don't break it in a future version unintentionally.
- Commit, do not mess with Rakefile or version (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull)
- Send me a pull request. Bonus points for topic branches.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
