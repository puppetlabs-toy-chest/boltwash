require 'bolt/transport/base'
require 'bolt/transport/docker/connection'
require 'open3'

class BoltDocker < Bolt::Transport::Docker::Connection
  attr_reader :target

  # Adapted from Bolt::Transport::Docker::Connection.execute.
  def execute(command, stdin: nil)
    if target.options['shell-command'] && !target.options['shell-command'].empty?
      # escape any double quotes in command
      command = command.gsub('"', '\"')
      command = "#{target.options['shell-command']} \" #{command}\""
    end
    command = *Shellwords.split(command)

    command_options = []
    # Need to be interactive if redirecting STDIN
    command_options << '--interactive' unless stdin.nil?
    command_options << '--tty' if target.options['tty']
    command_options << container_id
    command_options.concat(command)

    env_hash = {}
    # Set the DOCKER_HOST if we are using a non-default service-url
    env_hash['DOCKER_HOST'] = @docker_host unless @docker_host.nil?

    in_r, in_w = IO.pipe
    in_w.sync = true
    in_w.binmode
    pid = Process.spawn(env_hash, 'docker', 'exec', *command_options, in: in_r)
    in_w.write(stdin) if stdin
    in_w.close
    _, status = Process.wait2(pid)

    # The actual result is the exitstatus not the process object
    status.nil? ? -32768 : status.exitstatus
  end
end
