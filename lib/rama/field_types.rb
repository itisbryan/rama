# frozen_string_literal: true

module Rama::FieldTypes
  class BaseField
    attr_reader :name, :options, :resource

    def initialize(name, options = {}, resource = nil)
      @name = name
      @options = options
      @resource = resource
    end

    def searchable?
      options[:searchable] == true
    end

    def sortable?
      options[:sortable] != false
    end

    def required?
      options[:required] == true
    end

    def display_value(record)
      value = record.public_send(name)
      format_value(value)
    end

    def form_input_type
      :text_field
    end

    def filter_type
      :string
    end

    protected

    def format_value(value)
      value
    end
  end

  class StringField < BaseField
    def form_input_type
      :text_field
    end

    def filter_type
      :string
    end
  end

  class TextField < BaseField
    def form_input_type
      :text_area
    end

    def filter_type
      :string
    end

    protected

    def format_value(value)
      return nil if value.blank?

      truncate(value, length: options[:truncate] || 100)
    end

    private

    def truncate(text, length:)
      text.length > length ? "#{text[0...length]}..." : text
    end
  end

  class EmailField < StringField
    def form_input_type
      :email_field
    end

    protected

    def format_value(value)
      return nil if value.blank?

      # Use Rails helpers for safe HTML generation
      ActionController::Base.helpers.mail_to(value, value)
    end
  end

  class NumberField < BaseField
    def form_input_type
      :number_field
    end

    def filter_type
      :number_range
    end

    protected

    def format_value(value)
      return nil if value.blank?

      number_with_delimiter(value)
    end

    private

    def number_with_delimiter(number)
      number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end
  end

  class CurrencyField < NumberField
    protected

    def format_value(value)
      return nil if value.blank?

      currency = options[:currency] || 'USD'
      symbol = currency_symbol(currency)
      "#{symbol}#{number_with_delimiter(value)}"
    end

    private

    def currency_symbol(currency)
      case currency.upcase
      when 'USD' then '$'
      when 'EUR' then '€'
      when 'GBP' then '£'
      else currency
      end
    end
  end

  class BooleanField < BaseField
    def form_input_type
      :check_box
    end

    def filter_type
      :boolean
    end

    protected

    def format_value(value)
      value ? '✓' : '✗'
    end
  end

  class DateField < BaseField
    def form_input_type
      :date_field
    end

    def filter_type
      :date_range
    end

    protected

    def format_value(value)
      return nil if value.blank?

      value.strftime(options[:format] || '%Y-%m-%d')
    end
  end

  class DateTimeField < DateField
    def form_input_type
      :datetime_local_field
    end

    protected

    def format_value(value)
      return nil if value.blank?

      value.strftime(options[:format] || '%Y-%m-%d %H:%M')
    end
  end

  class SelectField < BaseField
    def form_input_type
      :select
    end

    def filter_type
      :select
    end

    def collection
      options[:collection] || []
    end

    protected

    def format_value(value)
      return nil if value.blank?

      if collection.is_a?(Hash)
        collection.key(value) || value
      else
        value
      end
    end
  end

  class BelongsToField < BaseField
    def form_input_type
      :select
    end

    def filter_type
      :select
    end

    def association_name
      options[:association] || name
    end

    def display_attribute
      options[:display] || :name
    end

    def collection
      association_class.all
    end

    def display_value(record)
      association = record.public_send(association_name)
      return nil unless association

      association.public_send(display_attribute)
    end

    private

    def association_class(resource_obj, assoc_name)
      return nil unless resource_obj&.model

      association = resource_obj.model.reflect_on_association(assoc_name)
      association&.klass
    end
  end

  class HasManyCountField < BaseField
    def sortable?
      false # Count fields are not directly sortable
    end

    def filter_type
      :number_range
    end

    def association_name
      options[:association] || name.to_s.gsub('_count', '').pluralize
    end

    def display_value(record)
      if record.respond_to?("#{name}_count")
        record.public_send("#{name}_count")
      else
        record.public_send(association_name).count
      end
    end
  end

  class FileField < BaseField
    def form_input_type
      :file_field
    end

    def display_value(record)
      file = record.public_send(name)
      return nil unless file.attached?

      if options[:preview] && file.image?
        image_tag(file, size: options[:preview_size] || '50x50')
      else
        link_to(file.filename, file, target: '_blank', rel: 'noopener')
      end
    end
  end

  class RichTextField < TextField
    def form_input_type
      :rich_text_area
    end

    protected

    def format_value(value)
      return nil if value.blank?

      if value.respond_to?(:to_plain_text)
        truncate(value.to_plain_text, length: options[:truncate] || 100)
      else
        truncate(value.to_s, length: options[:truncate] || 100)
      end
    end
  end

  # Register field types
  Rama.register_field_type(:string, StringField)
  Rama.register_field_type(:text, TextField)
  Rama.register_field_type(:email, EmailField)
  Rama.register_field_type(:number, NumberField)
  Rama.register_field_type(:currency, CurrencyField)
  Rama.register_field_type(:boolean, BooleanField)
  Rama.register_field_type(:date, DateField)
  Rama.register_field_type(:datetime, DateTimeField)
  Rama.register_field_type(:select, SelectField)
  Rama.register_field_type(:belongs_to, BelongsToField)
  Rama.register_field_type(:has_many_count, HasManyCountField)
  Rama.register_field_type(:file, FileField)
  Rama.register_field_type(:rich_text, RichTextField)
end
