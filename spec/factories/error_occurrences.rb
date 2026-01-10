# frozen_string_literal: true

FactoryBot.define do
  factory :error_occurrence, class: "Faultline::ErrorOccurrence" do
    association :error_group
    exception_class { "StandardError" }
    message { "Something went wrong" }
    backtrace { ["app/models/user.rb:42:in `save'", "app/controllers/users_controller.rb:10:in `create'"].to_json }
    environment { "test" }
    hostname { "localhost" }
    process_id { "1234" }
    request_method { "POST" }
    request_url { "http://localhost:3000/users" }
    ip_address { "127.0.0.1" }

    trait :with_local_variables do
      local_variables { { "user" => { "id" => 1, "email" => "test@example.com" }, "params" => { "name" => "John" } }.to_json }
    end

    trait :with_user do
      user_id { 1 }
      user_type { "User" }
    end
  end
end
