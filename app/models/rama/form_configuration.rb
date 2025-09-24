# frozen_string_literal: true

class Rama::FormConfiguration < ApplicationRecord
  self.table_name = 'flex_admin_form_configurations'

  has_many :field_configurations, dependent: :destroy, class_name: 'Rama::FieldConfiguration'
  belongs_to :resource_configuration, class_name: 'Rama::ResourceConfiguration', optional: true

  validates :name, presence: true
  validates :model_name, presence: true

  scope :active, -> { where(active: true) }
  scope :for_model, ->(model) { where(model_name: model.to_s) }

  def model_class
    model_name.constantize
  rescue NameError
    nil
  end

  def ordered_fields
    field_configurations.order(:position)
  end

  def to_resource_config
    {
      name: name,
      model: model_class,
      fields: fields_config,
      layout: layout_config || default_layout_config,
    }
  end

  def fields_config
    ordered_fields.each_with_object({}) do |field, config|
      config[field.name] = {
        type: field.field_type.to_sym,
        options: field.options || {},
        position: field.position,
      }
    end
  end

  def add_field(field_type, name, options = {})
    field_configurations.create!(
      field_type: field_type,
      name: name,
      options: options,
      position: next_position,
    )
  end

  def remove_field(field_id)
    field = field_configurations.find(field_id)
    field.destroy
    reorder_fields
  end

  def move_field(field_id, new_position)
    field = field_configurations.find(field_id)
    old_position = field.position

    if new_position < old_position
      # Moving up
      field_configurations.where(position: new_position...old_position)
        .update_all('position = position + 1')
    else
      # Moving down
      field_configurations.where(position: (old_position + 1)..new_position)
        .update_all('position = position - 1')
    end

    field.update!(position: new_position)
  end

  def duplicate(new_name)
    new_config = dup
    new_config.name = new_name
    new_config.active = false
    new_config.save!

    field_configurations.each do |field|
      new_field = field.dup
      new_field.form_configuration = new_config
      new_field.save!
    end

    new_config
  end

  def export_config
    {
      name: name,
      model_name: model_name,
      layout_config: layout_config,
      fields: ordered_fields.map(&:export_config),
    }
  end

  def self.import_config(config_data)
    form_config = create!(
      name: config_data[:name],
      model_name: config_data[:model_name],
      layout_config: config_data[:layout_config],
    )

    config_data[:fields].each_with_index do |field_data, index|
      form_config.field_configurations.create!(
        field_type: field_data[:field_type],
        name: field_data[:name],
        options: field_data[:options],
        validation_rules: field_data[:validation_rules],
        conditional_logic: field_data[:conditional_logic],
        position: index,
      )
    end

    form_config
  end

  private

  def next_position
    (field_configurations.maximum(:position) || -1) + 1
  end

  def reorder_fields
    ordered_fields.each_with_index do |field, index|
      field.update_column(:position, index)
    end
  end

  def default_layout_config
    {
      type: 'single_column',
      spacing: 'normal',
      card_style: true,
    }
  end
end
