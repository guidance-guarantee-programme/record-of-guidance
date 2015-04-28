require 'rails_helper'

RSpec.describe AppointmentSummary, type: :model do
  subject do
    described_class.new(continue_working: continue_working,
                        has_defined_contribution_pension: has_defined_contribution_pension)
  end

  let(:continue_working) { false }
  let(:has_defined_contribution_pension) { 'yes' }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to have_many(:appointment_summaries_batches).dependent(:destroy) }

  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to_not validate_presence_of(:first_name) }
  it { is_expected.to validate_presence_of(:last_name) }

  it { is_expected.to validate_inclusion_of(:title).in_array(%w(Mr Mrs Miss Ms Mx Dr Reverend)) }
  it { is_expected.to_not allow_value('Alien').for(:title) }

  it { is_expected.to allow_value('2015-02-10').for(:date_of_appointment) }
  it { is_expected.to allow_value('12/02/2015').for(:date_of_appointment) }
  it { is_expected.to_not allow_value('10/02/2012').for(:date_of_appointment) }
  it { is_expected.to_not allow_value(Time.zone.tomorrow.to_s).for(:date_of_appointment) }

  it { is_expected.to validate_presence_of(:reference_number) }
  it { is_expected.to validate_numericality_of(:reference_number).only_integer }

  it { is_expected.to_not validate_presence_of(:value_of_pension_pots) }
  it { is_expected.to validate_numericality_of(:value_of_pension_pots) }
  it { is_expected.to allow_value('').for(:value_of_pension_pots) }

  it { is_expected.to_not validate_presence_of(:upper_value_of_pension_pots) }
  it { is_expected.to validate_numericality_of(:upper_value_of_pension_pots) }
  it { is_expected.to allow_value('').for(:upper_value_of_pension_pots) }

  it { is_expected.to validate_inclusion_of(:income_in_retirement).in_array(%w(pension other)) }

  it { is_expected.to validate_presence_of(:guider_name) }
  it { is_expected.to validate_inclusion_of(:guider_organisation).in_array(%w(tpas dwp)) }

  it { is_expected.to validate_presence_of(:address_line_1) }
  it { is_expected.to validate_length_of(:address_line_1).is_at_most(50) }
  it { is_expected.to_not validate_presence_of(:address_line_2) }
  it { is_expected.to validate_length_of(:address_line_2).is_at_most(50) }
  it { is_expected.to_not validate_presence_of(:address_line_3) }
  it { is_expected.to validate_length_of(:address_line_3).is_at_most(50) }
  it { is_expected.to validate_presence_of(:town) }
  it { is_expected.to validate_length_of(:town).is_at_most(50) }
  it { is_expected.to_not validate_presence_of(:county) }
  it { is_expected.to validate_length_of(:county).is_at_most(50) }
  it { is_expected.to validate_presence_of(:country) }
  it { is_expected.to validate_inclusion_of(:country).in_array(Countries.all) }
  it { is_expected.to validate_presence_of(:postcode) }

  describe '#country' do
    it "has a default value of #{Countries.uk}" do
      expect(subject.country).to eq(Countries.uk)
    end
  end

  describe 'postcode validation' do
    context 'for UK addresses' do
      before { subject.country = Countries.uk }

      it { is_expected.to validate_presence_of(:postcode) }
      it { is_expected.to allow_value('SW1A 2HQ').for(:postcode) }
      it { is_expected.to_not allow_value('nonsense').for(:postcode) }
    end

    context 'for non-UK addresses' do
      before { subject.country = Countries.non_uk.sample }

      it { is_expected.to_not validate_presence_of(:postcode) }
      it { is_expected.to allow_value('nonsense').for(:postcode) }
    end
  end

  it do
    is_expected
      .to validate_inclusion_of(:has_defined_contribution_pension).in_array(%w(yes no unknown))
  end

  it do
    is_expected
      .to validate_inclusion_of(:format_preference).in_array(%w(standard large_text braille))
  end

  it 'has a defaults to a standard format preference' do
    expect(subject.format_preference).to eq('standard')
  end

  describe '#postcode=' do
    before { subject.postcode = ' sw1a 2hq    ' }

    specify { expect(subject.postcode).to eq('SW1A 2HQ') }
  end

  context 'when ineligible for guidance' do
    let(:has_defined_contribution_pension) { 'no' }

    it { is_expected.to_not be_eligible_for_guidance }
    it { is_expected.to_not be_generic_guidance }
    it { is_expected.to_not be_custom_guidance }

    it { is_expected.to_not validate_presence_of(:value_of_pension_pots) }
    it { is_expected.to_not validate_presence_of(:upper_value_of_pension_pots) }

    it { is_expected.to_not validate_numericality_of(:value_of_pension_pots) }
    it { is_expected.to_not validate_numericality_of(:upper_value_of_pension_pots) }

    it do
      is_expected.to_not validate_inclusion_of(:income_in_retirement).in_array(%w(pension other))
    end
  end

  context 'when eligible for guidance' do
    let(:has_defined_contribution_pension) { 'yes' }

    context 'and no retirement circumstances given' do
      it { is_expected.to be_eligible_for_guidance }
      it { is_expected.to be_generic_guidance }
      it { is_expected.to_not be_custom_guidance }
    end

    context 'and retirement circumstances given' do
      let(:continue_working) { true }

      it { is_expected.to be_eligible_for_guidance }
      it { is_expected.to_not be_generic_guidance }
      it { is_expected.to be_custom_guidance }
    end
  end

  describe '.unprocessed' do
    subject { described_class.unprocessed }

    def create_appointment_summary
      AppointmentSummary.create(
        title: 'Mr', last_name: 'Bloggs', date_of_appointment: Time.zone.today,
        reference_number: '123', guider_name: 'Jimmy', guider_organisation: 'tpas',
        address_line_1: '29 Acacia Road', town: 'Beanotown', postcode: 'BT7 3AP',
        has_defined_contribution_pension: 'yes', income_in_retirement: 'pension')
    end

    context 'with no unprocessed items' do
      let!(:appointment_summaries) { 2.times.map { create_appointment_summary } }
      let!(:previous_batch) { Batch.create(appointment_summaries: appointment_summaries) }

      it { is_expected.to be_empty }
    end

    context 'with unprocessed items' do
      let!(:appointment_summaries) { 2.times.map { create_appointment_summary } }

      it { is_expected.to eq(appointment_summaries) }
    end

    context 'with processed and unprocessed items' do
      let!(:appointment_summaries) { 4.times.map { create_appointment_summary } }
      let!(:previous_batch) { Batch.create(appointment_summaries: appointment_summaries[0..1]) }

      it { is_expected.to eq(appointment_summaries[2, 3]) }
    end
  end
end
