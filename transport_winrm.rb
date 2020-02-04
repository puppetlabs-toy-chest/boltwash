require 'bolt/transport/base'
require 'bolt/transport/winrm/connection'
require 'winrm'

class BoltWinRM < Bolt::Transport::WinRM::Connection
  # Override execute so it streams output and returns the exit code
  def execute(cmd, args, stdin: nil)
    # The WinRM gem doesn't provide a way to pass stdin. It would require
    # sending a whole script to make it work and we don't have a lot of cases
    # where it's needed yet.
    raise 'input on stdin not supported' if stdin

    # The powershell implementation ignores 'args', so just string join (which
    # is how powershell joins arg arrays). If you use characters that need to be
    # escaped, pass the argument as a single string with appropriate escaping.
    command = ([cmd] + args).join(' ')
    output = @session.run(command) do |stdout, stderr|
      $stdout << stdout
      $stderr << stderr
    end
    output.exitcode
  end
end
