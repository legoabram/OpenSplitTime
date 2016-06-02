Rails.application.routes.draw do
  root to: 'visitors#index'
  get 'about', to: 'visitors#about'
  get 'donations', to: 'visitors#donations'
  get 'getting_started', to: 'visitors#getting_started'
  get 'getting_started_2', to: 'visitors#getting_started_2'
  get 'getting_started_3', to: 'visitors#getting_started_3'
  get 'getting_started_4', to: 'visitors#getting_started_4'
  get 'getting_started_5', to: 'visitors#getting_started_5'
  get 'course_info', to: 'visitors#course_info'
  get 'effort_info', to: 'visitors#effort_info'
  get 'event_info', to: 'visitors#event_info'
  get 'location_info', to: 'visitors#location_info'
  get 'participant_info', to: 'visitors#participant_info'
  get 'race_info', to: 'visitors#race_info'
  get 'split_info', to: 'visitors#split_info'
  get 'split_time_info', to: 'visitors#split_time_info'
  devise_for :users, :controllers => {registrations: 'registrations'}
  resources :users do
    member { get :participants }
    member { put :associate_participant }
    member { post :add_interest }
    collection { get :my_interests }
    member { get :edit_preferences }
    member { put :update_preferences }
  end
  resources :locations
  resources :courses do
    member { get :best_efforts }
    member { get :plan_effort }
    member { get :segment_picker }
  end
  resources :events do
    member { post :import_splits }
    member { post :import_efforts }
    member { get :splits }
    member { put :associate_split }
    member { put :associate_splits }
    member { put :set_data_status }
    member { delete :remove_split }
    member { delete :remove_all_splits }
    member { delete :delete_all_efforts }
    member { get :reconcile }
    member { post :create_participants }
    member { get :stage}
    member { get :spread}
  end
  resources :splits do
    member { get :assign_location }
    member { post :create_location }
  end
  resources :races
  resources :participants do
    collection { get :subregion_options }
    member { get :avatar_claim }
    member { delete :avatar_disclaim }
    member { get :merge }
    member { put :combine }
    member { delete :remove_effort }
  end
  resources :efforts do
    member { put :associate_participant }
    collection { put :associate_participants}
    member { put :edit_split_times }
    member { delete :delete_split }
    member { put :confirm_split }
    member { put :set_data_status }
  end
  resources :split_times
  resources :interests
  get '/auth/:provider/callback' => 'sessions#create'
  get '/signin' => 'sessions#new', :as => :signin
  get '/signout' => 'sessions#destroy', :as => :signout
  get '/auth/failure' => 'sessions#failure'

  namespace :admin do
    root 'dashboard#dashboard'
    put 'set_effort_ages', to: 'dashboard#set_effort_ages'
  end

  namespace :live do
    get 'live_entry/:id', to: 'live_entry#show'
    get 'live_entry/:id/get_event_data', to: 'live_entry#get_event_data'
    get 'live_entry/:id/get_effort', to: 'live_entry#get_effort'
    get 'live_entry/:id/get_time_from_last', to: 'live_entry#get_time_from_last'
    get 'live_entry/:id/get_time_spent', to: 'live_entry#get_time_spent'
    get 'live_entry/:id/set_split_times', to: 'live_entry#set_split_times'
    get 'control_panel/:id', to: 'control_panel#show'
  end

end
