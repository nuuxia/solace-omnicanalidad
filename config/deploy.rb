# Change these
set :repo_url,        'git@github.com:Atricanico/SoftwareArrows.git'
set :application,     'software-arrow'
set :user,            'w3villa'
set :puma_threads,    [4, 16]
set :puma_workers,    0
set :keep_releases, 100

# Don't change these unless you know what you're doingo
set :pty,             true
set :use_sudo,        true
set :deploy_via,      :remote_cache
set :deploy_to,       "/home/#{fetch(:user)}/#{fetch(:application)}"
set :default_env, { 'NODE_OPTIONS' => '--max-old-space-size=4096 --openssl-legacy-provider' }
# Change Port to 3001
set :puma_bind, 'tcp://127.0.0.1:3001'
# set :puma_bind,       "unix://#{shared_path}/tmp/sockets/#{fetch(:application)}-puma.sock"
set :puma_state,      "#{shared_path}/tmp/pids/puma.state"
set :puma_pid,        "#{shared_path}/tmp/pids/puma.pid"
set :puma_access_log, "#{release_path}/log/puma.access.log"
set :puma_error_log,  "#{release_path}/log/puma.error.log"
set :ssh_options,     { forward_agent: true, user: fetch(:user), keys: %w[~/.ssh/id_rsa] }
set :puma_preload_app, true
set :puma_worker_timeout, nil
set :puma_init_active_record, true # Change to false when not using ActiveRecord

## Defaults:
# set :scm,           :git
# set :format,        :pretty
# set :log_level,     :debug
# set :keep_releases, 5

## Linked Files & Directories (Default None):
set :linked_files, %w[config/database.yml .env]
set :linked_dirs,  %w[log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system]

namespace :puma do
  desc 'Create Directories for Puma Pids and Socket'
  task :make_dirs do
    on roles(:app) do
      execute "mkdir #{shared_path}/tmp/sockets -p"
      execute "mkdir #{shared_path}/tmp/pids -p"
    end
  end

  before :start, :make_dirs
end

namespace :deploy do
  desc 'Make sure local git is in sync with remote.'
  task :check_revision do
    on roles(:app) do
      unless `git rev-parse HEAD` == `git rev-parse origin/master`
        puts 'WARNING: HEAD is not the same as origin/master'
        puts 'Run `git push` to sync changes.'
        # exit
      end
    end
  end

  desc 'Copy env variables to frontend'
  task :copy_env_to_frontend do
    on roles(:app) do
      within release_path do
        # Asegurarnos que el directorio existe
        execute :mkdir, '-p', 'app/javascript'
        # Copiar el archivo .env
        execute "cp #{shared_path}/.env #{release_path}/app/javascript/.env"
      end
    end
  end

  desc 'Initial Deploy'
  task :initial do
    on roles(:app) do
      before 'deploy:restart', 'puma:start'
      invoke 'deploy'
    end
  end

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      invoke! 'puma:restart'
    end
  end

  # Add the following lines to create the .env symlink after deployment is published

  task :create_env_symlink do
    on roles(:app) do
      within release_path do
        execute :ln, '-sf', "#{shared_path}/.env", '.env'
      end
    end
  end

  # Agrega los hooks en este orden
  after 'deploy:published', 'deploy:create_env_symlink'
  after 'deploy:create_env_symlink', 'deploy:copy_env_to_frontend'
  before :starting,     :check_revision
  after  :finishing,    :compile_assets
  after  :finishing,    :cleanup
  after  :finishing,    :restart
end

# ps aux | grep puma    # Get puma pid
# kill -s SIGUSR2 pid   # Restart puma
# kill -s SIGTERM pid   # Stop puma
