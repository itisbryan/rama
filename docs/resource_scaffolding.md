# Resource Scaffolding

Rama provides a powerful generator to automatically create resource files for your existing models, complete with intelligent defaults for filters, search, and actions.

## Table of Contents
- [Overview](#overview)
- [Usage](#usage)
- [Features](#features)
- [Customization](#customization)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)

## Overview

The `rama:resources:scaffolds` generator analyzes your Rails models and creates corresponding Rama resource files with sensible defaults. It automatically detects:

- Model attributes
- Boolean fields (as toggle filters)
- Enums (as select filters)
- Scopes (as filterable options)
- Associations
- Timestamps

## Usage

### Basic Usage

Generate resources for all models in your application:

```bash
rails g rama:resources:scaffolds
```

### Generate for Specific Models

Generate resources only for specific models:

```bash
rails g rama:resources:scaffolds User Product Order
```

### Options

- `--skip=Model1,Model2`: Skip specific models
- `--only=Model1,Model2`: Only generate for specific models
- `--force`: Overwrite existing files

Example:

```bash
rails g rama:resources:scaffolds --skip=User,Admin --force
```

## Features

### Automatic Field Detection

The generator automatically detects and configures:

- **Standard Fields**: All database columns
- **Boolean Fields**: As toggle filters
- **Enums**: As select dropdowns
- **Timestamps**: Formatted nicely in index views
- **Associations**: As searchable fields

### Generated Filters

For each model, the generator creates appropriate filters:

```ruby
# Boolean filter
filter :active, as: :boolean

# Enum filter
filter :status, as: :select, collection: ['draft', 'published', 'archived']

# Scope filter
filter :recent, as: :boolean, label: "Recently Updated"
```

### Search Configuration

Full-text search is automatically configured for all searchable fields:

```ruby
search do
  query do |query, term|
    query.where("name ILIKE :term OR email ILIKE :term", term: "%#{term}%")
  end
end
```

## Customization

### Customizing the Generated Resource

After generation, you can customize the resource file located at `app/resources/`. For example:

```ruby
class UserResource < Rama::Resource
  # Customize index columns
  index_columns :id, :name, :email, :role, :created_at
  
  # Custom form fields
  form do |f|
    f.input :name
    f.input :email
    f.input :role, as: :select, collection: User.roles.keys
  end
  
  # Add custom actions
  action :export_csv, only: :collection do
    # Export logic here
  end
end
```

### Regenerating Resources

To regenerate a resource:

```bash
rails g rama:resources:scaffolds User --force
```

## Advanced Usage

### Custom Templates

You can create custom templates by copying the default template and modifying it:

```bash
mkdir -p lib/templates/rama/resource
cp $(bundle show rama)/lib/generators/rama/resources/templates/resource.rb.erb lib/templates/rama/resource/
```

### Hooks

Add custom code to run before or after generation by creating an initializer:

```ruby
# config/initializers/rama_generators.rb
Rails.application.config.after_initialize do
  Rama::Generators::ResourcesGenerator.class_eval do
    def after_generate
      # Custom code here
    end
  end
end
```

## Troubleshooting

### Missing Models

If a model can't be found, ensure:

1. The model is in the autoload path
2. The model inherits from `ApplicationRecord`
3. The model file follows Rails naming conventions

### Performance Issues

For large applications, consider generating resources in smaller batches:

```bash
rails g rama:resources:scaffolds User Product Category
rails g rama:resources:scaffolds Order OrderItem Payment
```

### Customizing Views

To customize the generated views, copy the default views and modify them:

```bash
rails g rama:views
```

## Best Practices

1. **Review Generated Code**: Always review the generated files
2. **Version Control**: Commit generated files to version control
3. **Document Customizations**: Add comments for any custom logic
4. **Test**: Add tests for any custom functionality
