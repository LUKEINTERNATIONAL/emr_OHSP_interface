EmrOhspInterface::Engine.routes.draw do
    resources :radiology, path: 'api/v1/emr_ohsp_interface'      
    get '/get_weeks', to: 'emr_ohsp_interface#weeks_generator'
    get '/get_months', to: 'emr_ohsp_interface#months_generator'
end
