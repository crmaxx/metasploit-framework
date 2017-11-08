# -*- coding: binary -*-
# A Convenience to load all field classes and yaml handling.
# XXX: Pretty certian this monkeypatch isn't required in Metasploit.

if "a"[0].is_a?(Integer)
  unless Integer.methods.include? :ord
    class Integer
      def ord
        self
      end
    end
  end
end

require 'bit-struct/bit-struct'
require 'bit-struct/fields'
require 'bit-struct/yaml'
