require 'test_helper'

class RentalTest < ActiveSupport::TestCase
  let(:rental_data) {
    {
      checkout_date: "2017-01-08:",
      due_date: Date.today + 1,
      customer: customers(:one),
      video: videos(:one)
    }
  }

  before do
    @rental = Rental.new(rental_data)
  end

  describe "Constructor" do
    it "Has a constructor" do
      Rental.create!(rental_data)
    end

    it "Has a customer" do
      expect(@rental).must_respond_to :customer
    end

    it "Cannot be created without a customer" do
      data = rental_data.clone()
      data.delete :customer
      c = Rental.new(data)
      expect(c.valid?).must_equal false
      expect(c.errors.messages).must_include :customer
    end

    it "Has a video" do
      expect(@rental).must_respond_to :video
    end

    it "has a video with sufficient inventory" do
      videos(:one)['inventory'] = 0
      rental_data['video'] = videos(:one)
      bad_rental = Rental.new(rental_data)
      expect(bad_rental.valid?).must_equal false
      expect(bad_rental.errors.messages).must_include :video
      expect(bad_rental.errors.messages[:video]).must_include "is invalid"
    end

    it "Cannot be created without a video" do
      data = rental_data.clone
      data.delete :video
      c = Rental.new(data)
      expect(c.valid?).must_equal false
      expect(c.errors.messages).must_include :video
    end
  end

  describe "due_date" do
    it "Cannot be created without a due_date" do
      data = rental_data.clone
      data.delete :due_date
      c = Rental.new(data)
      expect(c.valid?).must_equal false
      expect(c.errors.messages).must_include :due_date
    end

    it "due_date on a new rental must be in the future" do
      data = rental_data.clone
      data[:due_date] = Date.today - 1
      c = Rental.new(data)
      expect(c.valid?).must_equal false
      expect(c.errors.messages).must_include :due_date

      # Today is also not in the future
      data = rental_data.clone
      data[:due_date] = Date.today
      c = Rental.new(data)
      expect(c.valid?).must_equal false
      expect(c.errors.messages).must_include :due_date
    end

    it "rental with an old due_date can be updated" do
      r = Rental.find(rentals(:overdue).id)
      r.returned = true
      r.save!
    end
  end

  describe "first_outstanding" do
    it "returns the only un-returned rental" do
      expect(Rental.count).must_equal 1
      expect(Rental.first.returned).must_equal false
      expect(
        Rental.first_outstanding(
          Rental.first.video,
          Rental.first.customer
        )
      ).must_equal Rental.first
    end

    it "returns nil if no rentals are un-returned" do
      Rental.all.each do |rental|
        rental.returned = true
        rental.save!
      end
      expect(
        Rental.first_outstanding(
          Rental.first.video,
          Rental.first.customer
        )
      ).must_be_nil
    end

    it "prefers rentals with earlier due dates" do
      # Start with a clean slate
      Rental.destroy_all

      # Last
      Rental.create!(
        video: videos(:one),
        customer: customers(:one),
        due_date: Date.today + 30,
        returned: false
      )
      first = Rental.create!(
        video: videos(:one),
        customer: customers(:one),
        due_date: Date.today + 10,
        returned: false
      )
      # Middle
      Rental.create!(
        video: videos(:one),
        customer: customers(:one),
        due_date: Date.today + 20,
        returned: false
      )
      expect(
        Rental.first_outstanding(
          videos(:one),
          customers(:one)
        )
      ).must_equal first
    end

    it "ignores returned rentals" do
      # Start with a clean slate
      Rental.destroy_all

      # Returned
      Rental.create!(
        video: videos(:one),
        customer: customers(:one),
        due_date: Date.today + 10,
        returned: true
      )
      outstanding = Rental.create!(
        video: videos(:one),
        customer: customers(:one),
        due_date: Date.today + 30,
        returned: false
      )

      expect(
        Rental.first_outstanding(
          videos(:one),
          customers(:one)
        )
      ).must_equal outstanding
    end
  end

  describe "overdue" do
    it "returns all overdue rentals" do
      expect(Rental.count).must_equal 1
      expect(Rental.first.returned).must_equal false
      expect(Rental.first.due_date).must_be :<, Date.today

      overdue = Rental.overdue
      expect(overdue.length).must_equal 1
      expect(overdue.first).must_equal Rental.first
    end

    it "ignores rentals that aren't due yet" do
      Rental.create!(
        video: videos(:two),
        customer: customers(:one),
        due_date: Date.today + 10,
        returned: false
      )

      overdue = Rental.overdue
      expect(overdue.length).must_equal 1
      expect(overdue.first).must_equal Rental.first
    end

    it "ignores rentals that have been returned" do
      Rental.new(
        video: videos(:two),
        customer: customers(:one),
        due_date: Date.today - 3,
        returned: true
      ).save!(validate: false)

      overdue = Rental.overdue
      expect(overdue.length).must_equal 1
      expect(overdue.first).must_equal Rental.first
    end

    it "returns an empty array if no rentals are overdue" do
      r = Rental.first
      r.returned = true
      r.save!
      expect(Rental.overdue.length).must_equal 0
    end
  end
end
