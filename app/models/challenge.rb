# frozen_string_literal: true

class Challenge < ApplicationRecord
  enum status: %i[queued active complete]

  belongs_to :user

  has_many :queries, dependent: :destroy
  has_many :attempts, through: :queries

  validates :spanish_text, :english_text, :user, presence: true

  MAX_ACTIVE = 10

  def current_streak
    recent_attempts = attempts.order("attempts.created_at DESC").limit(required_streak_for_completion)

    count = 0

    recent_attempts.each do |attempt|
      break unless attempt.correct?

      count += 1
    end

    count
  end

  def streak_enough_for_completion?
    current_streak >= required_streak_for_completion
  end

  def mark_as_complete
    complete!

    christina = User.find_by(username: "christina")

    christina&.text("Drew has completed the challenge \"#{spanish_text}\"!")
  end

  class << self
    def complete_and_process(challenge)
      challenge.mark_as_complete

      first_in_queue&.active! if need_more_active?
    end

    def create_and_process(attrs)
      attrs[:spanish_text] = attrs[:spanish_text]&.strip
      attrs[:english_text] = attrs[:english_text]&.strip

      create(attrs).tap do |challenge|
        challenge.status = :active if need_more_active?

        if challenge.valid?
          User.drew.text("New challenged added! '#{challenge.spanish_text}' / '#{challenge.english_text}'.")
        end
      end
    end

    def need_more_active?
      active.count < MAX_ACTIVE
    end

    def first_in_queue
      queued.first
    end
  end
end
