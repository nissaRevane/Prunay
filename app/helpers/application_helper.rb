module ApplicationHelper
  TONES = { 1 => "is-positive", -1 => "is-negative" }.freeze

  def euros(amount) = number_to_currency(amount, precision: 0)

  def tone(amount) = TONES[amount&.<=>(0)]

  def rate_tone(rate) = ("is-negative" if rate&.negative?)
end
