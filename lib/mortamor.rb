require 'mortamor/version'

# Load the defaults
#
module Mortamor
  class << self
      attr_writer :ui
        end

  class << self
      attr_reader :ui
        end
                end
