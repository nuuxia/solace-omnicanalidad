# frozen_string_literal: true

# This service handles the generation of Content-Disposition headers
# for filenames with non-ASCII characters, following RFC 6266 guidelines.
# It provides both ASCII and UTF-8 versions of the filename for maximum browser compatibility.
class ContentDispositionService
  # Generates a properly formatted Content-Disposition header value
  # that works with non-ASCII filenames across different browsers.
  #
  # @param filename [String] The original filename, can contain non-ASCII characters
  # @param disposition [String] Either 'attachment' or 'inline'
  # @return [String] A properly formatted Content-Disposition header value
  def self.format(filename, disposition: 'attachment')
    # ASCII version - replace non-ASCII chars with transliterated version if possible
    ascii_filename = I18n.transliterate(filename, replacement: '_')

    # URI encode both filenames
    encoded_ascii_filename = ERB::Util.url_encode(ascii_filename)
    encoded_utf8_filename = ERB::Util.url_encode(filename)

    # Format according to RFC 6266
    # First provide ASCII version, then UTF-8 version with filename* parameter
    %(#{disposition}; filename="#{encoded_ascii_filename}"; filename*=UTF-8''#{encoded_utf8_filename})
  end

  # Generates a URL with proper Content-Disposition header for ActiveStorage blobs
  #
  # @param blob [ActiveStorage::Blob] The ActiveStorage blob
  # @param disposition [String] Either 'attachment' or 'inline'
  # @return [String] URL with proper Content-Disposition header
  def self.url_for_blob(blob, disposition: 'attachment')
    # Get the base URL
    base_url = Rails.application.routes.url_helpers.rails_blob_url(blob)

    # Generate the Content-Disposition header
    content_disposition = format(blob.filename.to_s, disposition: disposition)

    # Add the Content-Disposition header as a query parameter
    # This works with services like S3 that support response-content-disposition
    separator = base_url.include?('?') ? '&' : '?'
    "#{base_url}#{separator}response-content-disposition=#{ERB::Util.url_encode(content_disposition)}"
  end
end
