# https://claude.ai/chat/4cd83f29-8ce4-42b7-8dcd-4f7c6222ab5e
require 'psych'

module YamlMerge
  extend self

  def deep_merge(base, override)
    result = base.dup
    override.each do |key, value|
      if value.is_a?(Hash) && result[key].is_a?(Hash)
        result[key] = deep_merge(result[key], value)
      elsif value.is_a?(Array) && result[key].is_a?(Array)
        result[key] = (result[key] + value).uniq
      else
        result[key] = value
      end
    end
    result
  end

  def process_yaml(node, anchors = {})
    case node
    when Psych::Nodes::Mapping
      result = {}
      node.children.each_slice(2) do |key, value|
        processed_key = process_yaml(key, anchors)
        processed_value = process_yaml(value, anchors)
        if key.is_a?(Psych::Nodes::Scalar) && key.anchor
          anchors[key.anchor.to_sym] = processed_value
        end
        if processed_key == '<<'
          if processed_value.is_a?(Array)
            processed_value.each { |v| result = deep_merge(v, result) }
          else
            result = deep_merge(processed_value, result)
          end
        elsif result.key?(processed_key) && result[processed_key].is_a?(Array) && processed_value.is_a?(Array)
          result[processed_key] = (result[processed_key] + processed_value).uniq
        else
          result[processed_key] = processed_value
        end
      end
      node.anchor ? anchors[node.anchor.to_sym] = result : result
    when Psych::Nodes::Sequence
      result = node.children.map { |child| process_yaml(child, anchors) }
      node.anchor ? anchors[node.anchor.to_sym] = result : result
    when Psych::Nodes::Scalar
      result = node.value
      node.anchor ? anchors[node.anchor.to_sym] = result : result
    when Psych::Nodes::Alias
      anchors[node.anchor.to_sym] || node.anchor
    else
      node
    end
  end

  def parse_and_process_yaml(yaml_string)
    parsed = Psych.parse(yaml_string)
    process_yaml(parsed.root)
  end

  def deep_copy_without_aliases(obj)
    case obj
    when Hash
      obj.transform_values { |v| deep_copy_without_aliases(v) }
    when Array
      obj.map { |v| deep_copy_without_aliases(v) }
    else
      obj
    end
  end

end


# SELF TEST ============================================================================================================
if File.expand_path($0) == File.expand_path(__FILE__)
  yaml_string = <<~YAML
    defaults: &defaults
      common:
        setting1: value1
        setting2: value2
      arr: [1, 2]

    node1: &node1
      <<: *defaults
      specific:
        key1: val1
      arr: [3, 4]

    node2:
      <<: [*defaults, *node1]
      arr: [5]
      nested:
        <<: *defaults
        extra: [a, b]
  YAML

  result = YamlMerge.parse_and_process_yaml(yaml_string)
  puts result.inspect

  data_without_aliases = YamlMerge.deep_copy_without_aliases(result)
  puts data_without_aliases.to_yaml

  # puts Psych.dump(data_without_aliases, indentation: 2, line_width: -1)

end