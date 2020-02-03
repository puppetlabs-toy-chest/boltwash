require 'bolt/transport/base'
require 'bolt/transport/sudoable'
require 'bolt/transport/ssh/connection'
require 'concurrent/atomic/atomic_reference'
require 'concurrent/promises'

class BoltSSH < Bolt::Transport::SSH::Connection
  # Adapted from Bolt::Transport::SSH::Connection.execute with output copied to
  # $stdout/$stderr. Returns an exit code instead of Bolt::Result. It also
  # handles stdin differently with sudo; it waits for some response, then
  # sends stdin.
  def execute(command, stdin: nil)
    escalate = run_as && @user != run_as
    use_sudo = escalate && @target.options['run-as-command'].nil?

    if escalate
      if use_sudo
        sudo_exec = target.options['sudo-executable'] || "sudo"
        sudo_flags = [sudo_exec, "-S", "-H", "-u", run_as, "-p", Bolt::Transport::Sudoable.sudo_prompt]
        sudo_str = Shellwords.shelljoin(sudo_flags)
      else
        sudo_str = Shellwords.shelljoin(@target.options['run-as-command'] + [run_as])
      end
      command = build_sudoable_command_str(command, sudo_str, @sudo_id, stdin: stdin, reset_cwd: true)
    end

    exit_code = 0
    session_channel = @session.open_channel do |channel|
      # Request a pseudo tty
      channel.request_pty if target.options['tty']

      channel.exec(command) do |_, success|
        unless success
          raise Bolt::Node::ConnectError.new(
            "Could not execute command: #{command}",
            'EXEC_ERROR'
          )
        end

        received = Concurrent::Promises.resolvable_future
        # Automatically resolve it if we're not using sudo so we immediately send input
        received.fulfill(true, false) unless use_sudo

        channel.on_data do |_, data|
          received.fulfill(true, false)
          $stdout << data unless use_sudo && handled_sudo(channel, data, stdin)
        end

        channel.on_extended_data do |_, _, data|
          received.fulfill(true, false)
          $stderr << data unless use_sudo && handled_sudo(channel, data, stdin)
        end

        channel.on_request('exit-status') do |_, data|
          exit_code = data.read_long
        end

        # Wait until we know sudo is handled, then send stdin.
        if stdin && received.value!
          channel.send_data(options[:stdin])
          channel.eof!
        end
      end
    end
    session_channel.wait
    exit_code
  end
end
