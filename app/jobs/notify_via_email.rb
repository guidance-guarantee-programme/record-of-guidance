require 'notifications/client'

class NotifyViaEmail < ApplicationJob
  class AttemptingToResendNotification < StandardError
    ERROR_ATTRIBUTES = %w(id email first_name last_name notification_id).freeze

    def initialize(appointment_summary)
      super(appointment_summary.attributes.slice(*ERROR_ATTRIBUTES).inspect)
    end
  end

  queue_as :default

  def perform(appointment_summary, config: Rails.configuration.x.notify)
    payload  = notification(appointment_summary, template_id(appointment_summary, config))
    response = Notifications::Client.new(config.secret_id).send_email(payload)

    appointment_summary.update(
      notification_id: response.id,
      notify_completed_at: nil,
      notify_status: :pending
    )
  end

  private

  def notification(appointment_summary, template_id)
    {
      email_address: appointment_summary.email,
      template_id: template_id,
      personalisation: {
        reference_number: appointment_summary.reference_number,
        title: appointment_summary.title,
        last_name: appointment_summary.last_name,
        guider_name: appointment_summary.guider_name,
        date_of_appointment: appointment_summary.date_of_appointment.to_s(:pw_date_long),
        section_32: covering_letter_content(appointment_summary, 'section_32'), # rubocop:disable Naming/VariableNumber
        adjustable_income: covering_letter_content(appointment_summary, 'adjustable_income'),
        inherited_pot: covering_letter_content(appointment_summary, 'inherited_pot'),
        fixed_term_annuity: covering_letter_content(appointment_summary, 'fixed_term_annuity')
      }
    }.to_json
  end

  def covering_letter_content(appointment_summary, type)
    appointment_summary.covering_letter_type == type ? 'yes' : 'no'
  end

  def template_id(appointment_summary, config)
    appointment_summary.eligible_for_guidance? ? config.appointment_summary_template_id : config.ineligible_template_id
  end
end
