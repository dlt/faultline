# frozen_string_literal: true

Faultline::Engine.routes.draw do
  root to: "error_groups#index"

  resources :error_groups do
    member do
      patch :resolve
      patch :unresolve
      patch :ignore
      post :create_github_issue
    end

    collection do
      post :bulk_action
    end
  end

  resources :error_occurrences, only: [:index, :show]

  resources :performance, only: [:index, :show], constraints: { id: /[^\/]+/ }

  resources :traces, only: [:show] do
    member do
      get :profile
    end
  end

  post "/mcp", to: "mcp#handle"
end
