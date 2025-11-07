require "application_system_test_case"

class InsalesTest < ApplicationSystemTestCase
  setup do
    @insale = insales(:one)
  end

  test "visiting the index" do
    visit insales_url
    assert_selector "h1", text: "Insales"
  end

  test "should create insale" do
    visit insales_url
    click_on "New insale"

    fill_in "Api key", with: @insale.api_key
    fill_in "Api link", with: @insale.api_link
    fill_in "Api password", with: @insale.api_password
    click_on "Create Insale"

    assert_text "Insale was successfully created"
    click_on "Back"
  end

  test "should update Insale" do
    visit insale_url(@insale)
    click_on "Edit this insale", match: :first

    fill_in "Api key", with: @insale.api_key
    fill_in "Api link", with: @insale.api_link
    fill_in "Api password", with: @insale.api_password
    click_on "Update Insale"

    assert_text "Insale was successfully updated"
    click_on "Back"
  end

  test "should destroy Insale" do
    visit insale_url(@insale)
    accept_confirm { click_on "Destroy this insale", match: :first }

    assert_text "Insale was successfully destroyed"
  end
end
