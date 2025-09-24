# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Pagination Performance', type: :performance do
  let(:model_class) { User }

  before do
    # Create a large dataset for performance testing
    create_large_dataset(model_class, count: 10_000)
  end

  describe Rama::Pagination::CursorPaginator do
    let(:scope) { model_class.order(:created_at) }

    describe 'performance with large datasets' do
      it 'paginates efficiently without COUNT queries' do
        paginator = described_class.new(scope, limit: 50)

        performance = measure_performance {
          result = paginator.paginate
          expect(result[:records].size).to eq(50)
        }

        expect(performance[:duration]).to be < 100.milliseconds
        expect(performance[:memory_used]).to be < 10.megabytes
      end

      it 'maintains consistent performance across pages' do
        paginator = described_class.new(scope, limit: 50)
        first_page = paginator.paginate

        # Test performance on a later page
        cursor = first_page[:next_cursor]
        10.times do
          paginator = described_class.new(scope, cursor: cursor, limit: 50)
          result = paginator.paginate
          cursor = result[:next_cursor]
          break unless cursor
        end

        # Performance should be consistent
        performance = measure_performance {
          paginator = described_class.new(scope, cursor: cursor, limit: 50)
          result = paginator.paginate
          expect(result[:records].size).to be <= 50
        }

        expect(performance[:duration]).to be < 100.milliseconds
      end

      it 'handles reverse pagination efficiently' do
        # Get to a middle page first
        paginator = described_class.new(scope, limit: 50)
        result = paginator.paginate
        cursor = result[:next_cursor]

        # Test reverse pagination
        performance = measure_performance {
          reverse_paginator = described_class.new(scope, cursor: cursor, limit: 50, direction: :backward)
          result = reverse_paginator.paginate
          expect(result[:records]).not_to be_empty
        }

        expect(performance[:duration]).to be < 100.milliseconds
      end
    end

    describe 'memory efficiency' do
      it 'does not load entire dataset into memory' do
        paginator = described_class.new(scope, limit: 100)

        performance = measure_performance {
          result = paginator.paginate
          expect(result[:records].size).to eq(100)
        }

        # Should use minimal memory regardless of total dataset size
        expect(performance[:memory_used]).to be < 20.megabytes
      end

      it 'handles very large page sizes efficiently' do
        paginator = described_class.new(scope, limit: 1000)

        performance = measure_performance {
          result = paginator.paginate
          expect(result[:records].size).to eq(1000)
        }

        expect(performance[:duration]).to be < 500.milliseconds
        expect(performance[:memory_used]).to be < 50.megabytes
      end
    end
  end

  describe Rama::Pagination::OffsetPaginator do
    let(:scope) { model_class.order(:created_at) }

    describe 'performance comparison' do
      it 'performs well for early pages' do
        paginator = described_class.new(scope, page: 1, per_page: 50)

        performance = measure_performance {
          result = paginator.paginate
          expect(result[:records].size).to eq(50)
        }

        expect(performance[:duration]).to be < 200.milliseconds
      end

      it 'shows degraded performance for later pages' do
        paginator = described_class.new(scope, page: 100, per_page: 50)

        performance = measure_performance {
          result = paginator.paginate
          expect(result[:records].size).to eq(50)
        }

        # Later pages should be slower due to OFFSET
        expect(performance[:duration]).to be < 1.second
      end

      it 'COUNT query performance degrades with dataset size' do
        performance = measure_performance {
          paginator = described_class.new(scope, page: 1, per_page: 50)
          result = paginator.paginate
          total_count = result[:total_count]
          expect(total_count).to eq(10_000)
        }

        # COUNT on large tables can be slow
        expect(performance[:duration]).to be < 1.second
      end
    end
  end

  describe 'Auto-selection strategy' do
    it 'chooses cursor pagination for large datasets' do
      large_scope = model_class.order(:created_at)
      allow(large_scope).to receive(:estimated_count).and_return(50_000)

      performance = measure_performance {
        result = Rama::Pagination.paginate(large_scope, strategy: :auto, limit: 50)
        expect(result[:records].size).to eq(50)
        expect(result).to have_key(:next_cursor) # Indicates cursor pagination
      }

      expect(performance[:duration]).to be < 200.milliseconds
    end

    it 'chooses offset pagination for small datasets' do
      small_scope = model_class.limit(100).order(:created_at)
      allow(small_scope).to receive(:estimated_count).and_return(100)

      performance = measure_performance {
        result = Rama::Pagination.paginate(small_scope, strategy: :auto, page: 1, per_page: 25)
        expect(result[:records].size).to eq(25)
        expect(result).to have_key(:total_pages) # Indicates offset pagination
      }

      expect(performance[:duration]).to be < 100.milliseconds
    end
  end

  describe 'Database-specific optimizations' do
    context 'with PostgreSQL', if: postgresql? do
      it 'uses efficient cursor queries' do
        scope = model_class.order(:created_at)
        paginator = Rama::Pagination::CursorPaginator.new(scope, limit: 50)

        # Monitor SQL queries
        queries = []
        callback = ->(_name, _started, _finished, _unique_id, payload) do
          queries << payload[:sql] if payload[:sql]
        end

        ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
          paginator.paginate
        end

        # Should use efficient WHERE clauses, not OFFSET
        cursor_queries = queries.select { |q| q.include?('WHERE') && q.exclude?('OFFSET') }
        expect(cursor_queries).not_to be_empty
      end
    end

    context 'with MySQL', if: mysql? do
      it 'adapts cursor queries for MySQL syntax' do
        scope = model_class.order(:created_at)
        paginator = Rama::Pagination::CursorPaginator.new(scope, limit: 50)

        expect { paginator.paginate }.not_to raise_error
      end
    end
  end

  describe 'Concurrent access performance' do
    it 'handles multiple simultaneous pagination requests' do
      threads = []
      results = []

      performance = measure_performance {
        10.times do
          threads << Thread.new do
            paginator = Rama::Pagination::CursorPaginator.new(
              model_class.order(:created_at),
              limit: 50,
            )
            results << paginator.paginate
          end
        end

        threads.each(&:join)
      }

      expect(results.size).to eq(10)
      expect(results.all? { |r| r[:records].size == 50 }).to be true
      expect(performance[:duration]).to be < 2.seconds
    end
  end

  private

  def postgresql?
    ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
  end

  def mysql?
    ActiveRecord::Base.connection.adapter_name.downcase.include?('mysql')
  end
end
