# frozen_string_literal: true

FactoryBot.define do
  factory :error_context, class: "Faultline::ErrorContext" do
    association :error_occurrence
    sequence(:key) { |n| "context_key_#{n}" }
    value { '{"foo": "bar"}' }

    trait :with_array_value do
      value { '["item1", "item2", "item3"]' }
    end

    trait :with_string_value do
      value { "plain string value" }
    end
  end
end
