require 'unicorn/launcher'
require 'unicorn/configurator'
require 'optparse'

module Hell
  class CLI
    def self.default_options(unicorn_path=nil)
      rackup_opts = Unicorn::Configurator::RACKUP || {}
      rackup_opts[:port] = 4567

      options = rackup_opts[:options] || {}
      options[:config_file] = unicorn_path unless unicorn_path.nil?
      options[:listeners] = ['0.0.0.0:4567']

      options[:log_path] = ENV.fetch('HELL_LOG_PATH', File.join(Dir.pwd, 'log'))

      options[:app_root] = ENV.fetch('HELL_APP_ROOT', Dir.pwd)
      options[:base_path] = ENV.fetch('HELL_BASE_PATH', '/')
      options[:require_env] = !!ENV.fetch('HELL_REQUIRE_ENV', true)
      options[:sentinel] = ENV.fetch('HELL_SENTINEL_STRINGS', 'Hellish Task Completed').split(',')
      options[:pusher_app_id] = ENV.fetch('HELL_PUSHER_APP_ID', nil)
      options[:pusher_key] = ENV.fetch('HELL_PUSHER_KEY', nil)
      options[:pusher_secret] = ENV.fetch('HELL_PUSHER_SECRET', nil)

      options
    end

    def self.unicorn_options(args, unicorn_path=nil)
      options, op = Hell::CLI.option_parser(args, unicorn_path)

      [
        :app_root,
        :base_path,
        :require_env,
        :sentinel,
        :pusher_app_id,
        :pusher_key,
        :pusher_secret,
      ].each {|key| options.delete(key)}

      [options, op]
    end

    def self.option_parser(args, unicorn_path=nil)
      options = Hell::CLI.default_options(unicorn_path)

      op = OptionParser.new("", 24, '  ') do |opts|
        cmd = File.basename($0)
        opts.banner = "Usage: #{cmd} " \
                      "[ruby options] [#{cmd} options] [rackup config file]"
        opts.separator "Ruby options:"

        lineno = 1
        opts.on("-e", "--eval LINE", "evaluate a LINE of code") do |line|
          eval line, TOPLEVEL_BINDING, "-e", lineno
          lineno += 1
        end

        opts.on("-d", "--debug", "set debugging flags (set $DEBUG to true)") do
          $DEBUG = true
        end

        opts.on("-w", "--warn", "turn warnings on for your script") do
          $-w = true
        end

        opts.on("-I", "--include PATH",
                "specify $LOAD_PATH (may be used more than once)") do |path|
          $LOAD_PATH.unshift(*path.split(/:/))
        end

        opts.on("-r", "--require LIBRARY",
                "require the library, before executing your script") do |library|
          require library
        end

        opts.separator "Unicorn options:"

        # some of these switches exist for rackup command-line compatibility,

        opts.on("-o", "--host HOST",
                "listen on HOST (default: 0.0.0.0)") do |h|
          rackup_opts[:host] = h || '0.0.0.0'
          rackup_opts[:set_listener] = true
        end

        opts.on("-p", "--port PORT",
                "use PORT (default: 4567)") do |p|
          rackup_opts[:port] = p || 4567
          rackup_opts[:port] = rackup_opts[:port].to_i
          rackup_opts[:set_listener] = true
        end

        opts.on("-E", "--env RACK_ENV",
                "use RACK_ENV for defaults (default: development)") do |e|
          ENV["RACK_ENV"] = e
        end

        opts.on("-D", "--daemonize", "run daemonized in the background") do |d|
          rackup_opts[:daemonize] = !!d
        end

        opts.on("-P", "--pid FILE", "DEPRECATED") do |f|
          warn %q{Use of --pid/-P is strongly discouraged}
          warn %q{Use the 'pid' directive in the Unicorn config file instead}
          options[:pid] = f
        end

        opts.on("-s", "--server SERVER",
                "this flag only exists for compatibility") do |s|
          warn "-s/--server only exists for compatibility with rackup"
        end

        # Unicorn-specific stuff
        opts.on("-l", "--listen {HOST:PORT|PATH}",
                "listen on HOST:PORT or PATH",
                "this may be specified multiple times",
                "(default: 0.0.0.0:4567)") do |address|
          options[:listeners] << address || '0.0.0.0:4567'
        end

        opts.on("-c", "--config-file FILE", "Unicorn-specific config file") do |f|
          options[:config_file] = unicorn_path
        end

        # I'm avoiding Unicorn-specific config options on the command-line.
        # IMNSHO, config options on the command-line are redundant given
        # config files and make things unnecessarily complicated with multiple
        # places to look for a config option.

        opts.separator "Common options"
        opts.separator "Note: will not work under unicorn, use environment variables instead"

        opts.on_tail("-h", "--help", "Show this message") do
          puts opts.to_s.gsub(/^.*DEPRECATED.*$/s, '')
          exit
        end

        opts.on_tail("-v", "--version", "Show version") do
          puts "#{cmd} v#{Unicorn::Const::UNICORN_VERSION}"
          exit
        end

        opts.on('-a', '--app-root APP_ROOT', 'directory from which capistrano should run') do |app_root|
          options[:app_root] = app_root if app_root
        end

        opts.on('-b', '--base-path BASE_PATH', 'base directory path to use in the web ui') do |base_path|
          options[:base_path] = base_path if base_path
        end

        opts.on('-L', '--log-path LOG_PATH', 'directory path to hell logs') do |log_path|
          options[:log_path] = log_path if log_path
        end

        opts.on('-R', '--require-env REQUIRE_ENV', 'whether or not to require specifying an environment') do |require_env|
          options[:require_env] = !!require_env if require_env
        end

        opts.on('-S', '--sentinel SENTINAL_PHRASE', 'sentinel phrase used to denote the end of a task run') do |sentinel|
          options[:sentinel] = sentinel.split(',') if sentinel
        end

        opts.on('--pusher-app-id PUSHER_APP_ID', 'pusher app id') do |pusher_app_id|
          options[:pusher_app_id] = pusher_app_id if pusher_app_id
        end

        opts.on('--pusher-key PUSHER_KEY', 'pusher key') do |pusher_key|
          options[:pusher_key] = pusher_key if pusher_key
        end

        opts.on('--pusher-secret PUSHER_SECRET', 'pusher secret') do |pusher_secret|
          options[:pusher_secret] = pusher_secret if pusher_secret
        end

        opts.parse! args
      end

      [options, op]
    end
  end
end