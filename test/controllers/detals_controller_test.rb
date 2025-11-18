require "test_helper"

class DetalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @detal = detals(:one)
  end

  test "should get index" do
    get detals_url
    assert_response :success
  end

  test "should get new" do
    get new_detal_url
    assert_response :success
  end

  test "should create detal" do
    assert_difference("Detal.count") do
      post detals_url, params: { detal: { desc: @detal.desc, sku: @detal.sku, status: @detal.status, title: @detal.title } }
    end

    assert_redirected_to detal_url(Detal.last)
  end

  test "should show detal" do
    get detal_url(@detal)
    assert_response :success
  end

  test "should get edit" do
    get edit_detal_url(@detal)
    assert_response :success
  end

  test "should update detal" do
    patch detal_url(@detal), params: { detal: { desc: @detal.desc, sku: @detal.sku, status: @detal.status, title: @detal.title } }
    assert_redirected_to detal_url(@detal)
  end

  test "should destroy detal" do
    assert_difference("Detal.count", -1) do
      delete detal_url(@detal)
    end

    assert_redirected_to detals_url
  end
end
