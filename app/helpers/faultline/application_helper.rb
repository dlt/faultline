# frozen_string_literal: true

module Faultline
  module ApplicationHelper
    def status_badge_class(status)
      case status
      when "unresolved"
        "bg-red-100 text-red-800"
      when "resolved"
        "bg-green-100 text-green-800"
      when "ignored"
        "bg-gray-100 text-gray-800"
      else
        "bg-gray-100 text-gray-800"
      end
    end

    def time_ago_in_words_short(time)
      return "never" unless time

      seconds = (Time.current - time).to_i

      case seconds
      when 0..59 then "#{seconds}s"
      when 60..3599 then "#{seconds / 60}m"
      when 3600..86399 then "#{seconds / 3600}h"
      else "#{seconds / 86400}d"
      end
    end

    def highlight_ruby(code)
      return "" if code.blank?

      highlighted = h(code)

      # Comments
      highlighted = highlighted.gsub(/(#.*)$/, '<span class="text-gray-400 italic">\1</span>')

      # Strings (double and single quoted)
      highlighted = highlighted.gsub(/(&quot;.*?&quot;|&#39;.*?&#39;|".*?"|'.*?')/, '<span class="text-emerald-600">\1</span>')

      # Symbols
      highlighted = highlighted.gsub(/(:[\w_]+)/, '<span class="text-purple-600">\1</span>')

      # Keywords
      keywords = %w[def end class module if else elsif unless case when then do begin rescue ensure raise return yield while until for break next retry self true false nil and or not in]
      keywords.each do |kw|
        highlighted = highlighted.gsub(/\b(#{kw})\b/, '<span class="text-rose-600 font-medium">\1</span>')
      end

      # Numbers
      highlighted = highlighted.gsub(/\b(\d+\.?\d*)\b/, '<span class="text-blue-600">\1</span>')

      # Instance variables
      highlighted = highlighted.gsub(/(@[\w_]+)/, '<span class="text-cyan-600">\1</span>')

      # Method definitions and calls with parentheses
      highlighted = highlighted.gsub(/\b([a-z_][\w_]*[?!]?)(\()/, '<span class="text-amber-600">\1</span>\2')

      highlighted.html_safe
    end
  end
end
