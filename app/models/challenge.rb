# frozen_string_literal: true

class Challenge < ApplicationRecord
  enum status: %i[queued active complete]

  belongs_to :student, class_name: "User", foreign_key: "student_id"
  belongs_to :creator, class_name: "User", foreign_key: "creator_id"

  has_many :queries, dependent: :destroy
  has_many :attempts, through: :queries

  validates :spanish_text, :english_text, :student, :creator, presence: true

  MAX_ACTIVE = 10

  def streak_enough_for_completion?
    current_streak >= required_streak_for_completion
  end

  def correct_attempts_still_required
    [0, required_streak_for_completion - current_streak].max
  end

  def mark_as_complete
    complete!

    self.class.first_in_queue&.active! if self.class.need_more_active?

    creator.text("#{student.username} has completed the challenge \"#{spanish_text}\"!") unless creator_id == student_id
  end

  def process_attempt(attempt)
    case attempt.result_status
    when "incorrect_active"
      update(current_streak: 0)
    when "correct_active_insufficient", "correct_complete"
      increment!(:current_streak)
    when "correct_active_sufficient"
      increment!(:current_streak)
      mark_as_complete
    when "incorrect_complete"
      update(current_streak: 0)
      active!
    end
  end

  def create_and_send_query
    query = Query.create(challenge: self, language: random_language)
    query.send_message
  end

  class << self
    def create_and_process(attrs)
      attrs[:spanish_text] = attrs[:spanish_text]&.strip
      attrs[:english_text] = attrs[:english_text]&.strip

      create(attrs).tap do |challenge|
        challenge.update(status: "active") if need_more_active?

        if challenge.valid?
          challenge.student.text("New challenged added! '#{challenge.spanish_text}' / '#{challenge.english_text}'.")
        end
      end
    end

    def need_more_active?
      active.count < MAX_ACTIVE
    end

    def first_in_queue
      queued.first
    end

    def random_active_not_last
      active.where.not(id: last_query.challenge_id).sample
    end

    def random_complete
      complete.sample
    end
  end

  private

  def random_language
    if rand < 0.66
      "english"
    else
      "spanish"
    end
  end
end
