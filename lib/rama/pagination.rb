# frozen_string_literal: true

class Rama::Pagination
  class CursorPaginator
    attr_reader :scope, :cursor, :limit, :direction

    def initialize(scope, cursor: nil, limit: 25, direction: :forward)
      @scope = scope
      @cursor = cursor
      @limit = [limit, 100].min # Cap at 100 for performance
      @direction = direction
    end

    def paginate
      paginated_scope = apply_cursor_conditions(scope)
      records = paginated_scope.limit(limit + 1).to_a

      {
        records: records.first(limit),
        has_next_page: records.size > limit,
        has_previous_page: cursor.present?,
        next_cursor: next_cursor(records),
        previous_cursor: previous_cursor,
        total_count: estimated_total_count,
      }
    end

    private

    def apply_cursor_conditions(scope)
      return scope if cursor.blank?

      cursor_data = decode_cursor(cursor)
      cursor_value = cursor_data[:value]
      cursor_id = cursor_data[:id]

      if direction == :forward
        # Get records after the cursor
        scope.where(
          "(#{order_column} > ?) OR (#{order_column} = ? AND id > ?)",
          cursor_value, cursor_value, cursor_id,
        )
      else
        # Get records before the cursor
        scope.where(
          "(#{order_column} < ?) OR (#{order_column} = ? AND id < ?)",
          cursor_value, cursor_value, cursor_id,
        ).reverse_order
      end
    end

    def next_cursor(records)
      return nil unless records.size > limit

      last_record = records[limit - 1]
      encode_cursor(last_record)
    end

    def previous_cursor
      return nil if cursor.blank?

      # This would require storing the previous cursor or implementing reverse pagination
      nil
    end

    def encode_cursor(record)
      cursor_data = {
        value: record.public_send(order_column_name),
        id: record.id,
      }
      Base64.urlsafe_encode64(cursor_data.to_json)
    end

    def decode_cursor(cursor)
      JSON.parse(Base64.urlsafe_decode64(cursor)).symbolize_keys
    rescue StandardError
      { value: nil, id: 0 }
    end

    def order_column
      "#{scope.table_name}.#{order_column_name}"
    end

    def order_column_name
      # Default to created_at, but could be configurable
      :created_at
    end

    def estimated_total_count
      # Use table statistics for fast count estimation
      if scope.respond_to?(:estimated_count)
        scope.estimated_count
      else
        # Fallback to actual count for small tables
        scope.count
      end
    end
  end

  class OffsetPaginator
    attr_reader :scope, :page, :per_page

    def initialize(scope, page: 1, per_page: 25)
      @scope = scope
      @page = [page.to_i, 1].max
      @per_page = [[per_page.to_i, 1].max, 100].min
    end

    def paginate
      offset = (page - 1) * per_page
      records = scope.offset(offset).limit(per_page).to_a

      {
        records: records,
        current_page: page,
        per_page: per_page,
        total_pages: total_pages,
        total_count: total_count,
        has_next_page: page < total_pages,
        has_previous_page: page > 1,
      }
    end

    private

    def total_count
      @total_count ||= scope.count
    end

    def total_pages
      (total_count.to_f / per_page).ceil
    end
  end

  # Factory method to choose appropriate paginator
  def self.paginate(scope, strategy: :cursor, **options)
    case strategy
    when :cursor
      CursorPaginator.new(scope, **options).paginate
    when :offset
      OffsetPaginator.new(scope, **options).paginate
    else
      # Auto-select based on scope size
      estimated_count = scope.respond_to?(:estimated_count) ? scope.estimated_count : scope.count

      if estimated_count > 10_000
        CursorPaginator.new(scope, **options).paginate
      else
        OffsetPaginator.new(scope, **options).paginate
      end
    end
  end
end
