class EmrOhspInterface::EmrOhspInterfaceController < ::ApplicationController
    def weeks_generator
        render json: service.weeks_generator();
    end   
    def months_generator
        render json: service.months_generator();
    end
   
    def service
        EmrOhspInterface::EmrOhspInterfaceService
    end
end