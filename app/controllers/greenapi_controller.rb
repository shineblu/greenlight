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
    @response = "API is ready"
    render plain: @response
  end

  # POST /greenapi/delete_room
  def delete_room
    begin
	if ( !params[:roomUid].nil? )
	    @room = Room.find_by!(uid: params[:roomUid])
	else
    	    @room = Room.find_by!(id: params[:roomId])
	end

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
	render plain: { error: "Room does not exists (exception)" }.to_json
    end
  end

  # POST /greenapi/cancel_room
  def cancel_room
    begin
	if ( !params[:roomUid].nil? )
	    @room = Room.find_by!(uid: params[:roomUid])
	else
    	    @room = Room.find_by!(id: params[:roomId])
	end

        if ( @room.nil? ) 
          render plain: { error: "Room does not exists" }.to_json
	  return
        end

	# Cancel action can be reverted, but if parameter is absent then it means room is cancelled
        @cancelled = params[:cancelled]
	if ( @cancelled.nil? || @cancelled.empty? )
	    @cancelled = "1"
	end

	# Adjust room settings
	@room_settings = JSON.parse(@room[:room_settings])
	@room_settings["roomIsCancelled"] = (@cancelled == "1")
        @room.room_settings = @room_settings.to_json
	@room.save
	
        result = {
	   result: "done",
	   room: @room
        }
        render plain: result.to_json
    rescue => e
	render plain: { error: "Room does not exists (exception)" }.to_json
    end
  end

  # POST /greenapi/room_records
  def room_records
    begin
	if ( !params[:roomUid].nil? )
	    @room = Room.find_by!(uid: params[:roomUid])
	else
    	    @room = Room.find_by!(id: params[:roomId])
	end

        if ( @room.nil? ) 
          render plain: { error: "Room does not exists" }.to_json
	  return
        end
        
	# get room records
	all_recordings = get_recordings(@room.bbb_id)
	filtered_recordings = []

	all_recordings[:recordings].each do |r|
	    next if r.key?(:error)
	    next if !r[:published] || r[:rawSize] == 0
	
	    recordStart = r[:startTime].to_datetime
	    recordEnd = r[:endTime].to_datetime
	    recordLength = ((recordEnd - recordStart) * 24 * 60).to_i
	    recordItem = {
		minutes: recordLength,
		url: r[:playback][:format][:url].strip
	    }
	    filtered_recordings.push(recordItem)
	end
	
        result = {
	   result: "done",
	   room: @room,
	   records: filtered_recordings
        }
        render plain: result.to_json
    rescue => e
	render plain: { error: "Room does not exists (exception)" }.to_json
    end
  end

  # POST /greenapi/list_rooms
  def list_rooms
    if ( !params[:roomUid].nil? )
        @rooms = Room.where(uid: params[:roomUid])
    elsif ( !params[:roomId].nil? )
	@rooms = Room.where(id: params[:roomId])
    else 
	@rooms = Room.where(deleted: false)
    end

    render plain: @rooms.to_json
  end

  # POST /greenapi/create_room
  def create_room
    @ownerUserId = params[:ownerUserId]
    if ( @ownerUserId.nil? || @ownerUserId.empty? ) 
	# attach to the first administrator
        @ownerUser = User.find_by(role_id: 2)
    else
        @ownerUser = User.find_by(id: @ownerUserId.to_i)
    end

    @moderatorAccessCode = params[:moderatorAccessCode]
    if ( @moderatorAccessCode.nil? || @moderatorAccessCode.empty? )
	@moderatorAccessCode = generate_activation_code(8)
    end

    @anyoneCanStart = params[:anyoneCanStart]
    if ( @anyoneCanStart.nil? || @anyoneCanStart.empty? )
	@anyoneCanStart = "0"
    end

    @recording = params[:recording]
    if ( @recording.nil? || @recording.empty? )
	@recording = "1"
    end

    @room = Room.new(name: params[:roomName], access_code: '', moderator_access_code: @moderatorAccessCode)
    @room_settings = {
	muteOnStart: true,
	requireModeratorApproval: false,
	anyoneCanStart: @anyoneCanStart == "1",
	joinModerator: false,
	recording: @recording == "1",
	attachFilesUrl: params[:attachFilesUrl],
	roomIsCancelled: false,
	roomExpiresOn: params[:roomExpiresOn]
    }

    @room.room_settings = @room_settings.to_json
    if ( !@ownerUser.nil? )
	@room.owner = @ownerUser
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
