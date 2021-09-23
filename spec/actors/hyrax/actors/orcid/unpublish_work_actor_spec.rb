# frozen_string_literal: true

require "rails_helper"

RSpec.describe Hyrax::Actors::Orcid::UnpublishWorkActor do
  subject(:actor) { described_class.new(next_actor) }
  let(:ability) { Ability.new(user) }
  let(:env) { Hyrax::Actors::Environment.new(work, ability, {}) }
  let(:next_actor) { Hyrax::Actors::Terminator.new }
  let(:user) { create(:user) }
  let!(:orcid_identity) { create(:orcid_identity, work_sync_preference: sync_preference, user: user) }
  let(:sync_preference) { "sync_all" }
  let(:model_class) { GenericWork }
  let(:work) { model_class.create(work_attributes) }
  let(:work_attributes) do
    {
      "title" => ["Moomin"],
      "creator" => [
        [{
          "creator_name" => "John Smith",
          "creator_orcid" => orcid_id
        }].to_json
      ]
    }
  end
  let(:orcid_id) { user.orcid_identity.orcid_id }

  before do
    allow(Flipflop).to receive(:enabled?).and_call_original
    allow(Flipflop).to receive(:enabled?).with(:hyrax_orcid).and_return(true)

    ActiveJob::Base.queue_adapter = :test
  end

  describe "#destroy" do
    context "when hyrax_orcid is enabled" do
      it "enqueues a job" do
        expect { actor.destroy(env) }.to have_enqueued_job(Hyrax::Orcid::UnpublishWorkDelegatorJob)
          .with(work)
          .on_queue(Hyrax.config.ingest_queue_name)
      end
    end

    context "when hyrax_orcid is disabled" do
      before do
        allow(Flipflop).to receive(:enabled?).with(:hyrax_orcid).and_return(false)
      end

      it "does not enqueue a job" do
        expect { actor.destroy(env) }.not_to have_enqueued_job(Hyrax::Orcid::UnpublishWorkDelegatorJob)
      end
    end
  end
end
