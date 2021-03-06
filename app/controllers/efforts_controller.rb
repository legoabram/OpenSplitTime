class EffortsController < ApplicationController
  before_action :authenticate_user!, except: [:index, :show, :mini_table, :show_photo, :subregion_options, :analyze, :place]
  before_action :set_effort, except: [:index, :new, :create, :associate_people, :mini_table, :subregion_options]
  after_action :verify_authorized, except: [:index, :show, :mini_table, :show_photo, :subregion_options, :analyze, :place]

  before_action do
    locale = params[:locale]
    Carmen.i18n_backend.locale = locale if locale
  end

  def index

  end

  def show
    @effort_show = EffortShowView.new(effort: @effort)
    session[:return_to] = effort_path(@effort)
  end

  def new
    @effort = Effort.new
    if params[:event_id]
      @event = Event.friendly.find(params[:event_id])
      @effort.event = @event
    end
    authorize @effort
  end

  def edit
    @event = Event.friendly.find(@effort.event_id)
    authorize @effort
  end

  def create
    @effort = Effort.new(permitted_params)
    authorize @effort

    if @effort.save
      redirect_to effort_path(@effort)
    else
      render 'new'
    end
  end

  def update
    authorize @effort

    if @effort.update(permitted_params)
      if params[:button] == 'check_in'
        event = @effort.event
        @stage_display = EventStageDisplay.new(event: event, params: {})
        render :toggle_check_in
      else
        redirect_to params[:commit] == 'Disassociate' ? request.referrer : effort_path(@effort)
      end
    else
      render 'edit'
    end
  end

  def destroy
    authorize @effort

    @effort.destroy
    session[:return_to] = params[:referrer_path] if params[:referrer_path]
    redirect_to session.delete(:return_to) || root_path
  end

  def analyze
    @effort_analysis = EffortAnalysisView.new(@effort)
    session[:return_to] = analyze_effort_path(@effort)
  end

  def place
    @effort_place = PlaceDetailView.new(@effort)
    session[:return_to] = place_effort_path(@effort)
  end

  def start
    authorize @effort
    effort = Effort.where(id: @effort.id).includes(split_times: :split).first

    response = Interactors::StartEfforts.perform!([effort], current_user.id)
    set_flash_message(response)
    redirect_to effort_path(effort)
  end

  def stop
    authorize @effort
    effort = Effort.where(id: @effort.id).includes(split_times: :split).first

    stop_response = Interactors::UpdateEffortsStop.perform!(effort)
    update_response = Interactors::UpdateEffortsStatus.perform!(effort)
    set_flash_message(stop_response.merge(update_response))
    redirect_to effort_path(effort)
  end

  def edit_split_times
    authorize @effort
    effort = Effort.where(id: @effort.id).includes(:event, split_times: :split).first

    @presenter = EffortWithTimesPresenter.new(effort: effort, params: params)
  end

  def update_split_times
    authorize @effort
    effort = Effort.where(id: @effort.id).includes(split_times: :split).first

    if effort.update(permitted_params)
      flash[:success] = "Updated split times. "
      response = Interactors::UpdateEffortsStatus.perform!(effort)
      set_flash_message(response)

      redirect_to effort_path(effort)
    else
      flash[:danger] = "Effort failed to update for the following reasons: #{effort.errors.full_messages}"
      @presenter = EffortWithTimesPresenter.new(effort: effort, params: params)
      render 'edit_split_times'
    end
  end

  def delete_split_times
    authorize @effort
    effort = Effort.where(id: @effort.id).includes(split_times: {split: :course}).first

    destroy_response = Interactors::DestroyEffortSplitTimes.perform!(effort, params[:split_time_ids])
    update_response = Interactors::UpdateEffortsStatus.perform!(effort)
    set_flash_message(destroy_response.merge(update_response))
    redirect_to effort_path(effort)
  end

  def set_data_status
    authorize @effort
    @effort.set_data_status
    redirect_to effort_path(@effort)
  end

  def mini_table
    @mini_table = EffortsMiniTable.new(params[:effort_ids])
    render partial: 'efforts_mini_table'
  end

  def show_photo
    render partial: 'show_photo'
  end

  def add_beacon
    authorize(@effort)
    update_beacon_url(params[:value])
    respond_to do |format|
      format.html { redirect_to effort_path(@effort) }
      format.js { render inline: "location.reload();" }
    end
  end

  def add_report
    authorize(@effort)
    update_report_url(params[:value])
    respond_to do |format|
      format.html { redirect_to effort_path(@effort) }
      format.js { render inline: "location.reload();" }
    end
  end

  def subregion_options
    render partial: 'subregion_select'
  end

  private

  def set_effort
    @effort = Effort.friendly.find(params[:id])
    redirect_numeric_to_friendly(@effort, params[:id])
  end

  def update_beacon_url(url)
    @effort.update(beacon_url: url)
  end

  def update_report_url(url)
    @effort.update(report_url: url)
  end
end
