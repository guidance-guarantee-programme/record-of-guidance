require 'rails_helper'

RSpec.describe AppointmentSummariesController, 'GET #new', type: :controller do
  let(:email) { 'guider@example.com' }
  let(:password) { 'pensionwise' }
  let(:user) do
    User.create(email: email, password: password).tap(&:confirm!)
  end

  subject { response }

  context 'when not authenticated' do
    before do
      get :new
    end

    it { is_expected.to redirect_to(controller: 'devise/sessions', action: :new) }
  end

  context 'when authenticated' do
    before do
      sign_in user
      get :new
    end

    it { is_expected.to be_ok }
  end

  context '#create' do
    let(:appointment_summary) do
      build(:appointment_summary, requested_digital: requested_digital, email: email).attributes
    end

    before { sign_in user }

    context 'when the customer has requested a digital summary document' do
      let(:requested_digital) { true }

      context 'and has provided a valid email address' do
        let(:email) { 'rick@sanchez.com' }

        it 'we should attempt to notify the customer of the digital summary document location by email' do
          expect(NotifyViaEmail).to receive(:perform_later).with(an_instance_of(AppointmentSummary))

          post :create, appointment_summary: appointment_summary
        end
      end

      context 'and has not provided a valid email address' do
        let(:email) { '' }

        it 'we should not attempt to notify the customer' do
          expect(NotifyViaEmail).not_to receive(:perform_later)

          post :create, appointment_summary: appointment_summary
        end
      end
    end

    context 'when the customer has requested a postal summary document' do
      let(:requested_digital) { false }
      let(:email) { 'rick@sanchez.com' }

      it 'we should not attempt to notify the customer' do
        expect(NotifyViaEmail).not_to receive(:perform_later)

        post :create, appointment_summary: appointment_summary
      end
    end
  end
end
