# lib/tasks/whatsapp_test.rake
namespace :whatsapp do
    desc "Encolar muchos WhatsappMessageJob para pruebas de estrés"
    task stress_test: :environment do
      require 'benchmark'
  
      Rails.logger.info "🔧 Iniciando prueba de estrés. Los mensajes serán simulados en entorno de desarrollo."
  
      # Conectar a Redis para métricas
      metrics_key = "whatsapp_metrics"
      redis = Sidekiq.redis { |conn| conn }
  
      # Resetear las métricas
      redis.del(metrics_key)
      Rails.logger.info "🧹 Métricas resetadas en Redis."
  
      # Utilizar un Inbox existente asociado a Channel::Whatsapp
      inbox = Inbox.find_by(name: 'Inbox de Prueba Whatsapp') # Asegúrate de que el nombre coincide
      if inbox.nil?
        Rails.logger.error "No se encontró el Inbox 'Inbox de Prueba Whatsapp'. Por favor, crea uno antes de ejecutar la tarea de estrés."
        exit(1)
      end
  
      Rails.logger.info "🆕 Inbox existente, ID=#{inbox.id}"
  
      # Crear una campaña de prueba asociada al Account y al Inbox
      campaign = CampaignsWhatsapp.create!(
        title: "Prueba de Estrés",
        inbox: inbox,
        account: inbox.account,
        template: {
          "id" => "574688125489609",
          "name" => "welcome",
          "status" => "APPROVED",
          "category" => "MARKETING",
          "language" => "en",
          "components" => [
            { "text" => "Welcome to Nuuxia! We're thrilled to have you join us", "type" => "HEADER", "format" => "TEXT" },
            { "text" => "If you have any questions or need assistance, feel free to reply to this message. Our team is here to help! 🚀\n\nLet’s make your experience exceptional.\n\nBest regards 🙌🏻", "type" => "BODY" },
            { "text" => "The Nuuxia Team", "type" => "FOOTER" }
          ],
          "sub_category" => "CUSTOM",
          "parameter_format" => "POSITIONAL"
        },
        audience: [
          { "id" => 2, "type" => "Label" },
          { "id" => 1, "type" => "Label" }
        ],
        scheduled_at: Time.current + 5.minutes
      )
  
      Rails.logger.info "🆕 Campaña creada exitosamente, ID=#{campaign.id}"
  
      # Definir el número de mensajes a enviar
      total_messages = 1000 # Ajusta este número según tus necesidades
      puts "📊 Encolando #{total_messages} WhatsappMessageJob para la campaña ID=#{campaign.id}"
  
      # Crear contactos de prueba y encolar trabajos
      Benchmark.bm do |x|
        x.report("Encolando mensajes:") do
          total_messages.times do |i|
            contact_id = i + 1000 # Asegúrate de que estos IDs no colisionen con los existentes
            phone_number = "+100000000#{i.to_s.rjust(3, '0')}" # Generar números de teléfono únicos
  
            # Crear o encontrar el contacto asociado al Account
            contact = Contact.find_or_create_by!(
              id: contact_id,
              account: inbox.account,
              phone_number: phone_number
            )
  
            # Encolar el trabajo
            WhatsappMessageJob.perform_async(campaign.id, contact.id)
          end
        end
      end
  
      Rails.logger.info "📤 Todos los trabajos han sido encolados exitosamente."
  
      # Esperar a que los trabajos sean procesados
      # Esto se hace comprobando las métricas y esperando hasta que messages_sent + messages_failed = total_messages
      puts "⏳ Esperando a que todos los trabajos sean procesados..."
  
      start_time = Time.now
      timeout = 300 # Tiempo máximo de espera en segundos (5 minutos)
  
      loop do
        sleep 5 # Esperar 5 segundos antes de verificar nuevamente
        sent = redis.hget(metrics_key, 'messages_sent').to_i
        failed = redis.hget(metrics_key, 'messages_failed').to_i
        total_processed = sent + failed
  
        puts "📈 Procesados: #{total_processed}/#{total_messages} (Enviados: #{sent}, Fallidos: #{failed})"
  
        break if total_processed >= total_messages
  
        if Time.now - start_time > timeout
          puts "⚠️ Tiempo de espera excedido. Se detiene la espera de los trabajos."
          break
        end
      end
  
      # Calcular el tiempo total de la prueba
      total_time = Time.now - start_time
  
      # Obtener las métricas finales
      final_sent = redis.hget(metrics_key, 'messages_sent').to_i
      final_failed = redis.hget(metrics_key, 'messages_failed').to_i
      final_skipped = redis.hget(metrics_key, 'contacts_skipped').to_i
      final_record_not_found = redis.hget(metrics_key, 'record_not_found').to_i
      final_errors = redis.hget(metrics_key, 'errors').to_i
  
      # Calcular métricas
      messages_per_second = final_sent / total_time.to_f
  
      # Mostrar las métricas
      puts "\n📊 **Resultados de la Prueba de Estrés**"
      puts "-------------------------------------"
      puts "Total de mensajes encolados: #{total_messages}"
      puts "Mensajes enviados exitosamente: #{final_sent}"
      puts "Mensajes fallidos: #{final_failed}"
      puts "Contactos sin número de teléfono: #{final_skipped}"
      puts "Registros no encontrados: #{final_record_not_found}"
      puts "Otros errores: #{final_errors}"
      puts "Tiempo total de la prueba: #{format("%.2f", total_time)} segundos"
      puts "Mensajes por segundo: #{format("%.2f", messages_per_second)}"
      puts "-------------------------------------\n"
  
      # Opcional: Guardar los resultados en un archivo
      File.open("whatsapp_stress_test_results_#{Time.now.strftime('%Y%m%d_%H%M%S')}.txt", 'w') do |file|
        file.puts "📊 **Resultados de la Prueba de Estrés**"
        file.puts "-------------------------------------"
        file.puts "Total de mensajes encolados: #{total_messages}"
        file.puts "Mensajes enviados exitosamente: #{final_sent}"
        file.puts "Mensajes fallidos: #{final_failed}"
        file.puts "Contactos sin número de teléfono: #{final_skipped}"
        file.puts "Registros no encontrados: #{final_record_not_found}"
        file.puts "Otros errores: #{final_errors}"
        file.puts "Tiempo total de la prueba: #{format("%.2f", total_time)} segundos"
        file.puts "Mensajes por segundo: #{format("%.2f", messages_per_second)}"
        file.puts "-------------------------------------\n"
      end
  
      Rails.logger.info "📝 Resultados de la prueba guardados en 'whatsapp_stress_test_results_#{Time.now.strftime('%Y%m%d_%H%M%S')}.txt'."
    end
  end
  