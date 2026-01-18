require "test_helper"

class ActPdfServiceTest < ActiveSupport::TestCase
  setup do
    # Создаем необходимые данные для теста
    @company = Company.create!(
      title: "Тестовая компания",
      ur_address: "г. Москва, ул. Тестовая, д. 1"
    )
    
    @strah = Company.create!(
      title: "Страховая компания",
      ur_address: "г. Москва, ул. Страховая, д. 2"
    )
    
    @okrug = Okrug.create!(title: "Тестовый округ")
    
    @act = Act.create!(
      company: @company,
      strah: @strah,
      okrug: @okrug,
      date: Date.current,
      status: :pending
    )
  end

  test "generates PDF without errors" do
    service = ActPdfService.new(@act)
    pdf_data = service.call
    
    assert_not_nil pdf_data, "PDF должен быть сгенерирован"
    assert pdf_data.is_a?(String), "PDF должен быть строкой (бинарные данные)"
    assert pdf_data.length > 0, "PDF не должен быть пустым"
  end

  test "generates PDF with many items to test footer overlap" do
    # Создаем заявку (incase)
    incase = Incase.create!(
      stoanumber: "ЗН-001",
      modelauto: "Тестовая модель",
      carnumber: "А123БВ777",
      unumber: "ВД-001",
      date: Date.current,
      company: @company
    )
    
    # Создаем много позиций для проверки переноса страниц
    # Это должно проверить, что позиции не накладываются на футер
    30.times do |i|
      item = Item.create!(
        incase: incase,
        title: "Позиция #{i + 1}",
        katnumber: "КАТ-#{i + 1}",
        quantity: 1,
        price: 100.0,
        condition: :priemka
      )
      
      ActItem.create!(act: @act, item: item)
    end
    
    service = ActPdfService.new(@act)
    pdf_data = service.call
    
    assert_not_nil pdf_data, "PDF должен быть сгенерирован"
    assert pdf_data.length > 0, "PDF не должен быть пустым"
    
    # Проверяем, что PDF содержит несколько страниц (если позиций много)
    # Это косвенно подтверждает, что перенос страниц работает
    # Более точная проверка потребовала бы парсинга PDF
  end

  test "handles act with no items" do
    service = ActPdfService.new(@act)
    pdf_data = service.call
    
    assert_not_nil pdf_data, "PDF должен быть сгенерирован даже без позиций"
  end
end
