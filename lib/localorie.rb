#####
# http://stackoverflow.com/a/29595013/151007
#

require 'psych'
require 'json'

class Psych::Nodes::Node
  attr_accessor :line
end

class LineNumberHandler < Psych::TreeBuilder
  attr_accessor :parser

  def scalar value, anchor, tag, plain, quoted, style
    s = super
    s.line = @mark
    @mark = parser.mark.line
    s
  end
end

class Psych::Visitors::ToRuby
  def revive_hash(hash, o)
    o.children.each_slice(2) do |k, v|
      key = accept k
      val = accept v

      if v.is_a? ::Psych::Nodes::Scalar
        val = { "value" => val, "line" => v.line + 1}
      end

      hash[key] = val
    end
    hash
  end
end

# Returns the yaml as a nested hash.
def parse(yaml)
  handler = LineNumberHandler.new
  parser = Psych::Parser.new handler
  handler.parser = parser
  parser.parse yaml
  handler.root.to_ruby[0]
end

#
#####


#####
# http://stackoverflow.com/a/30225093/151007
#

class Hash
  def deep_merge(other)
    merger = proc { |_, v1, v2|
      if Hash === v1 && Hash === v2
        v1.merge(v2, &merger)
      elsif Array === v1 && Array === v2
        v1 | v2
      elsif [:undefined, nil, :nil].include?(v2)
        v1
      else
        v2
      end
    }
    self.merge other.to_h, &merger
  end

  def stringify_keys!
    keys.each do |k|
      v = delete k
      self[k.to_s] = v
      v.stringify_keys! if v.is_a? Hash
    end
  end
end

#
#####

def add_source_file_yaml!(hash, file)
  hash.each do |_, v|
    if v.is_a? Hash
      if v.has_key?('value') && v.has_key?('line')
        v['file'] = file
      else
        add_source_file_yaml! v, file
      end
    end
  end
end

translations_yml = {}

Dir.glob("#{ARGV[0]}/config/locales/**/*en.yml").each do |f|
  hash = parse File.read(f)
  add_source_file_yaml! hash, f
  translations_yml = translations_yml.deep_merge hash
end

puts translations_yml.to_json
