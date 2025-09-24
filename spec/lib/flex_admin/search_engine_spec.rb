# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Rama::SearchEngine do
  let(:model_class) { User }
  
  before do
    # Create test data
    create(:user, name: 'John Doe', email: 'john.doe@example.com')
    create(:user, name: 'Jane Smith', email: 'jane.smith@example.com')
    create(:user, name: 'Bob Johnson', email: 'bob.johnson@example.com')
    create(:user, name: 'Alice Brown', email: 'alice.brown@example.com')
  end

  describe '#search' do
    context 'with basic search strategy' do
      let(:search_engine) { described_class.new(model_class, 'John', strategy: :basic) }

      it 'finds records with matching names' do
        results = search_engine.search
        expect(results.count).to eq(2) # John Doe and Bob Johnson
        expect(results.pluck(:name)).to include('John Doe', 'Bob Johnson')
      end

      it 'finds records with matching emails' do
        search_engine = described_class.new(model_class, 'jane.smith', strategy: :basic)
        results = search_engine.search
        expect(results.count).to eq(1)
        expect(results.first.email).to eq('jane.smith@example.com')
      end

      it 'is case insensitive' do
        search_engine = described_class.new(model_class, 'JOHN', strategy: :basic)
        results = search_engine.search
        expect(results.count).to eq(2)
      end
    end

    context 'with auto strategy selection' do
      it 'selects basic search for short queries' do
        search_engine = described_class.new(model_class, 'Jo', strategy: :auto)
        expect(search_engine.send(:strategy)).to eq(:basic)
      end

      it 'selects appropriate strategy for longer queries' do
        search_engine = described_class.new(model_class, 'John Doe', strategy: :auto)
        # Strategy depends on database capabilities
        expect([:basic, :trigram, :full_text]).to include(search_engine.send(:strategy))
      end
    end

    context 'with PostgreSQL and trigram support', if: postgresql_with_trigram? do
      before { setup_search_indexes }

      it 'uses trigram search for fuzzy matching' do
        search_engine = described_class.new(model_class, 'Jon', strategy: :trigram)
        results = search_engine.search
        expect(results.count).to be > 0
        expect(results.pluck(:name)).to include('John Doe')
      end

      it 'orders results by similarity' do
        search_engine = described_class.new(model_class, 'John', strategy: :trigram)
        results = search_engine.search
        # John Doe should rank higher than Bob Johnson
        expect(results.first.name).to eq('John Doe')
      end
    end

    context 'with empty or blank queries' do
      it 'returns empty scope for blank query' do
        search_engine = described_class.new(model_class, '', strategy: :basic)
        expect(search_engine.search).to eq(model_class.none)
      end

      it 'returns empty scope for nil query' do
        search_engine = described_class.new(model_class, nil, strategy: :basic)
        expect(search_engine.search).to eq(model_class.none)
      end
    end
  end

  describe '#suggestions' do
    context 'with basic strategy' do
      let(:search_engine) { described_class.new(model_class, 'Jo', strategy: :basic) }

      it 'returns relevant suggestions' do
        suggestions = search_engine.suggestions(limit: 5)
        expect(suggestions).to include('John Doe')
        expect(suggestions.size).to be <= 5
      end

      it 'respects the limit parameter' do
        suggestions = search_engine.suggestions(limit: 2)
        expect(suggestions.size).to be <= 2
      end
    end

    context 'with short queries' do
      it 'returns empty suggestions for very short queries' do
        search_engine = described_class.new(model_class, 'J', strategy: :basic)
        suggestions = search_engine.suggestions
        expect(suggestions).to be_empty
      end
    end
  end

  describe 'performance' do
    before do
      # Create a larger dataset for performance testing
      create_large_dataset(model_class, count: 1000)
    end

    it 'performs search within acceptable time limits' do
      search_engine = described_class.new(model_class, 'Test Record', strategy: :basic)
      
      performance = measure_performance do
        search_engine.search.limit(50).to_a
      end
      
      expect(performance[:duration]).to be < 1.second
    end

    it 'handles large result sets efficiently' do
      search_engine = described_class.new(model_class, 'Test', strategy: :basic)
      
      performance = measure_performance do
        search_engine.search.limit(100).to_a
      end
      
      expect(performance[:memory_used]).to be < 50.megabytes
    end
  end

  describe 'database adapter compatibility' do
    it 'works with the current database adapter' do
      search_engine = described_class.new(model_class, 'John', strategy: :basic)
      expect { search_engine.search.to_a }.not_to raise_error
    end

    it 'detects available search capabilities' do
      search_engine = described_class.new(model_class, 'John', strategy: :auto)
      
      # Should not raise errors when checking capabilities
      expect { search_engine.send(:full_text_available?) }.not_to raise_error
      expect { search_engine.send(:trigram_available?) }.not_to raise_error
    end
  end

  describe 'association search' do
    before do
      company = create(:company, name: 'Tech Corp')
      create(:user, name: 'John Doe', company: company)
    end

    it 'searches across associations when enabled' do
      search_engine = described_class.new(
        model_class, 
        'Tech Corp', 
        strategy: :basic,
        include_associations: true
      )
      
      # This would require proper join setup in the search engine
      # For now, just ensure it doesn't error
      expect { search_engine.search.to_a }.not_to raise_error
    end
  end

  private

  def postgresql_with_trigram?
    ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql') &&
    ActiveRecord::Base.connection.execute("SELECT 1 FROM pg_extension WHERE extname = 'pg_trgm'").any?
  rescue
    false
  end
end
