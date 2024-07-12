require_relative 'command_line'

BuildLabels::CommandLine::COMMANDS[:to_compose] = Class.new do
  def run(builder, params, compose)
    raise 'Compose file not defined' unless compose

    builder.extend_compose compose
  end

  def help = 'Add labels to all build sections of docker-compose file'
end.new


