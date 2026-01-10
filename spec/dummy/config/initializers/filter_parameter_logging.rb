# frozen_string_literal: true

Rails.application.config.filter_parameters += [:password, :password_confirmation]
