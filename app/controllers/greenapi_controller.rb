# frozen_string_literal: true

class GreenapiController < ApplicationController
  #skip_before_action :redirect_to_https, :set_user_domain, :set_user_settings, :maintenance_mode?, :migration_error?,
  #:user_locale, :check_admin_password, :check_user_role
  skip_before_action :verify_authenticity_token

  # GET /greenapi
  def all
    response = "API is ready"
    render plain: response
  end

  # POST /greenapi/create_room
  def create_room
    secret = params[:apiSecret]
    if ( secret.nil? || secret.empty? || secret != Rails.configuration.bigbluebutton_secret )
	render plain: "Authentication failed"
	return 
    end

    response = "Do create room #{params[:roomName]}"
    ownerUser = User.find_by(role_id: 2)
    moderatorAccessCode = params[:moderatorAccessCode]
    if ( moderatorAccessCode.nil? ||  moderatorAccessCode.empty? )
	moderatorAccessCode = generate_activation_code(8)
    end

    @room = Room.new(name: params[:roomName], access_code: '', moderator_access_code: moderatorAccessCode)
    room_settings = {
	muteOnStart: "1",
	requireModeratorApproval: "0",
	anyoneCanStart: "0",
	joinModerator: "0",
	recording: "1"
    }
    @room.room_settings = room_settings.to_json
    @room.owner = ownerUser
    @room.save
    render plain: @room.to_json
  end

  private

  def generate_activation_code(size = 8)
    charset = %w{1 2 3 4 6 7 9 0 A C D E F G H I J K L M N O P Q R S T U V W X Y Z}
    (0...size).map{ charset.to_a[rand(charset.size)] }.join
  end

end
