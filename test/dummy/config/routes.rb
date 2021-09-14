Rails.application.routes.draw do
  mount EmrOhspInterface::Engine => "/emr_ohsp_interface"
end
