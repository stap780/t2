# frozen_string_literal: true

class DocumentationController < ApplicationController
  def index
    @page = :index
  end

  def avito
    @page = :avito
  end

  def insales
    @page = :insales
  end

  def moysklad
    @page = :moysklad
  end
end
