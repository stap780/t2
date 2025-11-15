json.extract! product, :id, :status, :tip, :title, :description, :created_at, :updated_at
json.url product_url(product, format: :json)
