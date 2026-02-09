require "test_helper"

class IncasesControllerTest < ActionDispatch::IntegrationTest
  test "should get calc action" do
    strah = Company.create!(tip: 'strah', short_title: 'Test Strah', rate: 100.0)
    company = Company.create!(tip: 'our', short_title: 'Test Company')
    incase = Incase.create!(
      totalsum: 1000,
      strah: strah,
      company: company,
      date: Date.today,
      unumber: 'TEST-004'
    )
    
    get calc_incase_path(incase)
    assert_response :redirect
  end

  test "calc action supports turbo stream format" do
    strah = Company.create!(tip: 'strah', short_title: 'Test Strah', rate: 100.0)
    company = Company.create!(tip: 'our', short_title: 'Test Company')
    incase = Incase.create!(
      totalsum: 1000,
      strah: strah,
      company: company,
      date: Date.today,
      unumber: 'TEST-005'
    )
    
    get calc_incase_path(incase), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
  end
end
