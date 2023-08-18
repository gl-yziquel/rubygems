# frozen_string_literal: true

require "json"
require "open-uri"
require "time"

def generate_spdx_license_list(dest = "lib/rubygems/util/licenses.rb")
  base = URI("https://spdx.org/licenses/")
  updates = [
    %w[licenses licenseId],
    %w[exceptions licenseExceptionId],
  ].map do |uri, id|
    (base + "#{uri}.json").open do |f|
      begin
        mtime = Time.parse(f.meta["last-modified"])
      rescue ArgumentError
      end
      list = JSON.parse(f.read)[uri].map {|o| o[id] }
      [mtime, list]
    end
  end

  mtime = updates.filter_map {|t,| t }.max
  (_, licenses), (_, exceptions) = updates

  content = "#{<<-RUBY}#{<<-'RUBY'}"
# frozen_string_literal: true

# This is generated by #{File.basename(__FILE__)}, any edits to this
# file will be discarded.

require_relative "../text"

class Gem::Licenses
  extend Gem::Text

  NONSTANDARD = "Nonstandard"
  LICENSE_REF = "LicenseRef-.+"

  # Software Package Data Exchange (SPDX) standard open-source software
  # license identifiers
  LICENSE_IDENTIFIERS = %w[
    #{licenses.sort.join "\n    "}
  ].freeze

  # exception identifiers
  EXCEPTION_IDENTIFIERS = %w[
    #{exceptions.sort.join "\n    "}
  ].freeze

  RUBY
  REGEXP = /
    \A
    (?:
      #{Regexp.union(LICENSE_IDENTIFIERS)}
      \+?
      (?:\s WITH \s #{Regexp.union(EXCEPTION_IDENTIFIERS)})?
      | #{NONSTANDARD}
      | #{LICENSE_REF}
    )
    \Z
  /ox.freeze

  def self.match?(license)
    REGEXP.match?(license)
  end

  def self.suggestions(license)
    by_distance = LICENSE_IDENTIFIERS.group_by do |identifier|
      levenshtein_distance(identifier, license)
    end
    lowest = by_distance.keys.min
    return unless lowest < license.size
    by_distance[lowest]
  end
end
RUBY

  begin
    return if content == File.read(dest)
  rescue SystemCallError
  end
  File.binwrite(dest, content)
  [dest, mtime]
end

if $0 == __FILE__
  p generate_spdx_license_list
end