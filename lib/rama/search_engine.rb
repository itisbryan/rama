# frozen_string_literal: true

class Rama::SearchEngine
  attr_reader :model_class, :query, :strategy, :options

  def initialize(model_class, query, strategy: :auto, **options)
    @model_class = model_class
    @query = query.to_s.strip
    @strategy = determine_strategy(strategy)
    @options = options
  end

  def search
    return model_class.none if query.blank?

    case strategy
    when :full_text
      full_text_search
    when :trigram
      trigram_search
    when :basic, :elasticsearch
      if strategy == :elasticsearch
        elasticsearch_search
      else
        basic_search
      end
    else
      basic_search
    end
  end

  def suggestions(limit: 10)
    return [] if query.blank? || query.length < 2

    case strategy
    when :full_text
      full_text_suggestions(limit)
    when :trigram
      trigram_suggestions(limit)
    else
      basic_suggestions(limit)
    end
  end

  private

  def determine_strategy(requested_strategy)
    return requested_strategy unless requested_strategy == :auto

    return :basic if query.length < 3

    if full_text_available?
      :full_text
    elsif trigram_available?
      :trigram
    else
      :basic
    end
  end

  def full_text_available?
    model_class.connection.adapter_name.downcase.include?('postgresql') &&
      searchable_columns.any? { |col| has_full_text_index?(col) }
  end

  def trigram_available?
    model_class.connection.adapter_name.downcase.include?('postgresql') &&
      extension_available?('pg_trgm')
  end

  def elasticsearch_available?
    defined?(Elasticsearch) && model_class.respond_to?(:search)
  end

  def full_text_search
    search_vector_column = detect_search_vector_column

    if search_vector_column
      model_class.where(
        "#{search_vector_column} @@ plainto_tsquery('english', ?)",
        query,
      ).order(
        Arel.sql("ts_rank(#{search_vector_column}, plainto_tsquery('english', ?)) DESC"),
        query,
      )
    else
      # Fallback to basic search if no search vector found
      basic_search
    end
  end

  def trigram_search
    conditions = searchable_columns.map { |column|
      "similarity(#{column}, ?) > 0.3"
    }

    order_clause = searchable_columns.map { |column|
      "similarity(#{column}, ?)"
    }.join(', ')

    model_class.where(
      conditions.join(' OR '),
      *([query] * conditions.size),
    ).order(
      Arel.sql("GREATEST(#{order_clause}) DESC"),
      *([query] * searchable_columns.size),
    )
  end

  def basic_search
    conditions = searchable_columns.map { |column|
      if model_class.connection.adapter_name.downcase.include?('postgresql')
        "#{column} ILIKE ?"
      else
        "#{column} LIKE ?"
      end
    }

    model_class.where(
      conditions.join(' OR '),
      *(["%#{query}%"] * conditions.size),
    )
  end

  def elasticsearch_search
    return basic_search unless elasticsearch_available?

    model_class.search(
      query: {
        multi_match: {
          query: query,
          fields: searchable_columns,
          type: 'best_fields',
          fuzziness: 'AUTO',
        },
      },
      highlight: {
        fields: searchable_columns.index_with { |_col| {} },
      },
    )
  end

  def full_text_suggestions(limit)
    search_vector_column = detect_search_vector_column
    return [] unless search_vector_column

    model_class.where(
      "#{search_vector_column} @@ plainto_tsquery('english', ?)",
      query,
    ).limit(limit)
      .pluck(*suggestion_columns)
      .map { |values| format_suggestion(values) }
  end

  def trigram_suggestions(limit)
    suggestions = []

    searchable_columns.each do |column|
      results = model_class.where(
        "similarity(#{column}, ?) > 0.1",
        query,
      ).order(
        Arel.sql("similarity(#{column}, ?) DESC"),
        query,
      ).limit(limit)
        .pluck(column)
        .compact
        .uniq

      suggestions.concat(results)
    end

    suggestions.uniq.first(limit)
  end

  def basic_suggestions(limit)
    suggestions = []

    searchable_columns.each do |column|
      like_pattern = model_class.connection.adapter_name.downcase.include?('postgresql') ? 'ILIKE' : 'LIKE'

      results = model_class.where(
        "#{column} #{like_pattern} ?",
        "%#{query}%",
      ).limit(limit)
        .pluck(column)
        .compact
        .uniq

      suggestions.concat(results)
    end

    suggestions.uniq.first(limit)
  end

  def searchable_columns
    @searchable_columns ||= detect_searchable_columns
  end

  def detect_searchable_columns
    columns = []

    # Add string and text columns
    searchable_types = [:string, :text].freeze
    model_class.columns.each do |column|
      columns << "#{model_class.table_name}.#{column.name}" if searchable_types.include?(column.type)
    end

    # Add searchable association columns
    if options[:include_associations]
      model_class.reflect_on_all_associations(:belongs_to).each do |assoc|
        columns << "#{assoc.table_name}.name" if assoc.klass.column_names.include?('name')
      end
    end

    columns
  end

  def extract_column_name(column_string)
    return nil unless column_string

    parts = column_string.split('.')
    parts.last&.to_sym
  end

  def suggestion_columns
    base_columns = [:id]

    # Add display columns
    base_columns << if model_class.column_names.include?('name')
                      :name
                    elsif model_class.column_names.include?('title')
                      :title
                    else
                      extract_column_name(searchable_columns.first)
                    end

    base_columns.compact
  end

  def format_suggestion(values)
    return values.first if values.size == 1

    {
      id: values.first,
      text: values[1..].join(' - '),
    }
  end

  def detect_search_vector_column
    # Look for common search vector column names
    ['search_vector', 'search_data', 'searchable_text'].find do |col_name|
      model_class.column_names.include?(col_name)
    end
  end

  def has_full_text_index?(column)
    # Check if column has a GIN index (PostgreSQL full-text search)
    indexes = model_class.connection.indexes(model_class.table_name)
    indexes.any? do |index|
      index.using == :gin && index.columns.include?(column.split('.').last)
    end
  end

  def extension_available?(extension_name)
    result = model_class.connection.execute(
      "SELECT 1 FROM pg_extension WHERE extname = '#{extension_name}'",
    )
    result.any?
  rescue StandardError
    false
  end
end
