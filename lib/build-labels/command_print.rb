require_relative 'command_line'

BuildLabels::CommandLine::COMMANDS[:print] = Class.new do
  def run(builder, params, compose_text)
    builder.each_labels do |ns, values|
      values.each_pair do |k,v|
        puts "#{ns}.#{k}=#{v}" unless v.to_s.empty?
      end
    end
  end

  def help = 'Print labels to stdout'
end.new


