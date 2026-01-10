# frozen_string_literal: true

FactoryBot.define do
  factory :error_group, class: "Faultline::ErrorGroup" do
    sequence(:fingerprint) { |n| Digest::SHA256.hexdigest("error_#{n}") }
    exception_class { "StandardError" }
    sanitized_message { "Something went wrong" }
    file_path { "app/models/user.rb" }
    line_number { 42 }
    method_name { "save" }
    status { "unresolved" }
    first_seen_at { 1.hour.ago }
    last_seen_at { Time.current }
    occurrences_count { 1 }

    trait :resolved do
      status { "resolved" }
      resolved_at { Time.current }
    end

    trait :ignored do
      status { "ignored" }
    end
  end
end
