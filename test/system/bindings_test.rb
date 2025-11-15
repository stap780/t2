require "application_system_test_case"

class BindingsTest < ApplicationSystemTestCase
  setup do
    @binding = bindings(:one)
  end

  test "visiting the index" do
    visit bindings_url
    assert_selector "h1", text: "Bindings"
  end

  test "should create binding" do
    visit bindings_url
    click_on "New binding"

    fill_in "Bindable", with: @binding.bindable_id
    fill_in "Bindable type", with: @binding.bindable_type
    fill_in "Record", with: @binding.record_id
    fill_in "Record type", with: @binding.record_type
    fill_in "Value", with: @binding.value
    click_on "Create Binding"

    assert_text "Binding was successfully created"
    click_on "Back"
  end

  test "should update Binding" do
    visit binding_url(@binding)
    click_on "Edit this binding", match: :first

    fill_in "Bindable", with: @binding.bindable_id
    fill_in "Bindable type", with: @binding.bindable_type
    fill_in "Record", with: @binding.record_id
    fill_in "Record type", with: @binding.record_type
    fill_in "Value", with: @binding.value
    click_on "Update Binding"

    assert_text "Binding was successfully updated"
    click_on "Back"
  end

  test "should destroy Binding" do
    visit binding_url(@binding)
    accept_confirm { click_on "Destroy this binding", match: :first }

    assert_text "Binding was successfully destroyed"
  end
end
