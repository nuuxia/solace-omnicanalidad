namespace :labels do
  desc "Asigna la etiqueta 'Clientesdebitopdu1' a contactos específicos"
  task import_labels: :environment do
    account_id = 25
    label_title = 'clientesdebitopdu1'
    start_date = Date.new(2025, 1, 10)

    # Buscamos la etiqueta existente
    label = Label.find_by(title: label_title, account_id: account_id)

    unless label
      puts "Etiqueta '#{label_title}' no encontrada para la cuenta con ID #{account_id}."
      exit 1
    end

    # Buscamos los contactos específicos
    contacts = Contact.where(account_id: account_id)
                      .where('created_at >= ?', start_date)

    if contacts.empty?
      puts "No se encontraron contactos para la cuenta con ID #{account_id} desde el #{start_date}."
      exit 0
    end

    # Asignamos la etiqueta a los contactos
    contacts.each do |contact|
      contact.add_labels(label.title)
      puts "Etiqueta '#{label_title}' asignada al contacto con ID #{contact.id}."
    end

    puts "Proceso completado: Se asignó la etiqueta '#{label_title}' a #{contacts.count} contacto(s)."
  end
end
