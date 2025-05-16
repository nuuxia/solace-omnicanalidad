# app/services/mercado_libre/fetch_order_service.rb
module MercadoLibre
  class FetchOrderService
    pattr_initialize [:client!, :order_id!]
    def perform
      fetch_order_details
    end
    private
    def fetch_order_details
      client.fetch_order(order_id)
    rescue StandardError => e
      Rails.logger.error("Error fetching order #{order_id}: #{e.message}")
      nil
    end
  end
end
