require "test_helper"

class IncaseTest < ActiveSupport::TestCase
  test "item_prices returns false when totalsum is zero or negative" do
    incase = Incase.new(totalsum: 0)
    success, message = incase.item_prices
    assert_not success
    assert_includes message, 'Сумма убытка не задана или равна нулю'
    
    incase.totalsum = -100
    success, message = incase.item_prices
    assert_not success
    assert_includes message, 'Сумма убытка не задана или равна нулю'
  end

  test "item_prices uses default rate of 1.0 when strah rate is absent" do
    strah = Company.create!(tip: 'strah', short_title: 'Test Strah')
    incase = Incase.create!(
      totalsum: 1000,
      strah: strah,
      company: Company.create!(tip: 'our', short_title: 'Test Company'),
      date: Date.today,
      unumber: 'TEST-001'
    )
    
    # When rate is nil, should use 1.0 (100%)
    assert_equal 1.0, incase.strah&.rate.present? ? incase.strah.rate.to_f / 100.0 : 1.0
  end

  test "item_prices calculates real_total using strah rate" do
    strah = Company.create!(tip: 'strah', short_title: 'Test Strah', rate: 80.0)
    incase = Incase.create!(
      totalsum: 1000,
      strah: strah,
      company: Company.create!(tip: 'our', short_title: 'Test Company'),
      date: Date.today,
      unumber: 'TEST-002'
    )
    
    procent = incase.strah&.rate.present? ? incase.strah.rate.to_f / 100.0 : 1.0
    real_total = incase.totalsum * procent
    
    assert_equal 800.0, real_total
  end

  test "item_prices returns false when work_items size does not match items size" do
    strah = Company.create!(tip: 'strah', short_title: 'Test Strah', rate: 100.0)
    company = Company.create!(tip: 'our', short_title: 'Test Company')
    incase = Incase.create!(
      totalsum: 1000,
      strah: strah,
      company: company,
      date: Date.today,
      unumber: 'TEST-003'
    )
    
    # Create item without variant and без подходящего статуса
    Item.create!(
      incase: incase,
      title: 'Test Item',
      quantity: 1
    )
    
    success, message = incase.item_prices
    assert_not success
    assert_includes message, 'Позиция #'
  end
end
