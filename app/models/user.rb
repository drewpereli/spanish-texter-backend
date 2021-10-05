# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password
  has_secure_token :confirmation_token

  validates :username, :phone_number, presence: true
  validates :password, :password_confirmation, presence: true, on: :create
  validates :username, uniqueness: true

  has_many :challenges_assigned, class_name: "Challenge", foreign_key: "student_id"
  has_many :challenges_created, class_name: "Challenge", foreign_key: "creator_id"

  def token
    JWT.encode({user_id: id}, Rails.application.secret_key_base)
  end

  def text(message)
    twilio_client.text_number(phone_number, message)
  end

  def twilio_client
    @twilio_client ||= TwilioClient.new
  end

  def confirm!
    update!(confirmed: true, confirmation_token: nil)
  end

  def self.create_and_send_confirmation(attrs)
    create(attrs).tap do |user|
      break user unless user.persisted?

      front_end_url = Rails.env.production? ? "www.spanishtexter.com" : "localhost:4200"

      url = "#{front_end_url}/confirm-user?token=#{user.confirmation_token}&user_id=#{user.id}"

      message = "Please click this link to confirm your account. #{url}"

      user.text(message)
    end
  end
end
