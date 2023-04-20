# frozen_string_literal: true

# Alexander Kind (kind@shineblu.com) 19-04-2023
# Custom controller to ease room management from external systems like Bitrix
# It uses BBB secret as auth factor and shouldn't be used by end-users, but only server-server calls

class GreenapiController < ApplicationController
  #skip_before_action :redirect_to_https, :set_user_domain, :set_user_settings, :maintenance_mode?, :migration_error?,
  #:user_locale, :check_admin_password, :check_user_role
  skip_before_action :verify_authenticity_token
  before_action :check_api_secret

  # GET /greenapi
  def all
    response = "API is ready"
    render plain: response
  end

  # POST /greenapi/delete_room
  def delete_room
    begin
        @room = Room.find_by!(id: params[:roomId])
        if ( @room.nil? ) 
          render plain: { error: "Room does not exists" }.to_json
	  return
        end
        # Non-permanent deletion (deleted=true)
        @room.destroy(false)
        result = {
	   result: "done",
	   room: @room
        }
        render plain: result.to_json
    rescue => e
	render plain: { error: "Room does not exists" }.to_json
    end
  end

  # POST /greenapi/list_rooms
  def list_rooms
    rooms = Room.where(deleted: false)
    render plain: rooms.to_json
  end

  # POST /greenapi/create_room
  def create_room
    ownerUserId = params[:ownerUserId]
    if ( ownerUserId.nil? || ownerUserId.empty? ) 
	# attach to the first administrator
        ownerUser = User.find_by(role_id: 2)
    else
        ownerUser = User.find_by(id: ownerUserId.to_i)
    end

    moderatorAccessCode = params[:moderatorAccessCode]
    if ( moderatorAccessCode.nil? ||  moderatorAccessCode.empty? )
	moderatorAccessCode = generate_activation_code(8)
    end

    anyoneCanStart = params[:anyoneCanStart]
    if ( anyoneCanStart.nil? || anyoneCanStart.empty? )
	anyoneCanStart = "0"
    end

    recording = params[:recording]
    if ( recording.nil? || recording.empty? )
	recording = "1"
    end

    @room = Room.new(name: params[:roomName], access_code: '', moderator_access_code: moderatorAccessCode)
    room_settings = {
	muteOnStart: true,
	requireModeratorApproval: false,
	anyoneCanStart: anyoneCanStart == "1",
	joinModerator: false,
	recording: recording == "1"
    }

    @room.room_settings = room_settings.to_json
    if ( !ownerUser.nil? )
	@room.owner = ownerUser
    end

    @room.save
    render plain: @room.to_json
  end

  private

  def check_api_secret()
    secret = params[:apiSecret]
    if ( secret.nil? || secret.empty? || secret != Rails.configuration.bigbluebutton_secret )
	render plain: "Authentication failed"
	return 
    end
  end

  def generate_activation_code(size = 8)
    charset = %w{1 2 3 4 6 7 9 0 A C D E F G H I J K L M N O P Q R S T U V W X Y Z}
    (0...size).map{ charset.to_a[rand(charset.size)] }.join
  end

end
