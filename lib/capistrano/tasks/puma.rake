namespace :deploy do
  task :restart do
    invoke 'puma:restart'
  end

  task :stop do
    invoke 'puma:stop'
  end

  task :start do
    invoke 'puma:start'
  end
end

namespace :puma do
  desc 'Start puma'
  task start: :check_sockets_dir do
    on roles fetch(:puma_role) do
      within release_path do
        execute *fetch(:puma_cmd), start_options
      end
    end
  end

  desc 'Stop puma'
  task stop: :check_sockets_dir do
    on roles fetch(:puma_role) do
      within release_path do
        if config_file
          execute *fetch(:pumactl_cmd), "-F #{config_file} stop"
        else
          execute *fetch(:pumactl_cmd), "-S #{state_path} stop"
        end
      end
    end
  end

  desc 'Restart puma'
  task restart: :check_sockets_dir do
    on roles fetch(:puma_role) do
      within release_path do
        begin
          if test "[[ -f #{pid_file} ]]"
            puts "puma restart"
            if config_file
              execute *fetch(:pumactl_cmd), "-F #{config_file} restart"
            elsif test "[[ -f #{state_path} ]]"
              execute *fetch(:pumactl_cmd), "-S #{state_path} restart"
            else
              execute *fetch(:puma_cmd), start_options
            end
          else
            puts "puma start"
            execute *fetch(:puma_cmd), start_options
          end
        rescue
          execute *fetch(:puma_cmd), start_options
        end
      end
    end
  end

  desc 'Restart puma (phased restart)'
  task phased_restart: :check_sockets_dir do
    on roles fetch(:puma_role) do
      within release_path do
        if config_file
          execute *fetch(:pumactl_cmd), "-F #{config_file} phased-restart"
        elsif test "[[ -f #{state_path} ]]"
          execute *fetch(:pumactl_cmd), "-S #{state_path} phased-restart"
        end
      end
    end
  end

  desc 'Puma status'
  task status: :check_sockets_dir do
    on roles fetch(:puma_role) do
      within release_path do
        if config_file
          execute *fetch(:pumactl_cmd), "-F #{config_file} status"
        elsif test "[[ -f #{state_path} ]]"
          execute *fetch(:pumactl_cmd), "-S #{state_path} status"
        end
      end
    end
  end

  task :check_sockets_dir do
    on roles fetch(:puma_role) do
      execute :mkdir, '-pv', File.dirname(state_path)
    end
  end

  if Rake::Task['rvm:hook']
    before :start, 'rvm:hook'
    before :stop, 'rvm:hook'
    before :restart, 'rvm:hook'
  end

  def start_options
    if config_file
      "-q -d -e #{puma_env} -C #{config_file}"
    else
      "-q -d -e #{puma_env} -b '#{fetch(:puma_socket)}' -S #{state_path} --control 'unix://#{shared_path}/sockets/pumactl.sock'"
    end
  end

  def config_file
    @_config_file ||= begin
      file = fetch(:puma_config_file, nil)
      file = "./config/puma/#{puma_env}.rb" if !file && File.exists?("./config/puma/#{puma_env}.rb")
      file
    end
  end

  def pid_file
      fetch(:puma_pid)
  end

  def puma_env
    fetch(:rack_env, fetch(:stage, 'production'))
  end

  def state_path
    (config_file ? configuration.options[:state] : nil) || fetch(:puma_state)
  end

  def configuration
    require 'puma/configuration'

    config = Puma::Configuration.new(:config_file => config_file)
    config.load
    config
  end
end

namespace :load do
  task :defaults do
    set :puma_cmd    , -> { [fetch(:bundle_cmd, :bundle), 'exec puma'] }
    set :pumactl_cmd , -> { [fetch(:bundle_cmd, :bundle), 'exec pumactl'] }
    set :puma_state  , -> { shared_path.join('sockets/puma.state') }
    set :puma_socket , -> { "unix://#{shared_path}/sockets/puma.sock" }
    set :puma_pid    , -> { shared_path.join('sockets/puma.pid') }
    set :puma_role   , :app
  end
end