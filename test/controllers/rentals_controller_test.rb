require 'test_helper'

class RentalsControllerTest < ActionDispatch::IntegrationTest
  describe "check-out" do
    it "associates a video with a customer" do
      video = videos(:one)
      customer = customers(:two)

      post check_out_path(title: video.title), params: {
        customer_id: customer.id,
        due_date: Date.today + 1
      }
      must_respond_with :success

      # Reload from DB
      expect(
        Video.find(video.id).customers
      ).must_include Customer.find(customer.id)
    end

    it "sets the checkout_date to today" do
      video = videos(:one)
      customer = customers(:two)

      post check_out_path(title: video.title), params: {
        customer_id: customer.id,
        due_date: Date.today + 1
      }
      must_respond_with :success

      expect(
        Video.find(video.id).rentals.last.checkout_date
      ).must_equal Date.today
    end

    it "requires a valid video title" do
      post check_out_path(title: "does not exist"), params: {
        customer_id: customers(:two).id,
        due_date: Date.today + 1
      }
      must_respond_with :not_found
      data = JSON.parse @response.body
      expect(data).must_include "errors"
      expect(data["errors"]).must_include "title"
    end

    it "requires a valid customer ID" do
      bad_customer_id = 13371337
      expect(Customer.find_by(id: bad_customer_id)).must_be_nil

      post check_out_path(title: videos(:one).title), params: {
        customer_id: bad_customer_id,
        due_date: Date.today + 1
      }
      must_respond_with :not_found
      data = JSON.parse @response.body
      expect(data).must_include "errors"
      expect(data["errors"]).must_include "customer_id"
    end

    it "requires a due-date in the future" do
      # Obvious case: actually in the past
      post check_out_path(title: videos(:one).title), params: {
        customer_id: customers(:two).id,
        due_date: Date.today - 1
      }
      must_respond_with :bad_request
      data = JSON.parse @response.body
      expect(data).must_include "errors"
      expect(data["errors"]).must_include "due_date"
    end

    it "requires sufficient inventory" do
      videos(:one)['inventory'] = 1
      videos(:one).save # ensure new inventory number is saved to invalidate this test
      customer = customers(:two)
      post check_out_path(title: videos(:one).title), params: {
        customer_id: customer.id,
        due_date: Date.today + 1
      }

      must_respond_with :bad_request
      data = JSON.parse @response.body
      expect(data).must_include "errors"
      expect(data["errors"]).must_include "video"
      expect(data["errors"]["video"]).must_include "No copies available"
    end
  end

  describe "check-in" do
    before do
      # Establish a rental
      @rental = Rental.create!(
        video: videos(:one),
        customer: customers(:two),
        checkout_date: Date.today - 5,
        due_date: Date.today + 5,
        returned: false
      )
    end

    it "marks a rental complete" do
      post check_in_path(title: @rental.video.title), params: {
        customer_id: @rental.customer.id
      }
      must_respond_with :success

      @rental.reload

      expect(@rental.returned).must_equal true
    end

    it "can check out a rental and return it" do
      # Arrange
      Rental.destroy_all
      customer = Customer.first
      video = Video.first

      post check_out_path(title: video.title), params: {
        customer_id:  customer.id,
        due_date:     Date.today + 5
      }

      # Act
      post check_in_path(title: video.title), params: {
        customer_id: customer.id
      }

      must_respond_with :success

      rental = Rental.first

      # Expect
      expect(rental.customer_id).must_equal customer.id
      expect(rental.video_id).must_equal video.id
      expect(rental.due_date).must_equal Date.today + 5
      expect(rental.returned).must_equal true
    end

    it "requires a valid video title" do
      post check_in_path(title: "does not exist"), params: {
        customer_id: @rental.customer.id
      }
      must_respond_with :not_found
      data = JSON.parse @response.body
      expect(data).must_include "errors"
      expect(data["errors"]).must_include "title"
    end

    it "requires a valid customer ID" do
      bad_customer_id = 13371337
      expect(Customer.find_by(id: bad_customer_id)).must_be_nil

      post check_in_path(title: @rental.video.title), params: {
        customer_id: bad_customer_id
      }
      must_respond_with :not_found
      data = JSON.parse @response.body
      expect(data).must_include "errors"
      expect(data["errors"]).must_include "customer_id"
    end

    it "requires there to be a rental for that customer-video pair" do
      post check_in_path(title: videos(:two).title), params: {
        customer_id: customers(:three).id
      }
      must_respond_with :not_found
      data = JSON.parse @response.body
      expect(data).must_include "errors"
      expect(data["errors"]).must_include "rental"
    end

    it "requires an un-returned rental" do
      @rental.returned = true
      @rental.save!

      post check_in_path(title: @rental.video.title), params: {
        customer_id: @rental.customer.id
      }
      must_respond_with :not_found
      data = JSON.parse @response.body
      expect(data).must_include "errors"
      expect(data["errors"]).must_include "rental"
    end

    it "if multiple rentals match, ignores returned ones" do
      returned_rental = Rental.create!(
        video: @rental.video,
        customer: @rental.customer,
        checkout_date: Date.today - 5,
        due_date: @rental.due_date - 2,
        returned: true
      )

      post check_in_path(title: @rental.video.title), params: {
        customer_id: @rental.customer.id
      }
      must_respond_with :success

      returned_rental.reload
      @rental.reload

      expect(@rental.returned).must_equal true
    end

    it "returns the rental with the closest due_date" do
      soon_rental = Rental.create!(
        video: @rental.video,
        customer: @rental.customer,
        checkout_date: Date.today - 5,
        due_date: @rental.due_date - 2,
        returned: false
      )

      far_rental = Rental.create!(
        video: @rental.video,
        customer: @rental.customer,
        checkout_date: Date.today - 5,
        due_date: @rental.due_date + 10,
        returned: false
      )

      post check_in_path(title: @rental.video.title), params: {
        customer_id: @rental.customer.id
      }
      must_respond_with :success

      soon_rental.reload
      @rental.reload
      far_rental.reload

      expect(soon_rental.returned).must_equal true
      expect(@rental.returned).must_equal false
      expect(far_rental.returned).must_equal false
    end
  end

  describe "overdue" do
    # Note that we *don't* check the actual content,
    # since that is covered by the model tests.
    # Instead we just check the things the controlelr
    # is responsible for.

    it "Returns a JSON array" do
      get overdue_path
      must_respond_with :success
      expect(@response.headers['Content-Type']).must_include 'json'

      # Attempt to parse
      data = JSON.parse @response.body
      expect(data).must_be_kind_of Array
    end

    it "Returns an empty array if no rentals overdue" do
      # Make sure there's none overdue
      Rental.all.each do |r|
        r.returned = true
        r.save!
      end

      get overdue_path
      must_respond_with :success

      data = JSON.parse @response.body
      expect(data).must_be_kind_of Array
      expect(data.length).must_equal 0
    end

    it "Returns expected fields" do
      # Make sure we get something back
      expect(Rental.overdue.length).must_be :>, 0

      get overdue_path
      must_respond_with :success

      data = JSON.parse @response.body
      expect(data).must_be_kind_of Array
      expect(data.length).must_equal Rental.overdue.length

      data.each do |rental|
        expect(rental).must_be_kind_of Hash
        expect(rental).must_include "title"
        expect(rental).must_include "customer_id"
        expect(rental).must_include "name"
        expect(rental).must_include "postal_code"
        expect(rental).must_include "checkout_date"
        expect(rental).must_include "due_date"
      end
    end
  end
end
