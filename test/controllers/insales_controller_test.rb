require "test_helper"

class InsalesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @insale = insales(:one)
  end

  test "should get index" do
    get insales_url
    assert_response :success
  end

  test "should get new" do
    get new_insale_url
    assert_response :success
  end

  test "should create insale" do
    assert_difference("Insale.count") do
      post insales_url, params: { insale: { api_key: @insale.api_key, api_link: @insale.api_link, api_password: @insale.api_password } }
    end

    assert_redirected_to insale_url(Insale.last)
  end

  test "should show insale" do
    get insale_url(@insale)
    assert_response :success
  end

  test "should get edit" do
    get edit_insale_url(@insale)
    assert_response :success
  end

  test "should update insale" do
    patch insale_url(@insale), params: { insale: { api_key: @insale.api_key, api_link: @insale.api_link, api_password: @insale.api_password } }
    assert_redirected_to insale_url(@insale)
  end

  test "should destroy insale" do
    assert_difference("Insale.count", -1) do
      delete insale_url(@insale)
    end

    assert_redirected_to insales_url
  end
end
