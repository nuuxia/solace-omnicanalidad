require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/cassettes' # Directorio donde se guardarán las cassettes
  config.hook_into :webmock # Usa WebMock para interceptar las solicitudes
  config.configure_rspec_metadata! # Configura para que se use VCR automáticamente con RSpec
  config.allow_http_connections_when_no_cassette = false # Bloquea las conexiones HTTP cuando no hay cassette
end
