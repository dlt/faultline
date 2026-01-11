# frozen_string_literal: true

# Provide basic Kaminari-like pagination for tests
# since Kaminari is not a dependency of the gem
module PaginationHelper
  def self.setup!
    return if @setup_done

    ActiveRecord::Relation.class_eval do
      def page(num = 1)
        num = num.to_i
        num = 1 if num < 1
        result = offset((num - 1) * 25).limit(25)
        result.define_singleton_method(:per) { |_per_page| self }
        result
      end
    end

    @setup_done = true
  end
end

# Set up pagination support when this file is loaded
PaginationHelper.setup!
