class EmrOHSPInterface::EmrOHSPInterfaceController < ::ApplicationController
    def weeks_generator
        render json: service.weeks_generator();
    end   
    def months_generator
        render json: service.months_generator();
    end
   
    def service
        EmrOHSPInterface::EmrOHSPInterfaceService
    end
end