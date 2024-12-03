# server-based syntax
# ======================
# Definimos un servidor con sus roles y propiedades

server "159.203.161.226", user: "root", roles: %w{app db web}, my_property: :my_value

# Configuración personalizada
# ===========================

# La rama de Git que se debe desplegar (cambia a 'chatwoot_new_version')
set :branch, 'chatwoot_new_version'

# Configuración de Puma (puedes dejarla igual que en el archivo `deploy.rb`)
set :puma_threads,    [4, 16]
set :puma_workers,    0
set :puma_bind, 'tcp://127.0.0.1:4001'
set :puma_state,      "#{shared_path}/tmp/pids/puma.state"
set :puma_pid,        "#{shared_path}/tmp/pids/puma.pid"
set :puma_access_log, "#{release_path}/log/puma.access.log"
set :puma_error_log,  "#{release_path}/log/puma.error.log"
set :puma_preload_app, true
set :puma_worker_timeout, nil
set :puma_init_active_record, true # Cambiar a false si no usas ActiveRecord

# Definir las variables de despliegue
set :deploy_via,      :remote_cache
set :deploy_to,       "/home/#{fetch(:user)}/#{fetch(:application)}"
set :ssh_options,     { forward_agent: true, user: 'root', keys: %w[~/.ssh/id_ed25519] }

# Archivos y directorios vinculados
set :linked_files, %w[config/database.yml]
set :linked_dirs,  %w[log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system]

# Tareas de Puma
namespace :puma do
  desc 'Crear directorios para los PIDs y el socket de Puma'
  task :make_dirs do
    on roles(:app) do
      execute "mkdir #{shared_path}/tmp/sockets -p"
      execute "mkdir #{shared_path}/tmp/pids -p"
    end
  end

  before :start, :make_dirs
end

# Tareas de despliegue
namespace :deploy do
  desc 'Asegurarse de que el git local esté en sincronización con el remoto.'
  task :check_revision do
    on roles(:app) do
      unless `git rev-parse HEAD` == `git rev-parse origin/chatwoot_new_version`
        puts 'WARNING: HEAD no es lo mismo que origin/chatwoot_new_version'
        puts 'Ejecuta `git push` para sincronizar los cambios.'
        # exit
      end
    end
  end

  desc 'Despliegue inicial'
  task :initial do
    on roles(:app) do
      before 'deploy:restart', 'puma:start'
      invoke 'deploy'
    end
  end

  desc 'Reiniciar la aplicación'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      invoke 'puma:restart'
    end
  end

  # Agregar la tarea para crear el symlink del .env
  after 'deploy:published', 'deploy:create_env_symlink'

  task :create_env_symlink do
    on roles(:app) do
      within release_path do
        execute :ln, '-sf', "#{shared_path}/.env", '.env'
      end
    end
  end

  before :starting,     :check_revision
  after  :finishing,    :compile_assets
  after  :finishing,    :cleanup
  after  :finishing,    :restart
end
