class Rental < ApplicationRecord
  belongs_to :video
  belongs_to :customer

  # validates :video, uniqueness: { scope: :customer }
  validates :due_date, presence: true
  validate :due_date_in_future, on: :create
  validates_associated :customer, :video

  after_initialize :set_checkout_date
  after_initialize :set_returned


  def self.first_outstanding(video, customer)
    self.where(video: video, customer: customer, returned: false).order(:due_date).first
  end

  def self.overdue
    self.where(returned: false).where("due_date < ?", Date.today)
  end

private
  def due_date_in_future
    return unless self.due_date
    unless due_date > Date.today
      errors.add(:due_date, "Must be in the future")
    end
  end

  def set_checkout_date
    self.checkout_date ||= Date.today
  end

  def set_returned
    self.returned ||= false
  end
end
