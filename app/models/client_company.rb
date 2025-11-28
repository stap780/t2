class ClientCompany < ApplicationRecord
  belongs_to :client
  belongs_to :company
end
