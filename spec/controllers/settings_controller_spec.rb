# frozen_string_literal: true

require 'rails_helper'

describe SettingsController, type: :request do
  describe '#index' do
    %i[super_admin admin].each do |role|
      it "renders for role of #{role}" do
        user = create(role)
        allow_any_instance_of(ApplicationController)
          .to receive(:current_user).and_return(user)
        get '/settings'
        expect(response.status).to eq(200)
      end
    end

    %i[instructor user].each do |role|
      it "redirects for role of #{role}" do
        user = create(role)
        allow_any_instance_of(ApplicationController)
          .to receive(:current_user).and_return(user)
        get '/settings'
        expect(response.status).to eq(401)
      end
    end
  end

  describe '#all_admins' do
    before do
      # create an admin and super admin
      create(:user)
      create(:admin)
      @super_admin = create(:super_admin)
    end

    context 'when request is json' do
      before do
        allow_any_instance_of(ApplicationController)
          .to receive(:current_user).and_return(@super_admin)
        get '/settings/all_admins', params: { format: :json }
      end

      it 'returns all admin users' do
        expect(JSON.parse(response.body)['admins'].length).to be(2)
      end

      it 'returns 200 ok' do
        expect(response.status).to be(200)
      end
    end

    context 'when request is not json' do
      before do
        allow_any_instance_of(ApplicationController)
          .to receive(:current_user).and_return(@super_admin)
        get '/settings/all_admins'
      end

      it 'returns 404' do
        expect(response.status).to eq(404)
      end
    end

    context 'when the user is not permitted' do
      before do
        allow_any_instance_of(ApplicationController)
          .to receive(:current_user).and_return(create(:user, username: 'reg_user'))
        get '/settings/all_admins', params: { format: :json }
      end

      it 'denies access' do
        expect(response.status).to eq(401)
      end
    end
  end

  describe '#upgrade_admin' do
    before do
      super_admin = create(:super_admin)
      allow_any_instance_of(ApplicationController)
        .to receive(:current_user).and_return(super_admin)
      @action = '/settings/upgrade_admin'
      @format_type = :json
    end

    let(:post_params) do
      params = { user: { username: @user.username }, format: @format_type }
      post @action, params:
    end

    context 'user is not an admin' do
      before do
        @user = create(:user)
        post_params
      end

      it 'turns user into admin' do
        expect(@user.reload.admin?).to be(true)
      end

      it 'returns http 200' do
        expect(response.status).to be(200)
      end

      it 'returns the right message' do
        expect(response.body).to include("#{@user.username} elevated to admin.")
      end
    end

    context 'user is already an admin' do
      before do
        @user = create(:admin)
        post_params
      end

      it 'user remains admin' do
        expect(@user.reload.admin?).to be true
      end

      it 'returns http 422' do
        expect(response.status).to be(422)
      end

      it 'returns the right message' do
        expect(response.body).to include("#{@user.username} is already an admin!")
      end
    end

    context 'when the user does not exist' do
      before do
        @user = build(:user)
        post_params
      end

      it 'returns a 404' do
        expect(response.status).to eq(404)
      end
    end
  end

  describe '#downgrade_admin' do
    before do
      @action = '/settings/downgrade_admin'
      @format_type = :json
      super_admin = create(:super_admin)
      allow_any_instance_of(ApplicationController)
        .to receive(:current_user).and_return(super_admin)
    end

    let(:post_params) do
      params = { format: @format_type,
                  user: { username: @user.username } }
      post @action, params:
    end

    context 'user is an admin' do
      before do
        @user = create(:admin)
        post_params
      end

      it 'turns admin into instructor' do
        expect(@user.reload.instructor_permissions?).to be true
      end

      it 'returns http 200' do
        expect(response.status).to be(200)
      end

      it 'returns the right message' do
        expect(response.body).to include("#{@user.username} changed to instructor.")
      end
    end

    context 'user is already an instructor' do
      before do
        @user = create(:instructor)
        post_params
      end

      it 'user remains instructor' do
        expect(@user.reload.instructor_permissions?).to be true
      end

      it 'returns http 422' do
        expect(response.status).to be(422)
      end

      it 'returns the right message' do
        expect(response.body).to include("#{@user.username} is already an instructor!")
      end
    end

    context 'user is super_admin' do
      before do
        @user = create(:super_admin, username: 'tryandrevokeme')
        post_params
      end

      it 'disallows revocation' do
        expect(@user.reload.super_admin?).to be true
      end

      it 'returns http 422' do
        expect(response.status).to be(422)
      end

      it 'returns the right message' do
        expect(response.body).to include("Can't revoke admin status from a super admin")
      end
    end
  end

  describe '#upgrade_special_user' do
    before do
      super_admin = create(:super_admin)
      allow_any_instance_of(ApplicationController)
        .to receive(:current_user).and_return(super_admin)
      @action = '/settings/upgrade_special_user'
      @format_type = :json
    end

    let(:post_params) do
      params = { format: @format_type,
                  special_user: { username: @user.username,
                                  position: } }
      post @action, params:
    end

    let(:post_invalid_position_params) do
      params = { format: @format_type,
                  special_user: { username: @user.username,
                                  position: 'apositionhasnoname' } }
      post @action, params:
    end

    let(:position) { 'classroom_program_manager' }

    context 'user is not an communications_manager' do
      let(:position) { 'communications_manager' }

      before do
        @user = create(:user)
        post_params
      end

      it 'turns user into commications manager' do
        expect(SpecialUsers.is?(@user, position)).to be(true)
      end

      it 'returns http 200' do
        expect(response.status).to be(200)
      end

      it 'returns the right message' do
        expect(response.body).to include(
          I18n.t(
            'settings.special_users.new.elevate_success',
            username: @user.username,
            position:
          )
        )
      end
    end

    context 'user is already communications_manager' do
      let(:position) { 'communications_manager' }

      before do
        @user = create(:user)
        SpecialUsers.set_user(position, @user.username)
        post_params
      end

      it 'user remains communications_manager' do
        expect(SpecialUsers.is?(@user, position)).to be(true)
      end

      it 'returns http 422' do
        expect(response.status).to be(422)
      end

      it 'returns the right message' do
        expect(response.body).to include(
          I18n.t(
            'settings.special_users.new.already_is',
            username: @user.username,
            position:
          )
        )
      end
    end

    context 'user is not a wikipedia expert' do
      let(:position) { 'wikipedia_experts' }

      before do
        @user = create(:user)
        post_params
      end

      it 'adds user to wikipedia_experts set' do
        expect(SpecialUsers.is?(@user, position)).to be(true)
      end

      it 'returns http 200' do
        expect(response.status).to be(200)
      end

      it 'returns the right message' do
        expect(response.body).to include(
          I18n.t(
            'settings.special_users.new.elevate_success',
            username: @user.username,
            position:
          )
        )
      end
    end

    context 'user is already a wikipedia expert' do
      let(:position) { 'wikipedia_experts' }

      before do
        @user = create(:user)
        SpecialUsers.set_user(position, @user.username)
        post_params
      end

      it 'user remains a wikipedia expert' do
        expect(SpecialUsers.is?(@user, position)).to be(true)
      end

      it 'returns http 422' do
        expect(response.status).to be(422)
      end

      it 'returns the right message' do
        expect(response.body).to include(
          I18n.t(
            'settings.special_users.new.already_is',
            username: @user.username,
            position:
          )
        )
      end
    end

    context 'when the user does not exist' do
      before do
        @user = build(:user)
        post_params
      end

      it 'returns a 404' do
        expect(response.status).to eq(404)
      end
    end

    context 'when the position is invalid' do
      before do
        @user = create(:user)
        post_invalid_position_params
      end

      it 'returns position is invalid' do
        expect(response.body).to include('position is invalid')
      end
    end
  end

  describe '#downgrade_special_user' do
    before do
      @action = '/settings/downgrade_special_user'
      @format_type = :json
      super_admin = create(:super_admin)
      allow_any_instance_of(ApplicationController)
        .to receive(:current_user).and_return(super_admin)
    end

    let(:post_params) do
      params = { format: @format_type,
                  special_user: { username: @user.username,
                                  position: 'communications_manager' } }
      post @action, params:
    end

    context 'user is a communications_manager' do
      before do
        @user = create(:user)
        @position = 'communications_manager'
        SpecialUsers.set_user(@position, @user.username)
        post_params
      end

      it 'removes the user as communications_manager' do
        expect(SpecialUsers.is?(@user, @position)).to be false
      end

      it 'returns http 200' do
        expect(response.status).to be(200)
      end

      it 'returns the right message' do
        expect(response.body).to include(
          I18n.t(
            'settings.special_users.remove.demote_success',
            username: @user.username,
            position: @position
          )
        )
      end
    end

    context 'user is already just a user' do
      before do
        @user = create(:user)
        @position = 'communications_manager'
        post_params
      end

      it 'user remains a normal user' do
        expect(SpecialUsers.is?(@user, @position)).to be false
      end

      it 'returns http 422' do
        expect(response.status).to be(422)
      end

      it 'returns the right message' do
        expect(response.body).to include(
          I18n.t(
            'settings.special_users.new.already_is_not',
            username: @user.username,
            position: @position
          )
        )
      end
    end
  end

  describe '#update_salesforce_credentials' do
    before do
      @action = '/settings/update_salesforce_credentials'
      @format_type = :json
      super_admin = create(:super_admin)
      allow_any_instance_of(ApplicationController)
        .to receive(:current_user).and_return(super_admin)
    end

    it 'sets the Salesforce password and security token' do
      expect(SalesforceCredentials.get).to eq({})
      post @action, params: { password: 'new_pass', token: 'new_token' }
      expect(SalesforceCredentials.get[:password]).to eq('new_pass')
      expect(SalesforceCredentials.get[:security_token]).to eq('new_token')
    end
  end

  describe '#update_course_creation' do
    before do
      @action = '/settings/update_course_creation'
      @format_type = :json
      admin = create(:admin)
      allow_any_instance_of(ApplicationController)
        .to receive(:current_user).and_return(admin)
    end

    it 'sets the deadline and course creation messages' do
      expect(Deadlines.course_creation_notice).to be_nil
      post @action, params: {
        deadline: '2021-05-07',
        after_deadline_message: 'The deadline has passed.'
      }
      expect(Deadlines.course_creation_notice).to eq('The deadline has passed.')
    end
  end

  describe `#remove_featured_campaign` do
    let(:admin) { create(:super_admin) }
    let(:campaign) { create(:campaign) }
    let(:setting) { Setting.find_or_create_by(key: 'featured_campaigns') }

    before do
      setting.update(value: { 'campaign_slugs' => [campaign.slug] })
      allow_any_instance_of(ApplicationController)
        .to receive(:current_user).and_return(admin)
    end

    describe 'DELETE #remove_featured_campaign' do
      context 'when the campaign exists in the featured campaigns' do
        it 'removes the campaign and returns a success response' do
          post '/settings/remove_featured_campaign',
               params: { featured_campaign_slug: campaign.slug }

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq({ 'campaign_removed' => campaign.slug })
          expect(setting.reload.value['campaign_slugs']).not_to include(campaign.slug)
        end
      end

      context 'when the campaign does not exist in the featured campaigns' do
        it 'returns a success response even if no campaign was removed' do
          post '/settings/remove_featured_campaign',
               params: { featured_campaign_slug: 'non-existent-campaign' }

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq({ 'campaign_removed' => 'non-existent-campaign' })
          expect(setting.reload.value['campaign_slugs']).to include(campaign.slug)
        end
      end
    end
  end

  describe '#update_impact_stats' do
    let(:admin) { create(:super_admin) }

    before do
      allow_any_instance_of(ApplicationController)
        .to receive(:current_user).and_return(admin)
    end

    context 'when updating impact stats' do
      let(:impact_stats) { { 'first' => 234, 'second' => 234 } }

      it 'updates the impact stats and clears the cache' do
        post '/settings/update_impact_stats', params: { impactStats: impact_stats }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq({
          'message' => 'Impact Stats Updated Successfully.'
})
        expect(Rails.cache.read('impact_stats')).to be_nil
      end
    end
  end

  describe '#add_featured_campaign' do
    let(:admin) { create(:super_admin) }
    let(:campaign) { create(:campaign) }
    let(:campaign1) { create(:campaign) }
    let!(:setting) { Setting.find_or_create_by(key: 'featured_campaigns') }

    before do
      allow_any_instance_of(ApplicationController)
        .to receive(:current_user).and_return(admin)
    end

    context 'when adding a new campaign' do
      it 'adds the campaign_slug and returns a success response' do
        post '/settings/add_featured_campaign',
             params: { featured_campaign_slug: campaign.slug }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(
          'campaign_added' => { 'slug' => campaign.slug, 'title' => campaign.title }
        )
        expect(setting.reload.value['campaign_slugs']).to include(campaign.slug)
      end
    end

    context 'when the campaign is already added' do
      before { setting.update(value: { 'campaign_slugs' => [campaign1.slug] }) }

      it 'does not add a duplicate campaign and returns a success response' do
        post '/settings/add_featured_campaign',
             params: { featured_campaign_slug: campaign1.slug }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(
          'campaign_added' => { 'slug' => campaign1.slug, 'title' => campaign1.title }
        )
        expect(setting.reload.value['campaign_slugs']).to include(campaign1.slug)
      end
    end

    context 'when the campaign does not exist' do
      let(:not_found_slug) { 'not_found_campaign' }

      it 'returns a not_found error' do
        post '/settings/add_featured_campaign',
             params: { featured_campaign_slug: not_found_slug }

        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)).to eq(
          'message' => I18n.t('settings.featured_campaigns.campaign_not_found',
                              campaign_slug: not_found_slug)
        )
      end
    end
  end
end
