require "test_helper"

class BindingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @binding = bindings(:one)
  end

  test "should get index" do
    get bindings_url
    assert_response :success
  end

  test "should get new" do
    get new_binding_url
    assert_response :success
  end

  test "should create binding" do
    assert_difference("Binding.count") do
      post bindings_url, params: { binding: { bindable_id: @binding.bindable_id, bindable_type: @binding.bindable_type, record_id: @binding.record_id, record_type: @binding.record_type, value: @binding.value } }
    end

    assert_redirected_to binding_url(Binding.last)
  end

  test "should show binding" do
    get binding_url(@binding)
    assert_response :success
  end

  test "should get edit" do
    get edit_binding_url(@binding)
    assert_response :success
  end

  test "should update binding" do
    patch binding_url(@binding), params: { binding: { bindable_id: @binding.bindable_id, bindable_type: @binding.bindable_type, record_id: @binding.record_id, record_type: @binding.record_type, value: @binding.value } }
    assert_redirected_to binding_url(@binding)
  end

  test "should destroy binding" do
    assert_difference("Binding.count", -1) do
      delete binding_url(@binding)
    end

    assert_redirected_to bindings_url
  end
end
