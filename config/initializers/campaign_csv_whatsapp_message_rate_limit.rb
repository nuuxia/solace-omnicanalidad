# Puedes tunear esto por ENV para distintos entornos
Rails.application.config.x.whatsapp.rate_per_second = ENV.fetch('CAMPAING_CSV_WSP_RATE_LIMIT_MESSAGE_PER_SECOND=20', 10).to_i
Rails.application.config.x.whatsapp.sidekiq_bulk    = 1_000 # tamaño de lote bulk-push
